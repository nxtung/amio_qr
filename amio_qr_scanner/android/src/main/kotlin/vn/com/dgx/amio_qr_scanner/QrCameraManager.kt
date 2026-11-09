package vn.com.dgx.amio_qr_scanner

import android.Manifest
import android.content.Context
import android.content.ContextWrapper
import android.content.pm.PackageManager
import android.graphics.Rect
import android.graphics.RectF
import android.view.View
import androidx.camera.core.Camera
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.content.ContextCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.LifecycleRegistry
import com.google.mlkit.vision.barcode.BarcodeScannerOptions
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.common.InputImage
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import kotlin.math.max

/**
 * Fallback LifecycleOwner trong trường hợp Activity chủ không kế thừa ComponentActivity / FlutterActivity.
 */
private class FallbackLifecycleOwner : LifecycleOwner {
    private val registry = LifecycleRegistry(this)

    init {
        registry.currentState = Lifecycle.State.INITIALIZED
    }

    fun markActive() {
        registry.currentState = Lifecycle.State.RESUMED
    }

    fun markDestroyed() {
        registry.currentState = Lifecycle.State.DESTROYED
    }

    override val lifecycle: Lifecycle
        get() = registry
}

class QrCameraManager(
    private val context: Context,
    private val viewId: Int,
    private val plugin: AmioQrScannerPlugin,
    creationParams: Map<String, Any?>? = null
) : PlatformView, MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    private val previewView = PreviewView(context)
    private val fallbackLifecycleOwner = FallbackLifecycleOwner()

    private val methodChannel: MethodChannel? = QrEngine.messenger?.let {
        MethodChannel(it, "vn.com.dgx/amio_qr_scanner/methods_$viewId")
    }

    private val eventChannel: EventChannel? = QrEngine.messenger?.let {
        EventChannel(it, "vn.com.dgx/amio_qr_scanner/events_$viewId")
    }

    private var eventSink: EventChannel.EventSink? = null

    private var cameraProvider: ProcessCameraProvider? = null
    private var camera: Camera? = null

    private var facing = CameraSelector.LENS_FACING_BACK
    private var flashEnabled = false

    private val analysisExecutor: ExecutorService =
        Executors.newSingleThreadExecutor()

    private val scanner = BarcodeScanning.getClient(
        BarcodeScannerOptions.Builder()
            .setBarcodeFormats(Barcode.FORMAT_QR_CODE)
            .build()
    )

    @Volatile
    private var processing = false
    @Volatile
    private var isCameraActive = false
    private var lastScanTime = 0L
    private var detectionTimeout = 250L
    private var duplicateTimeout = 2000L

    private var lastDetectedValue: String? = null
    private var lastDetectedTimestamp = 0L

    @Volatile
    private var scanWindowSizeDp = 260.0
    @Volatile
    private var restrictToScanWindow = true
    @Volatile
    private var flutterViewWidthDp = 0.0
    @Volatile
    private var flutterViewHeightDp = 0.0

    init {
        methodChannel?.setMethodCallHandler(this)
        eventChannel?.setStreamHandler(this)

        previewView.implementationMode =
            PreviewView.ImplementationMode.COMPATIBLE
        previewView.scaleType = PreviewView.ScaleType.FILL_CENTER

        creationParams?.let { applyConfig(it) }
    }

    private fun applyConfig(args: Map<String, Any?>) {
        (args["detectionTimeout"] as? Number)?.let {
            detectionTimeout = it.toLong()
        }
        (args["duplicateTimeout"] as? Number)?.let {
            duplicateTimeout = it.toLong()
        }
        (args["scanWindowSize"] as? Number)?.let {
            scanWindowSizeDp = it.toDouble()
        }
        (args["restrictToScanWindow"] as? Boolean)?.let {
            restrictToScanWindow = it
        }
        (args["viewWidth"] as? Number)?.let {
            flutterViewWidthDp = it.toDouble()
        }
        (args["viewHeight"] as? Number)?.let {
            flutterViewHeightDp = it.toDouble()
        }
        (args["enableFlash"] as? Boolean)?.let {
            flashEnabled = it
        }
        (args["cameraFacing"] as? String)?.let {
            facing = if (it == "front") {
                CameraSelector.LENS_FACING_FRONT
            } else {
                CameraSelector.LENS_FACING_BACK
            }
        }
    }

    override fun getView(): View = previewView

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "requestPermission" -> {
                plugin.requestCameraPermission(result)
            }

            "start" -> {
                @Suppress("UNCHECKED_CAST")
                val args = call.arguments as? Map<String, Any?>
                if (args != null) {
                    applyConfig(args)
                }
                startCamera(result)
            }

            "updateScanWindow" -> {
                @Suppress("UNCHECKED_CAST")
                val args = call.arguments as? Map<String, Any?>
                if (args != null) {
                    (args["scanWindowSize"] as? Number)?.let {
                        scanWindowSizeDp = it.toDouble()
                    }
                    (args["restrictToScanWindow"] as? Boolean)?.let {
                        restrictToScanWindow = it
                    }
                    (args["viewWidth"] as? Number)?.let {
                        flutterViewWidthDp = it.toDouble()
                    }
                    (args["viewHeight"] as? Number)?.let {
                        flutterViewHeightDp = it.toDouble()
                    }
                }
                result.success(null)
            }

            "resetDetection" -> {
                lastDetectedValue = null
                lastDetectedTimestamp = 0L
                result.success(null)
            }

            "stop" -> {
                stopCamera()
                result.success(null)
            }

            "pause" -> {
                stopCamera()
                result.success(null)
            }

            "toggleFlash" -> {
                val hasFlashUnit = camera?.cameraInfo?.hasFlashUnit() == true
                if (facing == CameraSelector.LENS_FACING_BACK && hasFlashUnit) {
                    flashEnabled = !flashEnabled
                    camera?.cameraControl?.enableTorch(flashEnabled)
                } else {
                    flashEnabled = false
                }
                result.success(flashEnabled)
            }

            "switchCamera" -> {
                val targetFacing = if (facing == CameraSelector.LENS_FACING_BACK) {
                    CameraSelector.LENS_FACING_FRONT
                } else {
                    CameraSelector.LENS_FACING_BACK
                }

                val provider = cameraProvider
                if (provider != null) {
                    val targetSelector = CameraSelector.Builder()
                        .requireLensFacing(targetFacing)
                        .build()
                    val available = try {
                        provider.hasCamera(targetSelector)
                    } catch (_: Exception) {
                        false
                    }
                    if (!available) {
                        result.success(
                            if (facing == CameraSelector.LENS_FACING_FRONT) "front" else "back"
                        )
                        return
                    }
                }

                facing = targetFacing
                flashEnabled = false

                startCamera(null)
                result.success(
                    if (facing == CameraSelector.LENS_FACING_FRONT) "front" else "back"
                )
            }

            else -> result.notImplemented()
        }
    }

    private fun resolveLifecycleOwner(): LifecycleOwner {
        val currentActivity = QrEngine.activity
        if (currentActivity is LifecycleOwner) {
            return currentActivity
        }

        var ctx: Context? = context
        while (ctx is ContextWrapper) {
            if (ctx is LifecycleOwner) {
                return ctx
            }
            ctx = ctx.baseContext
        }

        fallbackLifecycleOwner.markActive()
        return fallbackLifecycleOwner
    }

    private fun startCamera(result: MethodChannel.Result?) {
        if (QrEngine.activity == null) {
            result?.error("NO_ACTIVITY", "Activity unavailable", null)
            return
        }

        if (
            ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.CAMERA
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            result?.error(
                "PERMISSION_DENIED",
                "Camera permission not granted",
                null
            )
            return
        }

        val future = ProcessCameraProvider.getInstance(context)

        future.addListener({
            try {
                val provider = future.get()
                cameraProvider = provider
                provider.unbindAll()

                val preview = Preview.Builder().build()
                preview.setSurfaceProvider(previewView.surfaceProvider)

                val analysis = ImageAnalysis.Builder()
                    .setBackpressureStrategy(
                        ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST
                    )
                    .build()

                analysis.setAnalyzer(analysisExecutor) { image ->
                    analyze(image)
                }

                val desiredSelector = CameraSelector.Builder()
                    .requireLensFacing(facing)
                    .build()

                val effectiveSelector = if (provider.hasCamera(desiredSelector)) {
                    desiredSelector
                } else {
                    facing = CameraSelector.LENS_FACING_BACK
                    CameraSelector.DEFAULT_BACK_CAMERA
                }

                val lifecycleOwner = resolveLifecycleOwner()

                camera = provider.bindToLifecycle(
                    lifecycleOwner,
                    effectiveSelector,
                    preview,
                    analysis
                )

                isCameraActive = true

                if (flashEnabled && camera?.cameraInfo?.hasFlashUnit() == true) {
                    camera?.cameraControl?.enableTorch(true)
                } else {
                    flashEnabled = false
                }

                result?.success(null)
            } catch (e: Exception) {
                isCameraActive = false
                emitError(e.message ?: "Camera initialization failed")
                result?.error("CAMERA_ERROR", e.message, null)
            }
        }, ContextCompat.getMainExecutor(context))
    }

    @androidx.annotation.OptIn(
        androidx.camera.core.ExperimentalGetImage::class
    )
    private fun analyze(imageProxy: ImageProxy) {
        val now = System.currentTimeMillis()

        if (
            !isCameraActive ||
            processing ||
            now - lastScanTime < detectionTimeout
        ) {
            imageProxy.close()
            return
        }

        val mediaImage = imageProxy.image
        if (mediaImage == null) {
            imageProxy.close()
            return
        }

        processing = true
        lastScanTime = now

        val rotationDegrees = imageProxy.imageInfo.rotationDegrees
        val isRotated = rotationDegrees == 90 || rotationDegrees == 270
        val imgWidth = (if (isRotated) imageProxy.height else imageProxy.width)
            .coerceAtLeast(1)
            .toFloat()
        val imgHeight = (if (isRotated) imageProxy.width else imageProxy.height)
            .coerceAtLeast(1)
            .toFloat()

        val inputImage = InputImage.fromMediaImage(
            mediaImage,
            rotationDegrees
        )

        scanner.process(inputImage)
            .addOnSuccessListener { barcodes ->
                if (!isCameraActive) return@addOnSuccessListener

                for (barcode in barcodes) {
                    val rawValue = barcode.rawValue
                    if (barcode.format != Barcode.FORMAT_QR_CODE || rawValue.isNullOrBlank()) {
                        continue
                    }

                    val normalizedRect = normalizeBoundingBox(
                        barcode.boundingBox,
                        imgWidth,
                        imgHeight
                    )

                    if (restrictToScanWindow && !isInsideScanWindow(normalizedRect)) {
                        continue
                    }

                    val currentTime = System.currentTimeMillis()
                    if (
                        lastDetectedValue == rawValue &&
                        currentTime - lastDetectedTimestamp < duplicateTimeout
                    ) {
                        break
                    }

                    lastDetectedValue = rawValue
                    lastDetectedTimestamp = currentTime

                    emit(
                        mapOf(
                            "type" to "result",
                            "source" to "camera",
                            "value" to rawValue,
                            "timestamp" to currentTime,
                            "left" to normalizedRect.left.toDouble(),
                            "top" to normalizedRect.top.toDouble(),
                            "width" to normalizedRect.width().toDouble(),
                            "height" to normalizedRect.height().toDouble()
                        )
                    )
                    break
                }
            }
            .addOnFailureListener {
                if (isCameraActive) {
                    emitError(it.message ?: "QR detection failed")
                }
            }
            .addOnCompleteListener {
                processing = false
                imageProxy.close()
            }
    }

    /**
     * Chuyển đổi tọa độ pixel trên ảnh phân tích sang tọa độ chuẩn hóa (0.0 - 1.0)
     * tương ứng với khung hiển thị PreviewView (FILL_CENTER).
     */
    private fun normalizeBoundingBox(
        box: Rect?,
        imgWidth: Float,
        imgHeight: Float
    ): RectF {
        if (box == null) return RectF(0f, 0f, 0f, 0f)

        val viewW = previewView.width.toFloat().takeIf { it > 0f } ?: imgWidth
        val viewH = previewView.height.toFloat().takeIf { it > 0f } ?: imgHeight

        val scale = max(viewW / imgWidth, viewH / imgHeight)
        val scaledWidth = imgWidth * scale
        val scaledHeight = imgHeight * scale
        val offsetX = (scaledWidth - viewW) / 2f
        val offsetY = (scaledHeight - viewH) / 2f

        var leftPx = box.left * scale - offsetX
        val topPx = box.top * scale - offsetY
        val widthPx = box.width() * scale
        val heightPx = box.height() * scale

        if (facing == CameraSelector.LENS_FACING_FRONT) {
            leftPx = viewW - (leftPx + widthPx)
        }

        val normLeft = (leftPx / viewW).coerceIn(0f, 1f)
        val normTop = (topPx / viewH).coerceIn(0f, 1f)
        val normWidth = (widthPx / viewW).coerceIn(0f, 1f - normLeft)
        val normHeight = (heightPx / viewH).coerceIn(0f, 1f - normTop)

        return RectF(normLeft, normTop, normLeft + normWidth, normTop + normHeight)
    }

    /**
     * Kiểm tra tâm của mã QR có nằm trong vùng khung ngắm (Scan Window ROI) hay không.
     */
    private fun isInsideScanWindow(normalizedQrRect: RectF): Boolean {
        val density = context.resources.displayMetrics.density.takeIf { it > 0f } ?: 1f
        val viewW = if (flutterViewWidthDp > 0) {
            flutterViewWidthDp
        } else {
            (previewView.width / density).toDouble()
        }
        val viewH = if (flutterViewHeightDp > 0) {
            flutterViewHeightDp
        } else {
            (previewView.height / density).toDouble()
        }

        if (viewW <= 0.0 || viewH <= 0.0) return true

        val shortestSide = minOf(viewW, viewH)
        val windowSize = scanWindowSizeDp.coerceIn(100.0, shortestSide)

        val winLeft = ((viewW - windowSize) / (2.0 * viewW)).toFloat()
        val winTop = ((viewH - windowSize) / (2.0 * viewH)).toFloat()
        val winRight = 1f - winLeft
        val winBottom = 1f - winTop

        val centerX = normalizedQrRect.centerX()
        val centerY = normalizedQrRect.centerY()

        return centerX in winLeft..winRight && centerY in winTop..winBottom
    }

    private fun emit(event: Map<String, Any?>) {
        ContextCompat.getMainExecutor(context).execute {
            eventSink?.success(event)
        }
    }

    private fun emitError(message: String) {
        emit(
            mapOf(
                "type" to "error",
                "message" to message
            )
        )
    }

    private fun stopCamera() {
        isCameraActive = false
        cameraProvider?.unbindAll()
        camera = null
        flashEnabled = false
    }

    override fun dispose() {
        stopCamera()
        fallbackLifecycleOwner.markDestroyed()

        methodChannel?.setMethodCallHandler(null)
        eventChannel?.setStreamHandler(null)

        analysisExecutor.shutdown()
        scanner.close()
    }
}
