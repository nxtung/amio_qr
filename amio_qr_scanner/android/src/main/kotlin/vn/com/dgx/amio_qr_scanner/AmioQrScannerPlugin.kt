package vn.com.dgx.amio_qr_scanner

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.google.mlkit.vision.barcode.BarcodeScannerOptions
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.common.InputImage
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import java.io.File

internal object QrEngine {
    var messenger: BinaryMessenger? = null
    var activity: Activity? = null
    var appContext: Context? = null
}

class AmioQrScannerPlugin :
    FlutterPlugin,
    ActivityAware,
    MethodChannel.MethodCallHandler,
    PluginRegistry.RequestPermissionsResultListener,
    PluginRegistry.ActivityResultListener {

    private var activityBinding: ActivityPluginBinding? = null
    private var pluginChannel: MethodChannel? = null

    private var permissionBooleanResult: MethodChannel.Result? = null
    private var permissionStatusResult: MethodChannel.Result? = null
    private var pickImageResult: MethodChannel.Result? = null
    private var hasRequestedPermissionBefore = false

    private val imageQrScanner by lazy {
        BarcodeScanning.getClient(
            BarcodeScannerOptions.Builder()
                .setBarcodeFormats(Barcode.FORMAT_QR_CODE)
                .build()
        )
    }

    companion object {
        const val VIEW_TYPE = "vn.com.dgx/amio_qr_scanner/view"
        const val PLUGIN_CHANNEL = "vn.com.dgx/amio_qr_scanner/plugin"
        const val PERMISSION_REQUEST = 9281
        const val PICK_IMAGE_REQUEST = 9282
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        QrEngine.messenger = binding.binaryMessenger
        QrEngine.appContext = binding.applicationContext

        pluginChannel = MethodChannel(binding.binaryMessenger, PLUGIN_CHANNEL).also {
            it.setMethodCallHandler(this)
        }

        binding.platformViewRegistry.registerViewFactory(
            VIEW_TYPE,
            QrScannerViewFactory(this)
        )
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "checkPermission" -> {
                result.success(getCurrentPermissionStatus())
            }

            "requestPermission" -> {
                requestCameraPermissionStatus(result)
            }

            "openAppSettings" -> {
                result.success(openAppSettings())
            }

            "scanImagePath" -> {
                val path = call.argument<String>("path")
                if (path.isNullOrBlank()) {
                    result.error("INVALID_PATH", "Image path is empty", null)
                    return
                }
                val uri = if (path.startsWith("content://") || path.startsWith("file://")) {
                    Uri.parse(path)
                } else {
                    Uri.fromFile(File(path))
                }
                scanImageUri(uri, result)
            }

            "pickAndScanImage" -> {
                pickImageFromGallery(result)
            }

            else -> result.notImplemented()
        }
    }

    private fun getCurrentPermissionStatus(): String {
        val ctx = QrEngine.activity ?: QrEngine.appContext ?: return "notDetermined"
        val granted = ContextCompat.checkSelfPermission(
            ctx,
            Manifest.permission.CAMERA
        ) == PackageManager.PERMISSION_GRANTED

        if (granted) return "granted"

        val currentActivity = QrEngine.activity
        if (currentActivity != null && hasRequestedPermissionBefore) {
            val shouldShowRationale = ActivityCompat.shouldShowRequestPermissionRationale(
                currentActivity,
                Manifest.permission.CAMERA
            )
            return if (shouldShowRationale) "denied" else "permanentlyDenied"
        }

        return "notDetermined"
    }

    fun requestCameraPermissionStatus(result: MethodChannel.Result) {
        val currentActivity = QrEngine.activity

        if (currentActivity == null) {
            result.error("NO_ACTIVITY", "Activity is unavailable", null)
            return
        }

        if (
            ContextCompat.checkSelfPermission(
                currentActivity,
                Manifest.permission.CAMERA
            ) == PackageManager.PERMISSION_GRANTED
        ) {
            result.success("granted")
            return
        }

        if (permissionStatusResult != null || permissionBooleanResult != null) {
            result.error(
                "PERMISSION_PENDING",
                "A permission request is already running",
                null
            )
            return
        }

        permissionStatusResult = result
        hasRequestedPermissionBefore = true

        ActivityCompat.requestPermissions(
            currentActivity,
            arrayOf(Manifest.permission.CAMERA),
            PERMISSION_REQUEST
        )
    }

    fun requestCameraPermission(result: MethodChannel.Result) {
        val currentActivity = QrEngine.activity

        if (currentActivity == null) {
            result.error("NO_ACTIVITY", "Activity is unavailable", null)
            return
        }

        if (
            ContextCompat.checkSelfPermission(
                currentActivity,
                Manifest.permission.CAMERA
            ) == PackageManager.PERMISSION_GRANTED
        ) {
            result.success(true)
            return
        }

        if (permissionBooleanResult != null || permissionStatusResult != null) {
            result.error(
                "PERMISSION_PENDING",
                "A permission request is already running",
                null
            )
            return
        }

        permissionBooleanResult = result
        hasRequestedPermissionBefore = true

        ActivityCompat.requestPermissions(
            currentActivity,
            arrayOf(Manifest.permission.CAMERA),
            PERMISSION_REQUEST
        )
    }

    private fun openAppSettings(): Boolean {
        val context = QrEngine.activity ?: QrEngine.appContext ?: return false
        return try {
            val intent = Intent(
                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                Uri.fromParts("package", context.packageName, null)
            ).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(intent)
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun pickImageFromGallery(result: MethodChannel.Result) {
        val currentActivity = QrEngine.activity
        if (currentActivity == null) {
            result.error("NO_ACTIVITY", "Activity is unavailable", null)
            return
        }
        if (pickImageResult != null) {
            result.error("PICKER_ACTIVE", "Image picker is already active", null)
            return
        }

        pickImageResult = result
        try {
            val intent = Intent(Intent.ACTION_GET_CONTENT).apply {
                type = "image/*"
                addCategory(Intent.CATEGORY_OPENABLE)
            }
            currentActivity.startActivityForResult(
                Intent.createChooser(intent, "Chọn ảnh QR"),
                PICK_IMAGE_REQUEST
            )
        } catch (e: Exception) {
            pickImageResult = null
            result.error("PICKER_ERROR", e.message, null)
        }
    }

    private fun scanImageUri(uri: Uri, result: MethodChannel.Result) {
        val context = QrEngine.activity ?: QrEngine.appContext
        if (context == null) {
            result.error("NO_CONTEXT", "Context is unavailable", null)
            return
        }

        try {
            val inputImage = InputImage.fromFilePath(context, uri)
            val imgWidth = inputImage.width.coerceAtLeast(1).toDouble()
            val imgHeight = inputImage.height.coerceAtLeast(1).toDouble()

            imageQrScanner.process(inputImage)
                .addOnSuccessListener { barcodes ->
                    val qr = barcodes.firstOrNull {
                        it.format == Barcode.FORMAT_QR_CODE && !it.rawValue.isNullOrBlank()
                    }
                    if (qr == null) {
                        result.success(null)
                    } else {
                        val box = qr.boundingBox
                        result.success(
                            mapOf(
                                "type" to "result",
                                "source" to "image",
                                "value" to qr.rawValue,
                                "timestamp" to System.currentTimeMillis(),
                                "left" to ((box?.left ?: 0).toDouble() / imgWidth).coerceIn(0.0, 1.0),
                                "top" to ((box?.top ?: 0).toDouble() / imgHeight).coerceIn(0.0, 1.0),
                                "width" to ((box?.width() ?: 0).toDouble() / imgWidth).coerceIn(0.0, 1.0),
                                "height" to ((box?.height() ?: 0).toDouble() / imgHeight).coerceIn(0.0, 1.0)
                            )
                        )
                    }
                }
                .addOnFailureListener { e ->
                    result.error("SCAN_IMAGE_ERROR", e.message, null)
                }
        } catch (e: Exception) {
            result.error("IMAGE_READ_ERROR", e.message, null)
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ): Boolean {
        if (requestCode != PERMISSION_REQUEST) return false

        val granted =
            grantResults.isNotEmpty() &&
            grantResults[0] == PackageManager.PERMISSION_GRANTED

        permissionBooleanResult?.success(granted)
        permissionBooleanResult = null

        permissionStatusResult?.let { statusRes ->
            if (granted) {
                statusRes.success("granted")
            } else {
                val currentActivity = QrEngine.activity
                val showRationale = currentActivity != null &&
                    ActivityCompat.shouldShowRequestPermissionRationale(
                        currentActivity,
                        Manifest.permission.CAMERA
                    )
                statusRes.success(if (showRationale) "denied" else "permanentlyDenied")
            }
        }
        permissionStatusResult = null

        return true
    }

    override fun onActivityResult(
        requestCode: Int,
        resultCode: Int,
        data: Intent?
    ): Boolean {
        if (requestCode != PICK_IMAGE_REQUEST) return false

        val pendingResult = pickImageResult ?: return true
        pickImageResult = null

        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            pendingResult.success(null)
            return true
        }

        val uri = data.data!!
        scanImageUri(uri, pendingResult)
        return true
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activityBinding = binding
        QrEngine.activity = binding.activity
        binding.addRequestPermissionsResultListener(this)
        binding.addActivityResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activityBinding?.removeRequestPermissionsResultListener(this)
        activityBinding?.removeActivityResultListener(this)
        activityBinding = null
        QrEngine.activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activityBinding = binding
        QrEngine.activity = binding.activity
        binding.addRequestPermissionsResultListener(this)
        binding.addActivityResultListener(this)
    }

    override fun onDetachedFromActivity() {
        activityBinding?.removeRequestPermissionsResultListener(this)
        activityBinding?.removeActivityResultListener(this)
        activityBinding = null
        QrEngine.activity = null
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        pluginChannel?.setMethodCallHandler(null)
        pluginChannel = null

        permissionBooleanResult?.error("PLUGIN_DETACHED", "Plugin detached", null)
        permissionBooleanResult = null

        permissionStatusResult?.error("PLUGIN_DETACHED", "Plugin detached", null)
        permissionStatusResult = null

        pickImageResult?.error("PLUGIN_DETACHED", "Plugin detached", null)
        pickImageResult = null

        QrEngine.messenger = null
        QrEngine.appContext = null
    }
}

class QrScannerViewFactory(
    private val plugin: AmioQrScannerPlugin
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(
        context: Context,
        viewId: Int,
        args: Any?
    ): PlatformView {
        @Suppress("UNCHECKED_CAST")
        val creationParams = args as? Map<String, Any?>
        return QrCameraManager(
            context,
            viewId,
            plugin,
            creationParams
        )
    }
}
