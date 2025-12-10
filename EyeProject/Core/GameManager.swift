import SpriteKit

class GameManager {
    
    // MARK: - Properties
    
    private weak var scene: SKScene?
    private var eyes: [EyeAnimator] = []
    
    // Configuration
    private let maxEyesBeforeAngry = 20
    private let spawnInterval: TimeInterval = 0.5
    
    // State
    private var isAngryMode = false
    private var lastNoiseTime: TimeInterval = 0
    private var silenceStartTime: TimeInterval?
    private let silenceDurationToRemove: TimeInterval = 2.0
    
    // Angry mode exit
    private var angrySilenceStartTime: TimeInterval?
    private var requiredAngrySilenceDuration: TimeInterval = 0
    
    // Boss mode
    private var isBossMode = false
    private var bossEye: EyeAnimator?
    private var angryNoiseStartTime: TimeInterval?
    private var requiredAngryNoiseDuration: TimeInterval = TimeInterval.random(in: 2.0...3.0)
    
    // Boss eye states
    private var isBossAngry = false
    private var bossAngrySilenceStartTime: TimeInterval?
    private var requiredBossAngrySilenceDuration: TimeInterval = 0
    private var bossNormalSilenceStartTime: TimeInterval?
    private let bossNormalSilenceDuration: TimeInterval = 3.0
    
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
        if isBossMode {
            // Boss mode logic
            if isBossAngry {
                if let silenceStart = bossAngrySilenceStartTime {
                    let silenceDuration = currentTime - silenceStart
                    if silenceDuration >= requiredBossAngrySilenceDuration {
                        setBossAngry(false)
                    }
                }
            } else {
                if let silenceStart = bossNormalSilenceStartTime {
                    let silenceDuration = currentTime - silenceStart
                    if silenceDuration >= bossNormalSilenceDuration {
                        closeBossAndReset()
                    }
                }
            }
        } else if isAngryMode {
            if let angrySilenceStart = angrySilenceStartTime {
                let silenceDuration = currentTime - angrySilenceStart
                if silenceDuration >= requiredAngrySilenceDuration {
                    exitAngryMode()
                }
            }
            
            if let noiseStart = angryNoiseStartTime {
                let noiseDuration = currentTime - noiseStart
                
                if noiseDuration >= requiredAngryNoiseDuration {
                    enterBossMode()
                }
            }
        } else {
            if let silenceStart = silenceStartTime {
                let silenceDuration = currentTime - silenceStart
                if silenceDuration >= silenceDurationToRemove && eyes.count > 1 {
                    removeRandomEye()
                    silenceStartTime = currentTime
                }
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
        
        if isBossMode {
            bossNormalSilenceStartTime = nil
            bossAngrySilenceStartTime = nil
            
            if !isBossAngry {
                setBossAngry(true)
            }
        } else if isAngryMode {
            // Angry mode
            silenceStartTime = nil
            angrySilenceStartTime = nil
            
            if angryNoiseStartTime == nil {
                angryNoiseStartTime = currentTime
            }
            
        } else {
            // Normal mode
            silenceStartTime = nil
            
            if currentTime - lastNoiseTime >= spawnInterval {
                lastNoiseTime = currentTime
                
                if eyes.count < maxEyesBeforeAngry {
                    spawnEyeAtRandomPosition()
                } else {
                    enterAngryMode()
                }
            }
        }
    }
    
    private func handleSilence() {
        if isBossMode {
            if isBossAngry {
                if bossAngrySilenceStartTime == nil {
                    bossAngrySilenceStartTime = CACurrentMediaTime()
                }
            } else {
                if bossNormalSilenceStartTime == nil {
                    bossNormalSilenceStartTime = CACurrentMediaTime()
                }
            }
        } else if isAngryMode {
            // Angry mode
            angryNoiseStartTime = nil
            
            if angrySilenceStartTime == nil {
                angrySilenceStartTime = CACurrentMediaTime()
            }
        } else {
            // Normal mode
            if silenceStartTime == nil {
                silenceStartTime = CACurrentMediaTime()
            }
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
        
        let maxAttempts = 50
        
        for _ in 0..<maxAttempts {
            let x = CGFloat.random(in: minX...maxX)
            let y = CGFloat.random(in: minY...maxY)
            let position = CGPoint(x: x, y: y)
            
            var isValid = true
            
            for eye in eyes {
                let eyePosition = eye.getPosition()
                let eyeSafetyRadius = eye.getSafetyRadius()
                
                let newEyeSafetyRadius: CGFloat = 350
                let minDistance = eyeSafetyRadius + newEyeSafetyRadius
                
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
        
        return findBestAvailablePosition(minX: minX, maxX: maxX, minY: minY, maxY: maxY)
    }
    
    private func findBestAvailablePosition(minX: CGFloat, maxX: CGFloat, minY: CGFloat, maxY: CGFloat) -> CGPoint {
        var bestPosition = CGPoint.zero
        var maxMinDistance: CGFloat = 0
        
        for _ in 0..<20 {
            let x = CGFloat.random(in: minX...maxX)
            let y = CGFloat.random(in: minY...maxY)
            let position = CGPoint(x: x, y: y)
            
            var minDistance: CGFloat = .greatestFiniteMagnitude
            
            for eye in eyes {
                let eyePosition = eye.getPosition()
                let distance = hypot(position.x - eyePosition.x, position.y - eyePosition.y)
                minDistance = min(minDistance, distance)
            }
            
            if minDistance > maxMinDistance {
                maxMinDistance = minDistance
                bestPosition = position
            }
        }
        
        return bestPosition
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
        }
    }
    
    // MARK: - Angry Mode
    private func enterAngryMode() {
        isAngryMode = true
        angrySilenceStartTime = nil
        angryNoiseStartTime = nil
        
        requiredAngrySilenceDuration = TimeInterval.random(in: 3.0...5.0)

        for eye in eyes {
            eye.setAngry(true)
        }
    }
    
    private func exitAngryMode() {
        isAngryMode = false
        angrySilenceStartTime = nil
        angryNoiseStartTime = nil
        
        for eye in eyes {
            eye.setAngry(false)
        }
    }
    
    // MARK: - Boss Mode
    private func enterBossMode() {
        isBossMode = true
        isAngryMode = false
        isBossAngry = true
        angryNoiseStartTime = nil
        angrySilenceStartTime = nil
        bossAngrySilenceStartTime = nil
        bossNormalSilenceStartTime = nil
        
        requiredBossAngrySilenceDuration = TimeInterval.random(in: 3.0...5.0)
        requiredAngryNoiseDuration = TimeInterval.random(in: 3.0...5.0)
        
        closeAllEyes {
            self.spawnBossEye()
        }
    }
    
    private func closeAllEyes(completion: @escaping () -> Void) {
        guard !eyes.isEmpty else {
            completion()
            return
        }
        
        let group = DispatchGroup()
        
        for eye in eyes {
            group.enter()
            eye.removeFromScene(animated: true) {
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            self.eyes.removeAll()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                completion()
            }
        }
    }
    
    private func spawnBossEye() {
        let bossEye = EyeAnimator(position: .zero, isBoss: true)
        bossEye.addToScene(scene!)
        self.bossEye = bossEye
        
        bossEye.animateOpening()
        
        bossEye.setAngry(true)
        
        FaceTracker.shared.onFaceUpdate = { [weak self] position, detected in
            self?.bossEye?.update(facePosition: position, faceDetected: detected)
        }
    }
    
    private func setBossAngry(_ angry: Bool) {
        guard let bossEye = bossEye else { return }
        
        isBossAngry = angry
        bossAngrySilenceStartTime = nil
        bossNormalSilenceStartTime = nil
        
        bossEye.setAngry(angry)
    }
    
    private func closeBossAndReset() {
        guard let bossEye = bossEye else {
            resetGame()
            return
        }
        
        bossEye.removeFromScene(animated: true) { [weak self] in
            self?.bossEye = nil
            self?.resetGame()
        }
    }
    
    private func resetGame() {
        isBossMode = false
        isAngryMode = false
        isBossAngry = false
        bossEye = nil
        angryNoiseStartTime = nil
        angrySilenceStartTime = nil
        bossAngrySilenceStartTime = nil
        bossNormalSilenceStartTime = nil
        silenceStartTime = nil
        lastNoiseTime = 0
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.spawnEye(at: .zero, animated: true)
        }
    }
}
