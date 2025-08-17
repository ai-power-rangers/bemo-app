import UIKit
import AVFoundation

class ViewController: UIViewController {
    // MARK: - Properties
    private var integratedPipeline: TPIntegratedPipeline!
    private var captureSession: AVCaptureSession!
    private var videoOutput: AVCaptureVideoDataOutput!
    private var previewLayer: AVCaptureVideoPreviewLayer!
    private var overlayImageView: UIImageView!
    private var polygonPlotView: PolygonPlotView!
    private var currentCameraInfo: String = ""
    
    // UI Elements
    // Status and text labels removed for cleaner UI
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        initializePipeline()
        setupCamera()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startCamera()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopCamera()
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = .black
        
        // Overlay image view for visualizations
        overlayImageView = UIImageView()
        overlayImageView.contentMode = .scaleAspectFit  // Letterbox to match video
        overlayImageView.translatesAutoresizingMaskIntoConstraints = false
        overlayImageView.backgroundColor = .clear
        view.addSubview(overlayImageView)
        
        // Top-half polygon plotter
        polygonPlotView = PolygonPlotView()
        polygonPlotView.translatesAutoresizingMaskIntoConstraints = false
        polygonPlotView.backgroundColor = UIColor.clear
        polygonPlotView.isUserInteractionEnabled = false
        view.addSubview(polygonPlotView)
        
        NSLayoutConstraint.activate([
            // Overlay fills the entire view
            overlayImageView.topAnchor.constraint(equalTo: view.topAnchor),
            overlayImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlayImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            overlayImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        NSLayoutConstraint.activate([
            polygonPlotView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            polygonPlotView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            polygonPlotView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            polygonPlotView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.5)
        ])
    }
    
    private func initializePipeline() {
        // Path to tangram shapes configuration
        guard let modelPath = Bundle.main.path(forResource: "tangram_shapes_2d", ofType: "json") else {
            showError("Model file not found")
            return
        }
        
        // Path to YOLO model
        guard let yoloPath = Bundle.main.path(forResource: "best_aug16_realSynth", ofType: "mlmodelc") ?? 
                             Bundle.main.path(forResource: "best_aug16_realSynth", ofType: "mlpackage") else {
            showError("YOLO model not found")
            return
        }
        
        // Initialize the integrated pipeline
        do {
            // Pass models folder to C++ so colors from .mtl are used consistently
            let assetsDir = Bundle.main.path(forResource: "models", ofType: nil) ?? ""
            integratedPipeline = try TPIntegratedPipeline(
                modelPath: yoloPath,
                tangramModelsJSON: modelPath,
                assetsDir: assetsDir
            )
            // Pipeline initialized successfully
        } catch {
            showError("Failed to initialize pipeline: \(error.localizedDescription)")
        }
    }
    
    private func setupCamera() {
        captureSession = AVCaptureSession()
        
        // Get front camera with ultra-wide preference
        guard let camera = getFrontFacingCamera() else {
            showError("No front camera available")
            return
        }
        
        print("📱 Using camera: \(camera.localizedName)")
        logCameraCapabilities(camera)
        
        // Update camera info for display
        if camera.deviceType == .builtInUltraWideCamera {
            currentCameraInfo = "Front Ultra-Wide"
        } else if camera.deviceType == .builtInWideAngleCamera {
            if #available(iOS 13.0, *) {
                let fov = camera.activeFormat.videoFieldOfView
                currentCameraInfo = fov > 70 ? "Front Wide (\(Int(fov))°)" : "Front Camera (\(Int(fov))°)"
            } else {
                currentCameraInfo = "Front Wide"
            }
        } else {
            currentCameraInfo = "Front Camera"
        }
        
        // Camera info stored but not displayed
        // self.currentCameraInfo contains camera details
        
        do {
            let input = try AVCaptureDeviceInput(device: camera)
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
            }
            
            // Configure for highest resolution
            configureForHighestResolution(camera)
            
            // Set session preset after adding input
            let preferredPresets: [AVCaptureSession.Preset] = [.hd4K3840x2160, .hd1920x1080, .hd1280x720, .high]
            for preset in preferredPresets {
                if captureSession.canSetSessionPreset(preset) {
                    captureSession.sessionPreset = preset
                    print("Selected camera session preset: \(preset)")
                    break
                }
            }
            
            // Video output
            videoOutput = AVCaptureVideoDataOutput()
            videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
            videoOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
            videoOutput.alwaysDiscardsLateVideoFrames = true
            
            if captureSession.canAddOutput(videoOutput) {
                captureSession.addOutput(videoOutput)
                
                // Configure connection for front camera
                if let connection = videoOutput.connection(with: .video) {
                    connection.videoOrientation = .portrait
                    // Mirror front camera for natural selfie view
                    connection.isVideoMirrored = true
                    print("🪞 Front camera mirroring enabled")
                }
            }
            
