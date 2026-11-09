import AVFoundation
import Flutter
import UIKit
import Vision

/// Custom container view tự động đồng bộ `previewLayer.frame` và orientation khi bố cục Flutter thay đổi.
final class QrPreviewContainerView: UIView {
    var previewLayer: AVCaptureVideoPreviewLayer? {
        didSet {
            if let layer = previewLayer {
                layer.frame = bounds
            }
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        previewLayer?.frame = bounds
        CATransaction.commit()
    }
}

final class QrCameraManager: NSObject,
    FlutterPlatformView,
    FlutterStreamHandler,
    AVCaptureVideoDataOutputSampleBufferDelegate {

    private let container: QrPreviewContainerView

    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(
        label: "vn.com.dgx.amio_qr_scanner.session"
    )

    private let detectionQueue = DispatchQueue(
        label: "vn.com.dgx.amio_qr_scanner.detection"
    )

    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var videoInput: AVCaptureDeviceInput?
    private var currentPosition: AVCaptureDevice.Position = .back

    private var eventSink: FlutterEventSink?
    private var isProcessing = false
    private var isRunning = false
    private var flashEnabled = false

    private var lastDetectionTime = Date.distantPast
    private var detectionTimeout: TimeInterval = 0.25
    private var duplicateTimeout: TimeInterval = 2.0

    private var lastDetectedValue: String?
    private var lastDetectedDuplicateTime = Date.distantPast

    private var scanWindowSize: CGFloat = 260.0
    private var restrictToScanWindow: Bool = true
    private var flutterViewWidth: CGFloat = 0.0
    private var flutterViewHeight: CGFloat = 0.0

    private let methodChannel: FlutterMethodChannel
    private let eventChannel: FlutterEventChannel

    init(
        frame: CGRect,
        viewId: Int64,
        messenger: FlutterBinaryMessenger,
        arguments: [String: Any]? = nil
    ) {
        container = QrPreviewContainerView(frame: frame)
        container.backgroundColor = .black

        methodChannel = FlutterMethodChannel(
            name: "vn.com.dgx/amio_qr_scanner/methods_\(viewId)",
            binaryMessenger: messenger
        )

        eventChannel = FlutterEventChannel(
            name: "vn.com.dgx/amio_qr_scanner/events_\(viewId)",
            binaryMessenger: messenger
        )

        super.init()

        if let args = arguments {
            applyConfig(args)
        }

        methodChannel.setMethodCallHandler(handle)
        eventChannel.setStreamHandler(self)

        configurePreview()
    }

    func view() -> UIView {
        return container
    }

    private func applyConfig(_ args: [String: Any]) {
        if let timeoutMs = args["detectionTimeout"] as? Double {
            detectionTimeout = timeoutMs / 1000.0
        }
        if let dupMs = args["duplicateTimeout"] as? Double {
            duplicateTimeout = dupMs / 1000.0
        }
        if let winSize = args["scanWindowSize"] as? Double {
            scanWindowSize = CGFloat(winSize)
        }
        if let restrict = args["restrictToScanWindow"] as? Bool {
            restrictToScanWindow = restrict
        }
        if let vw = args["viewWidth"] as? Double {
            flutterViewWidth = CGFloat(vw)
        }
        if let vh = args["viewHeight"] as? Double {
            flutterViewHeight = CGFloat(vh)
        }
        if let flash = args["enableFlash"] as? Bool {
            flashEnabled = flash
        }
        if let facing = args["cameraFacing"] as? String {
            currentPosition = facing == "front" ? .front : .back
        }
    }

    // MARK: - Channels

    func onListen(
        withArguments arguments: Any?,
        eventSink events: @escaping FlutterEventSink
    ) -> FlutterError? {
        eventSink = events
        return nil
    }

    func onCancel(
        withArguments arguments: Any?
    ) -> FlutterError? {
        eventSink = nil
        return nil
    }

    private func handle(
        _ call: FlutterMethodCall,
        result: @escaping FlutterResult
    ) {
        switch call.method {
        case "requestPermission":
            requestPermission(result)

        case "start":
            if let args = call.arguments as? [String: Any] {
                applyConfig(args)
            }
            start(result)

        case "updateScanWindow":
            if let args = call.arguments as? [String: Any] {
                if let winSize = args["scanWindowSize"] as? Double {
                    scanWindowSize = CGFloat(winSize)
                }
                if let restrict = args["restrictToScanWindow"] as? Bool {
                    restrictToScanWindow = restrict
                }
                if let vw = args["viewWidth"] as? Double {
                    flutterViewWidth = CGFloat(vw)
                }
                if let vh = args["viewHeight"] as? Double {
                    flutterViewHeight = CGFloat(vh)
                }
            }
            result(nil)

        case "resetDetection":
            lastDetectedValue = nil
            lastDetectedDuplicateTime = .distantPast
            result(nil)

        case "stop", "pause":
            stop()
            result(nil)

        case "toggleFlash":
            toggleFlash(result)

        case "switchCamera":
            switchCamera(result)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Permission

    private func requestPermission(_ result: @escaping FlutterResult) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            result(true)

        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    result(granted)
                }
            }

        default:
            result(false)
        }
    }

    // MARK: - Preview

    private func configurePreview() {
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = container.bounds
        container.layer.addSublayer(layer)
        container.previewLayer = layer
        previewLayer = layer
    }

    // MARK: - Camera

    private func start(_ result: @escaping FlutterResult) {
        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else {
            result(
                FlutterError(
                    code: "PERMISSION_DENIED",
                    message: "Camera permission denied",
                    details: nil
                )
            )
            return
        }

        sessionQueue.async {
            do {
                if self.session.inputs.isEmpty {
                    try self.configureSession()
                } else if self.videoInput?.device.position != self.currentPosition {
                    try self.rebindCameraInput(position: self.currentPosition)
                }

                if !self.session.isRunning {
                    self.session.startRunning()
                }

                self.isRunning = true

                if self.flashEnabled && self.currentPosition == .back {
                    self.applyTorch(enabled: true)
                }

                DispatchQueue.main.async {
                    result(nil)
                }
            } catch {
                DispatchQueue.main.async {
                    result(
                        FlutterError(
                            code: "CAMERA_ERROR",
                            message: error.localizedDescription,
                            details: nil
                        )
                    )
                }
            }
        }
    }

    private func configureSession() throws {
        session.beginConfiguration()
        session.sessionPreset = .high

        defer {
            session.commitConfiguration()
        }

        guard let device = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: currentPosition
        ) else {
            throw NSError(
                domain: "AmioQrScanner",
                code: -1,
                userInfo: [
                    NSLocalizedDescriptionKey: "Camera unavailable"
                ]
            )
        }

        let input = try AVCaptureDeviceInput(device: device)

        guard session.canAddInput(input) else {
            throw NSError(
                domain: "AmioQrScanner",
                code: -2,
                userInfo: [
                    NSLocalizedDescriptionKey: "Cannot add camera input"
                ]
            )
        }

        session.addInput(input)
        videoInput = input

        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: detectionQueue)

        guard session.canAddOutput(output) else {
            throw NSError(
                domain: "AmioQrScanner",
                code: -3,
                userInfo: [
                    NSLocalizedDescriptionKey: "Cannot add video output"
                ]
            )
        }

        session.addOutput(output)
    }

    private func rebindCameraInput(position: AVCaptureDevice.Position) throws {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        if let existing = videoInput {
            session.removeInput(existing)
        }

        guard let device = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: position
        ) else {
            if let existing = videoInput, session.canAddInput(existing) {
                session.addInput(existing)
            }
            throw NSError(
                domain: "AmioQrScanner",
                code: -4,
                userInfo: [NSLocalizedDescriptionKey: "Target camera unavailable"]
            )
        }

        let newInput = try AVCaptureDeviceInput(device: device)
        if session.canAddInput(newInput) {
            session.addInput(newInput)
            videoInput = newInput
        }
    }

    private func stop() {
        isRunning = false
        flashEnabled = false
        sessionQueue.async {
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }

    // MARK: - Orientation Helper

    private func currentImageOrientation() -> CGImagePropertyOrientation {
        let deviceOrientation = UIDevice.current.orientation
        let isFront = currentPosition == .front

        switch deviceOrientation {
        case .portraitUpsideDown:
            return isFront ? .rightMirrored : .left
        case .landscapeLeft:
            return isFront ? .downMirrored : .up
        case .landscapeRight:
            return isFront ? .upMirrored : .down
        case .portrait, .faceUp, .faceDown, .unknown:
            return isFront ? .leftMirrored : .right
        @unknown default:
            return isFront ? .leftMirrored : .right
        }
    }

    // MARK: - QR Detection

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard isRunning, !isProcessing else {
            return
        }

        let now = Date()

        guard now.timeIntervalSince(lastDetectionTime) >= detectionTimeout else {
            return
        }

        isProcessing = true
        lastDetectionTime = now

        defer {
            isProcessing = false
        }

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        let request = VNDetectBarcodesRequest()
        request.symbologies = [.qr]

        let handler = VNImageRequestHandler(
            cvPixelBuffer: pixelBuffer,
            orientation: currentImageOrientation(),
            options: [:]
        )

        do {
            try handler.perform([request])

            guard let observations = request.results else {
                return
            }

            for observation in observations {
                guard observation.symbology == .qr,
                      let value = observation.payloadStringValue,
                      !value.isEmpty else {
                    continue
                }

                let box = observation.boundingBox
                let normLeft = box.origin.x
                let normTop = 1.0 - box.origin.y - box.height
                let normWidth = box.width
                let normHeight = box.height

                let normalizedRect = CGRect(
                    x: normLeft,
                    y: normTop,
                    width: normWidth,
                    height: normHeight
                )

                if restrictToScanWindow && !isInsideScanWindow(normalizedRect) {
                    continue
                }

                let detectNow = Date()
                if lastDetectedValue == value &&
                    detectNow.timeIntervalSince(lastDetectedDuplicateTime) < duplicateTimeout {
                    break
                }

                lastDetectedValue = value
                lastDetectedDuplicateTime = detectNow

                emit([
                    "type": "result",
                    "source": "camera",
                    "value": value,
                    "timestamp": Int(detectNow.timeIntervalSince1970 * 1000),
                    "left": normLeft,
                    "top": normTop,
                    "width": normWidth,
                    "height": normHeight
                ])
                break
            }
        } catch {
            emit([
                "type": "error",
                "message": error.localizedDescription
            ])
        }
    }

    private func isInsideScanWindow(_ normalizedQrRect: CGRect) -> Bool {
        let viewW = flutterViewWidth > 0 ? flutterViewWidth : container.bounds.width
        let viewH = flutterViewHeight > 0 ? flutterViewHeight : container.bounds.height

        guard viewW > 0, viewH > 0 else { return true }

        let shortestSide = min(viewW, viewH)
        let winSize = min(max(scanWindowSize, 100.0), shortestSide)

        let winLeft = (viewW - winSize) / (2.0 * viewW)
        let winTop = (viewH - winSize) / (2.0 * viewH)
        let winRight = 1.0 - winLeft
        let winBottom = 1.0 - winTop

        let centerX = normalizedQrRect.midX
        let centerY = normalizedQrRect.midY

        return centerX >= winLeft &&
            centerX <= winRight &&
            centerY >= winTop &&
            centerY <= winBottom
    }

    // MARK: - Flash

    private func applyTorch(enabled: Bool) {
        guard let device = videoInput?.device, device.hasTorch else {
            flashEnabled = false
            return
        }
        do {
            try device.lockForConfiguration()
            if enabled {
                try device.setTorchModeOn(level: 1.0)
                flashEnabled = true
            } else {
                device.torchMode = .off
                flashEnabled = false
            }
            device.unlockForConfiguration()
        } catch {
            flashEnabled = false
        }
    }

    private func toggleFlash(_ result: FlutterResult) {
        guard let device = videoInput?.device,
              device.hasTorch,
              currentPosition == .back else {
            flashEnabled = false
            result(false)
            return
        }

        do {
            try device.lockForConfiguration()

            if device.torchMode == .on {
                device.torchMode = .off
                flashEnabled = false
            } else {
                try device.setTorchModeOn(level: 1.0)
                flashEnabled = true
            }

            device.unlockForConfiguration()
            result(flashEnabled)
        } catch {
            result(false)
        }
    }

    // MARK: - Switch Camera

    private func switchCamera(_ result: @escaping FlutterResult) {
        let targetPosition: AVCaptureDevice.Position =
            currentPosition == .back ? .front : .back

        sessionQueue.async {
            do {
                try self.rebindCameraInput(position: targetPosition)
                self.currentPosition = targetPosition
                self.flashEnabled = false

                DispatchQueue.main.async {
                    result(self.currentPosition == .front ? "front" : "back")
                }
            } catch {
                DispatchQueue.main.async {
                    result(
                        FlutterError(
                            code: "CAMERA_SWITCH_ERROR",
                            message: error.localizedDescription,
                            details: nil
                        )
                    )
                }
            }
        }
    }

    // MARK: - Event

    private func emit(_ data: [String: Any]) {
        DispatchQueue.main.async {
            self.eventSink?(data)
        }
    }

    deinit {
        methodChannel.setMethodCallHandler(nil)
        eventChannel.setStreamHandler(nil)

        let captureSession = session
        sessionQueue.async {
            if captureSession.isRunning {
                captureSession.stopRunning()
            }
        }
    }
}
