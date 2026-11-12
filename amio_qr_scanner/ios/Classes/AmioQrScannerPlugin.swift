import AVFoundation
import CoreImage
import Flutter
import PhotosUI
import UIKit
import Vision

public class AmioQrScannerPlugin: NSObject,
    FlutterPlugin,
    UIImagePickerControllerDelegate,
    UINavigationControllerDelegate {

    private var pickImageResult: FlutterResult?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = AmioQrScannerPlugin()

        let pluginChannel = FlutterMethodChannel(
            name: "vn.com.dgx/amio_qr_scanner/plugin",
            binaryMessenger: registrar.messenger()
        )
        registrar.addMethodCallDelegate(instance, channel: pluginChannel)

        let factory = QrScannerViewFactory(messenger: registrar.messenger())
        registrar.register(
            factory,
            withId: "vn.com.dgx/amio_qr_scanner/view"
        )
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "checkPermission":
            result(Self.currentPermissionStatusString())

        case "requestPermission":
            Self.requestPermissionStatus(result)

        case "openAppSettings":
            openAppSettings(result)

        case "scanImagePath":
            guard let args = call.arguments as? [String: Any],
                  let path = args["path"] as? String,
                  !path.isEmpty else {
                result(
                    FlutterError(
                        code: "INVALID_PATH",
                        message: "Image path is empty",
                        details: nil
                    )
                )
                return
            }
            scanImageAtPath(path, result: result)

        case "pickAndScanImage":
            pickAndScanImage(result: result)

        case "generateQrImage":
            guard let args = call.arguments as? [String: Any],
                  let data = args["data"] as? String,
                  !data.isEmpty else {
                result(
                    FlutterError(
                        code: "INVALID_DATA",
                        message: "QR data cannot be empty",
                        details: nil
                    )
                )
                return
            }
            let width = args["width"] as? Int ?? 512
            let height = args["height"] as? Int ?? 512
            let margin = args["margin"] as? Int ?? 1
            let ecLevel = args["errorCorrectionLevel"] as? String ?? "M"
            let codeColorNum = args["codeColor"] as? NSNumber
            let bgColorNum = args["backgroundColor"] as? NSNumber

            generateQrImage(
                data: data,
                width: width,
                height: height,
                margin: margin,
                ecLevel: ecLevel,
                codeColorNum: codeColorNum,
                bgColorNum: bgColorNum,
                result: result
            )

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    static func currentPermissionStatusString() -> String {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return "granted"
        case .notDetermined:
            return "notDetermined"
        case .denied:
            return "permanentlyDenied"
        case .restricted:
            return "restricted"
        @unknown default:
            return "denied"
        }
    }

    static func requestPermissionStatus(_ result: @escaping FlutterResult) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            result("granted")
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    result(granted ? "granted" : "permanentlyDenied")
                }
            }
        case .denied:
            result("permanentlyDenied")
        case .restricted:
            result("restricted")
        @unknown default:
            result("denied")
        }
    }

    private func openAppSettings(_ result: @escaping FlutterResult) {
        guard let url = URL(string: UIApplication.openSettingsURLString),
              UIApplication.shared.canOpenURL(url) else {
            result(false)
            return
        }
        UIApplication.shared.open(url, options: [:]) { success in
            DispatchQueue.main.async {
                result(success)
            }
        }
    }

    private func scanImageAtPath(_ path: String, result: @escaping FlutterResult) {
        let cleanPath = path.replacingOccurrences(of: "file://", with: "")
        guard let image = UIImage(contentsOfFile: cleanPath) else {
            result(
                FlutterError(
                    code: "IMAGE_READ_ERROR",
                    message: "Cannot load image at path: \(path)",
                    details: nil
                )
            )
            return
        }
        decodeQrFromUIImage(image, result: result)
    }

    private func decodeQrFromUIImage(_ image: UIImage, result: @escaping FlutterResult) {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let ciImage = CIImage(image: image) ?? image.cgImage.map({ CIImage(cgImage: $0) }) else {
                DispatchQueue.main.async {
                    result(nil)
                }
                return
            }

            let request = VNDetectBarcodesRequest()
            request.symbologies = [.qr]

            let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
            do {
                try handler.perform([request])
                guard let observation = request.results?.first(where: {
                    $0.symbology == .qr && !($0.payloadStringValue ?? "").isEmpty
                }),
                let value = observation.payloadStringValue else {
                    DispatchQueue.main.async {
                        result(nil)
                    }
                    return
                }

                let box = observation.boundingBox
                let payload: [String: Any] = [
                    "type": "result",
                    "source": "image",
                    "value": value,
                    "timestamp": Int(Date().timeIntervalSince1970 * 1000),
                    "left": box.origin.x,
                    "top": 1.0 - box.origin.y - box.height,
                    "width": box.width,
                    "height": box.height
                ]

                DispatchQueue.main.async {
                    result(payload)
                }
            } catch {
                DispatchQueue.main.async {
                    result(
                        FlutterError(
                            code: "SCAN_IMAGE_ERROR",
                            message: error.localizedDescription,
                            details: nil
                        )
                    )
                }
            }
        }
    }

    private func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
        let keyWindow = scenes
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
        var top = keyWindow?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }

    private func pickAndScanImage(result: @escaping FlutterResult) {
        guard pickImageResult == nil else {
            result(
                FlutterError(
                    code: "PICKER_ACTIVE",
                    message: "Image picker is already active",
                    details: nil
                )
            )
            return
        }

        guard let presenter = topViewController() else {
            result(
                FlutterError(
                    code: "NO_VIEW_CONTROLLER",
                    message: "Unable to find active view controller",
                    details: nil
                )
            )
            return
        }

        pickImageResult = result

        if #available(iOS 14.0, *) {
            var config = PHPickerConfiguration()
            config.selectionLimit = 1
            config.filter = .images
            let picker = PHPickerViewController(configuration: config)
            picker.delegate = self
            presenter.present(picker, animated: true)
        } else {
            let picker = UIImagePickerController()
            picker.sourceType = .photoLibrary
            picker.delegate = self
            presenter.present(picker, animated: true)
        }
    }

    public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
        let pending = pickImageResult
        pickImageResult = nil
        pending?(nil)
    }

    public func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    ) {
        picker.dismiss(animated: true)
        guard let pending = pickImageResult else { return }
        pickImageResult = nil

        guard let image = info[.originalImage] as? UIImage else {
            pending(nil)
            return
        }
        decodeQrFromUIImage(image, result: pending)
    }
}

