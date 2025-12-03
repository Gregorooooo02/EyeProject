import AVFoundation

class AudioMonitor {
    
    // MARK: - Properties
    
    static let shared = AudioMonitor()
    
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    
    private var isMonitoring = false
    private var currentVolume: Float = 0.0
    
    private let noiseThreshold: Float = 0.02
    
    // Callbacks
    var onNoiseDetected: (() -> Void)?
    var onSilence: (() -> Void)?
    
    // Debug
    private var lastLogTime: TimeInterval = 0
    
    // MARK: - Initialization
    private init() {}
    
    // MARK: - Public Methods
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        audioEngine = AVAudioEngine()
        
        guard let audioEngine = audioEngine else {
            print("❌ Nie udało się utworzyć audio engine")
            return
        }
        
        inputNode = audioEngine.inputNode
        guard let inputNode = inputNode else {
            print("❌ Brak input node")
            return
        }
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.processAudioBuffer(buffer)
        }
        
        do {
            try audioEngine.start()
            isMonitoring = true
            print("✅ AudioMonitor uruchomiony")
        } catch {
            print("❌ Błąd uruchamiania audio engine: \(error)")
        }
    }
    
    func stopMonitoring() {
        guard isMonitoring else { return }
        
        inputNode?.removeTap(onBus: 0)
        audioEngine?.stop()
        isMonitoring = false
        print("⏹️ AudioMonitor zatrzymany")
    }
    
    func getCurrentVolume() -> Float {
        return currentVolume
    }
    
    // MARK: - Private Methods
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        
        let channelDataValue = channelData.pointee
        let frameLength = Int(buffer.frameLength)
        
        var sum: Float = 0.0
        for i in 0..<frameLength {
            let sample = channelDataValue[i]
            sum += abs(sample)
        }
        
        let averageAmplitude = sum / Float(frameLength)
        currentVolume = averageAmplitude
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
                        
            if averageAmplitude > self.noiseThreshold {
                self.onNoiseDetected?()
            } else {
                self.onSilence?()
            }
        }
    }
}
