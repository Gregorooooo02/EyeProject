import SpriteKit

class GameManager {
    
    // MARK: - Properties
    
    private weak var scene: SKScene?
    private var eyes: [EyeAnimator] = []
    
    // Configuration
    private let maxEyesBeforeAngry = 20
    private let spawnInterval: TimeInterval = 0.8 // Szybsze spawn przy hałasie
    
    // State
    private var isAngryMode = false
    private var lastNoiseTime: TimeInterval = 0
    private var silenceStartTime: TimeInterval?
    private let silenceDurationToRemove: TimeInterval = 1.5 // Szybsze usuwanie przy ciszy
    
    // Screen bounds
    private var screenBounds: CGRect = .zero
    
    // MARK: - Initialization
    init(scene: SKScene) {
        self.scene = scene
        self.screenBounds = scene.frame
    }
    
    // MARK: - Public Methods
    func start() {
        spawnEye(at: .zero, animated: true)
        setupAudioMonitoring()
    }
    
    func update(currentTime: TimeInterval) {
        if let silenceStart = silenceStartTime {
            let silenceDuration = currentTime - silenceStart
            if silenceDuration >= silenceDurationToRemove && eyes.count > 1 {
                removeRandomEye()
                silenceStartTime = currentTime
            }
        }
    }
    
    // MARK: - Audio Monitoring
    private func setupAudioMonitoring() {
        AudioMonitor.shared.startMonitoring()
        
        AudioMonitor.shared.onNoiseDetected = { [weak self] in
            self?.handleNoise()
        }
        
        AudioMonitor.shared.onSilence = { [weak self] in
            self?.handleSilence()
        }
    }
    
    private func handleNoise() {
        let currentTime = CACurrentMediaTime()
        
        silenceStartTime = nil
        
        if currentTime - lastNoiseTime >= spawnInterval {
            lastNoiseTime = currentTime
            
            if eyes.count < maxEyesBeforeAngry {
                spawnEyeAtRandomPosition()
            } else if !isAngryMode {
                enterAngryMode()
            }
        }
    }
    
    private func handleSilence() {
        if silenceStartTime == nil {
            silenceStartTime = CACurrentMediaTime()
        }
    }
    
    // MARK: - Eye Spawning
    private func spawnEye(at position: CGPoint, animated: Bool) {
        let eye = EyeAnimator(position: position)
        eye.addToScene(scene!)
        eyes.append(eye)
        
        if animated {
            animateEyeOpening(eye)
        }
        
        updateFaceTrackingCallback()
        
        print("👁️ Spawned eye #\(eyes.count) at \(position)")
    }
    
    private func updateFaceTrackingCallback() {
        FaceTracker.shared.onFaceUpdate = { [weak self] position, detected in
            guard let self = self else { return }
            for eye in self.eyes {
                eye.update(facePosition: position, faceDetected: detected)
            }
        }
    }
    
    private func spawnEyeAtRandomPosition() {
        let position = findValidSpawnPosition()
        spawnEye(at: position, animated: true)
    }
    
    private func findValidSpawnPosition() -> CGPoint {
        let margin: CGFloat = 100
        let minX = screenBounds.minX + margin
        let maxX = screenBounds.maxX - margin
        let minY = screenBounds.minY + margin
        let maxY = screenBounds.maxY - margin
        
        for _ in 0..<20 {
            let x = CGFloat.random(in: minX...maxX)
            let y = CGFloat.random(in: minY...maxY)
            let position = CGPoint(x: x, y: y)
            
            let minDistance: CGFloat = 250
            var isValid = true
            
            for eye in eyes {
                let eyePosition = eye.getPosition()
                let distance = hypot(position.x - eyePosition.x, position.y - eyePosition.y)
                if distance < minDistance {
                    isValid = false
                    break
                }
            }
            
            if isValid {
                return position
            }
        }
        
        return CGPoint(
            x: CGFloat.random(in: minX...maxX),
            y: CGFloat.random(in: minY...maxY)
        )
    }
    
    private func animateEyeOpening(_ eye: EyeAnimator) {
        eye.animateOpening()
    }
    
    // MARK: - Eye Removal
    
    private func removeRandomEye() {
        guard eyes.count > 1 else { return }
        
        let randomIndex = Int.random(in: 1..<eyes.count)
        let eye = eyes[randomIndex]
        
        eye.removeFromScene(animated: true) { [weak self] in
            self?.eyes.remove(at: randomIndex)
            print("👁️ Removed eye - remaining: \(self?.eyes.count ?? 0)")
        }
    }
    
    // MARK: - Angry Mode
    private func enterAngryMode() {
        isAngryMode = true

        for eye in eyes {
            eye.setAngry(true)
        }
        
        print("😡 ANGRY MODE ACTIVATED!")
    }
}