            // Preview layer
            previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
            previewLayer.videoGravity = .resizeAspect  // Letterbox to show full frame
            previewLayer.frame = view.bounds
            view.layer.insertSublayer(previewLayer, at: 0)
            
        } catch {
            showError("Camera setup failed: \(error)")
        }
    }
    
    private func startCamera() {
        if !captureSession.isRunning {
            captureSession.startRunning()
        }
    }
    
    private func stopCamera() {
        if captureSession.isRunning {
            captureSession.stopRunning()
        }
    }
    
    // MARK: - Camera Selection Helpers
    private func getFrontFacingCamera() -> AVCaptureDevice? {
        print("🔍 Searching for front-facing cameras...")
        
        // Use discovery session to find all front cameras
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [
                .builtInUltraWideCamera,
                .builtInWideAngleCamera,
                .builtInTrueDepthCamera,
                .builtInDualWideCamera,
                .builtInTripleCamera
            ],
            mediaType: .video,
            position: .front
        )
        
        let frontCameras = discoverySession.devices
        print("📱 Found \(frontCameras.count) front camera(s)")
        
        // Priority selection
        // 1. Try ultra-wide first
        if let ultraWide = frontCameras.first(where: { $0.deviceType == .builtInUltraWideCamera }) {
            print("✅ Selected: Ultra-wide front camera")
            return ultraWide
        }
        
        // 2. Try wide-angle
        if let wide = frontCameras.first(where: { $0.deviceType == .builtInWideAngleCamera }) {
            print("✅ Selected: Wide-angle front camera")
            return wide
        }
        
        // 3. Try TrueDepth
        if let trueDepth = frontCameras.first(where: { $0.deviceType == .builtInTrueDepthCamera }) {
            print("✅ Selected: TrueDepth front camera")
            return trueDepth
        }
        
        // 4. Use any available front camera
        if let anyFront = frontCameras.first {
            print("✅ Selected: Default front camera")
            return anyFront
        }
        
        print("❌ No front cameras found!")
        return nil
    }
    
    private func logCameraCapabilities(_ device: AVCaptureDevice) {
        print("📊 Camera Capabilities:")
        print("   Device Type: \(device.deviceType.rawValue)")
        print("   Position: \(device.position == .front ? "Front" : "Back")")
        
        let format = device.activeFormat
        if #available(iOS 13.0, *) {
            let fov = format.videoFieldOfView
            print("   Field of View: \(fov)°")
            if fov > 65 {
                print("   📐 Wide-angle camera (FOV > 65°)")
            }
        }
        
        // Check maximum resolution
        let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
        print("   Current Resolution: \(dimensions.width)x\(dimensions.height)")
    }
    
    private func configureForHighestResolution(_ device: AVCaptureDevice) {
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            
            print("🔧 Configuring camera for highest resolution...")
            
            // Find the highest resolution format that supports 30 FPS
            var bestFormat: AVCaptureDevice.Format? = nil
            var bestArea: Int32 = 0
            
            for format in device.formats {
                let dims = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
                let area = dims.width * dims.height
                
                let supports30fps = format.videoSupportedFrameRateRanges.contains { range in
                    range.minFrameRate <= 30.0 && 30.0 <= range.maxFrameRate
                }
                
                if supports30fps && area > bestArea {
                    bestArea = area
                    bestFormat = format
                }
            }
            
            if let format = bestFormat {
                device.activeFormat = format
                // Lock to 30 FPS
                let desired = CMTime(value: 1, timescale: 30)
                device.activeVideoMinFrameDuration = desired
                device.activeVideoMaxFrameDuration = desired
                
                let dims = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
                print("✅ Set format: \(dims.width)x\(dims.height) @30fps")
            }
        } catch {
            print("❌ Failed to configure camera: \(error)")
        }
    }
    
    // MARK: - Helpers
    private func showError(_ message: String) {
        // Log error to console instead of displaying in UI
        print("❌ Error: \(message)")
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
              let pipeline = integratedPipeline else { return }
        
        // Process frame through integrated pipeline
        let startTime = CACurrentMediaTime()
        
        do {
            let options = TPTangramOptions()
            options.renderOverlays = true
            options.lockingEnabled = true
            
            let result = try pipeline.processFrame(
                pixelBuffer,
                viewSize: view.bounds.size,
                confidenceThreshold: 0.6,
                options: options
            )
            
            let processingTime = (CACurrentMediaTime() - startTime) * 1000
            
            // Update UI
            DispatchQueue.main.async {
                // Log detection results to console instead of UI
                if result.detections.isEmpty {
                    print("📦 No tangrams detected")
                } else {
                    print("📦 Detected \(result.detections.count) tangram(s):")
                    for detection in result.detections {
                        let className = detection.className
                        let confidence = detection.confidence
                        print("   - \(className): \(String(format: "%.1f%%", confidence * 100))")
                    }
                }
                
                // Update overlay
                if let combinedOverlay = result.combinedOverlay {
                    let ciImage = CIImage(cvPixelBuffer: combinedOverlay)
                    let context = CIContext()
                    if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
                        self.overlayImageView.image = UIImage(cgImage: cgImage)
                    }
                }
                // Update polygon plotter with model polygons only
                if let planeModel = result.tangramResult?.planeModelPolygons as? [NSNumber: [NSNumber]], !planeModel.isEmpty {
                    let modelColors = result.tangramResult?.modelColorsRGB as? [NSNumber: [NSNumber]]
                    self.polygonPlotView.update(modelPlanePolygons: planeModel, modelColorsRGB: modelColors)
                }
                
                // Log FPS to console
                let fps = 1000.0 / processingTime
                print(String(format: "⚡ %.1f FPS", fps))
            }
        } catch {
            print("Processing error: \(error)")
        }
    }
    
}