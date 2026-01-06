import AVFoundation
import Vision

class FaceTracker : NSObject {
    // MARK: Properties
    static let shared = FaceTracker()
    
    private let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let sequenceHandler = VNSequenceRequestHandler()
    
    private(set) var facePosition = CGPoint.zero
    private(set) var faceDetected = false
    private(set) var allFaces: [CGPoint] = []
    
    var onFaceUpdate: ((CGPoint, Bool) -> Void)?
    var onMultipleFacesUpdate: (([CGPoint]) -> Void)?
    
    private override init() {
        super.init()
    }
    
    func startTracking() {
        print("Turning on tracking...")
        setupCamera()
    }
    
    func stopTracking() {
        captureSession.stopRunning()
    }
        
    private func setupCamera() {
        captureSession.sessionPreset = .vga640x480
        
        // Find the camera
        guard let camera = AVCaptureDevice.default(for: .video) else {
            print("Could not find a camera in the device.")
            return
        }
        
        print("Camera found: \(camera.localizedName)")
        
        // Add camera as an input
        do {
            let input = try AVCaptureDeviceInput(device: camera)
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
            }
        } catch {
            print("Camera error: \(error)")
            return
        }
        
        // Video output configuration
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession.startRunning()
            print("Camera successfuly turned on.")
        }
    }
    
    private func detectFace(in pixelBuffer: CVPixelBuffer) {
        let request = VNDetectFaceRectanglesRequest { [weak self] request, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Detection error: \(error)")
                return
            }
            
            guard let observations = request.results as? [VNFaceObservation],
                  !observations.isEmpty else {
                self.faceDetected = false
                self.allFaces = []
                self.onFaceUpdate?(.zero, false)
                self.onMultipleFacesUpdate?([])
                return
            }
            
            var detectedFaces: [CGPoint] = []
            
            for face in observations {
                let boundingBox = face.boundingBox
                
                let x = (boundingBox.midX * 2) - 1
                let y = (boundingBox.midY * 2) - 1
                
                let normalizedPosition = CGPoint(x: -x, y: y)
                detectedFaces.append(normalizedPosition)
            }
            
            detectedFaces.sort { $0.x < $1.x }
            
            self.allFaces = detectedFaces
            self.facePosition = detectedFaces.first ?? .zero
            self.faceDetected = true
            
            self.onFaceUpdate?(self.facePosition, true)
            self.onMultipleFacesUpdate?(detectedFaces)
        }
        
        try? sequenceHandler.perform([request], on: pixelBuffer)
    }
}

extension FaceTracker: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return;
        }
        
        detectFace(in: pixelBuffer);
    }
}