@available(iOS 14.0, *)
extension AmioQrScannerPlugin: PHPickerViewControllerDelegate {
    public func picker(
        _ picker: PHPickerViewController,
        didFinishPicking results: [PHPickerResult]
    ) {
        picker.dismiss(animated: true)
        guard let pending = pickImageResult else { return }
        pickImageResult = nil

        guard let provider = results.first?.itemProvider,
              provider.canLoadObject(ofClass: UIImage.self) else {
            pending(nil)
            return
        }

        provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
            guard let self = self, let image = object as? UIImage else {
                DispatchQueue.main.async {
                    pending(nil)
                }
                return
            }
            self.decodeQrFromUIImage(image, result: pending)
        }
    }
}

// MARK: - QR Code Generation
extension AmioQrScannerPlugin {

    private func generateQrImage(
        data: String,
        width: Int,
        height: Int,
        margin: Int,
        ecLevel: String,
        codeColorNum: NSNumber?,
        bgColorNum: NSNumber?,
        result: @escaping FlutterResult
    ) {
        guard let qrFilter = CIFilter(name: "CIQRCodeGenerator") else {
            result(
                FlutterError(
                    code: "FILTER_ERROR",
                    message: "CIQRCodeGenerator is not available",
                    details: nil
                )
            )
            return
        }
        guard let dataBytes = data.data(using: .utf8) else {
            result(
                FlutterError(
                    code: "ENCODING_ERROR",
                    message: "Cannot encode data to UTF-8",
                    details: nil
                )
            )
            return
        }

        qrFilter.setValue(dataBytes, forKey: "inputMessage")
        let validEc: String
        switch ecLevel.uppercased() {
        case "L", "Q", "H": validEc = ecLevel.uppercased()
        default: validEc = "M"
        }
        qrFilter.setValue(validEc, forKey: "inputCorrectionLevel")

        guard let rawCiImage = qrFilter.outputImage else {
            result(
                FlutterError(
                    code: "GENERATION_ERROR",
                    message: "Failed to generate QR output image",
                    details: nil
                )
            )
            return
        }

        let codeColor = colorFromNumber(codeColorNum, defaultColor: .black)
        let bgColor = colorFromNumber(bgColorNum, defaultColor: .white)

        let colorFilter = CIFilter(name: "CIFalseColor")
        colorFilter?.setValue(rawCiImage, forKey: "inputImage")
        colorFilter?.setValue(CIColor(color: codeColor), forKey: "inputColor0")
        colorFilter?.setValue(CIColor(color: bgColor), forKey: "inputColor1")

        guard let coloredImage = colorFilter?.outputImage else {
            result(
                FlutterError(
                    code: "COLOR_ERROR",
                    message: "Failed to apply color filter",
                    details: nil
                )
            )
            return
        }

        let extent = coloredImage.extent
        let modWidth = extent.width
        let modHeight = extent.height
        let totalWidth = modWidth + CGFloat(margin * 2)
        let totalHeight = modHeight + CGFloat(margin * 2)

        let scaleX = CGFloat(width) / totalWidth
        let scaleY = CGFloat(height) / totalHeight
        let scale = min(scaleX, scaleY)

        let context = CIContext(options: [CIContextOption.useSoftwareRenderer: false])
        guard let cgImage = context.createCGImage(coloredImage, from: extent) else {
            result(
                FlutterError(
                    code: "RENDER_ERROR",
                    message: "Failed to create CGImage",
                    details: nil
                )
            )
            return
        }

        let targetW = max(1, Int(totalWidth * scale))
        let targetH = max(1, Int(totalHeight * scale))
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let bitmapContext = CGContext(
            data: nil,
            width: targetW,
            height: targetH,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            result(
                FlutterError(
                    code: "BITMAP_ERROR",
                    message: "Failed to create CGContext",
                    details: nil
                )
            )
            return
        }

        bitmapContext.interpolationQuality = .none
        bitmapContext.setFillColor(bgColor.cgColor)
        bitmapContext.fill(CGRect(x: 0, y: 0, width: targetW, height: targetH))

        let qrDrawRect = CGRect(
            x: CGFloat(margin) * scale,
            y: CGFloat(margin) * scale,
            width: modWidth * scale,
            height: modHeight * scale
        )
        bitmapContext.draw(cgImage, in: qrDrawRect)

        guard let finalCgImage = bitmapContext.makeImage() else {
            result(
                FlutterError(
                    code: "FINAL_IMAGE_ERROR",
                    message: "Failed to finalize QR image",
                    details: nil
                )
            )
            return
        }

        let finalUiImage = UIImage(cgImage: finalCgImage)
        guard let pngData = finalUiImage.pngData() else {
            result(
                FlutterError(
                    code: "PNG_ERROR",
                    message: "Failed to encode PNG data",
                    details: nil
                )
            )
            return
        }

        result(FlutterStandardTypedData(bytes: pngData))
    }

    private func colorFromNumber(_ number: NSNumber?, defaultColor: UIColor) -> UIColor {
        guard let num = number?.int64Value else { return defaultColor }
        let a = CGFloat((num >> 24) & 0xFF) / 255.0
        let r = CGFloat((num >> 16) & 0xFF) / 255.0
        let g = CGFloat((num >> 8) & 0xFF) / 255.0
        let b = CGFloat(num & 0xFF) / 255.0
        return UIColor(red: r, green: g, blue: b, alpha: a)
    }
}

class QrScannerViewFactory: NSObject, FlutterPlatformViewFactory {

    private let messenger: FlutterBinaryMessenger

    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        super.init()
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        FlutterStandardMessageCodec.sharedInstance()
    }

    func create(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> FlutterPlatformView {
        return QrCameraManager(
            frame: frame,
            viewId: viewId,
            messenger: messenger,
            arguments: args as? [String: Any]
        )
    }
}
