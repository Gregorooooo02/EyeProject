import SpriteKit

class EyeAnimator {
    // MARK: Node Hierarchy
    private let eyeContainerNode: SKNode;
    private let eyeballNode: SKSpriteNode;
    private let irisNode: SKSpriteNode;
    private let pupilNode: SKSpriteNode;
    private let upperEyelidNode: SKSpriteNode;
    private let lowerEyelidNode: SKSpriteNode;
    
    // MARK: Configuration
    private let isBoss: Bool;
    private let normalEyeSize: CGFloat;
    private let angryEyeSize: CGFloat;
    private let bossEyeSize: CGFloat = 0.25;
    
    private let normalPupilSize: CGFloat = 1.0;
    private let angryPupilSize: CGFloat = 0.1;
    private let maxPupilOffset: CGFloat = 150.0;
    
    private let minBlinkInterval: TimeInterval = 0.1;
    private let maxBlinkInterval: TimeInterval = 3.0;
    private let blinkDuration: TimeInterval = 0.15;
    
    private let minBlinksBeforeSquint = 2;
    private let maxBlinksBeforeSquint = 5;
    private let squintIntensity: CGFloat = 0.5;
    private let minSquintDuration: TimeInterval = 1;
    private let maxSquintDuration: TimeInterval = 3;
    
    // MARK: - State
    private var isAngry = false;
    private var isBlinking = false;
    private var isSquinting = false;
    private var isOpening = false;
    private var isClosing = false;
    private var blinkCounter = 0;
    private var blinksUntilSquint = 0;
    
    private var currentEyeSize: CGFloat = 0.8;
    private var targetFacePosition = CGPoint.zero;
    private var eyelidMaxScale: CGFloat = 0.8;
    
    // Random look state
    private var isFaceTracked = true;
    private var randomLookPosition = CGPoint.zero;
    private var randomLookTimer: Timer?;
    
    // Angry random look parameters
    private let normalLookInterval = (min: 0.5, max: 2.5);
    private let angryLookInterval = (min: 0.1, max: 0.3);
    
    // MARK: Initialization
    init(position: CGPoint, isBoss: Bool = false) {
        self.isBoss = isBoss;
        
        if isBoss {
            self.normalEyeSize = bossEyeSize;
            self.angryEyeSize = bossEyeSize;
        } else {
            self.normalEyeSize = 0.05;
            self.angryEyeSize = 0.05;
        }
        
        eyeContainerNode = SKNode();
        
        eyeballNode = SKSpriteNode(imageNamed: "Eyeball");
        irisNode = SKSpriteNode(imageNamed: "Iris");
        pupilNode = SKSpriteNode(imageNamed: "Pupil");
        upperEyelidNode = SKSpriteNode(imageNamed: "UpperEyelid");
        lowerEyelidNode = SKSpriteNode(imageNamed: "LowerEyelid");
        
        eyeContainerNode.addChild(eyeballNode);
        eyeContainerNode.addChild(irisNode);
        eyeContainerNode.addChild(pupilNode);
        eyeContainerNode.addChild(upperEyelidNode);
        eyeContainerNode.addChild(lowerEyelidNode);
        
        eyeContainerNode.position = position;
        
        // Start settings
        setupNodes();
        
        blinksUntilSquint = Int.random(in: minBlinksBeforeSquint...maxBlinksBeforeSquint);
        
        if !isBoss {
            startBlinking();
        }
        
        startRandomLooking();
    }
    
    deinit {
        randomLookTimer?.invalidate();
    }
    
    private func setupNodes() {
        eyeContainerNode.setScale(normalEyeSize);
        currentEyeSize = normalEyeSize;
        
        eyeballNode.xScale = 1.0;
        eyeballNode.yScale = 0.8;
        eyeballNode.position = .zero;
        
        irisNode.color = .blue;
        irisNode.colorBlendFactor = 0.6;
        irisNode.position = .zero;
        
        pupilNode.setScale(normalPupilSize);
        pupilNode.position = .zero;
        
        let actualEyeHeight = eyeballNode.size.height * eyeballNode.yScale;
        
        upperEyelidNode.anchorPoint = CGPoint(x: 0.5, y: 1.0);
        lowerEyelidNode.anchorPoint = CGPoint(x: 0.5, y: 0.0);
        
        upperEyelidNode.xScale = 1.1;
        lowerEyelidNode.xScale = 1.1;
        upperEyelidNode.yScale = 0.0;
        lowerEyelidNode.yScale = 0.0;
        
        eyelidMaxScale = 1.0;
        
        upperEyelidNode.position = CGPoint(x: 0, y: actualEyeHeight / 1.5);
        lowerEyelidNode.position = CGPoint(x: 0, y: -actualEyeHeight / 1.5);
        
        upperEyelidNode.color = .black;
        upperEyelidNode.colorBlendFactor = 1.0;
        lowerEyelidNode.color = .black;
        lowerEyelidNode.colorBlendFactor = 1.0;
        
        eyeballNode.zPosition = 0;
        irisNode.zPosition = 1;
        pupilNode.zPosition = 2;
        upperEyelidNode.zPosition = 3;
        lowerEyelidNode.zPosition = 3;
    }
    
    func addToScene(_ scene: SKScene) {
        scene.addChild(eyeContainerNode);
    }
    
    func removeFromScene() {
        eyeContainerNode.removeFromParent();
    }
    
    func removeFromScene(animated: Bool, completion: (() -> Void)? = nil) {
        guard !isClosing else { return }
        
        if animated {
            isClosing = true;
            animateClosing {
                self.eyeContainerNode.removeFromParent();
                completion?();
            }
        } else {
            eyeContainerNode.removeFromParent();
            completion?();
        }
    }
    
    func getPosition() -> CGPoint {
        return eyeContainerNode.position;
    }
    
    func getSafetyRadius() -> CGFloat {
        let eyeSize = eyeballNode.size.width * currentEyeSize;
        let safetyBuffer: CGFloat = 1.5;
        return (eyeSize / 2.0) * safetyBuffer;
    }
    
    func animateOpening(completion: (() -> Void)? = nil) {
        isOpening = true;
        
        upperEyelidNode.yScale = eyelidMaxScale;
        lowerEyelidNode.yScale = eyelidMaxScale;
        
        eyeContainerNode.removeAllActions();
        
        let open = SKAction.scaleY(to: 0.0, duration: 0.5);
        open.timingMode = .easeOut;
        
        upperEyelidNode.run(open);
        lowerEyelidNode.run(open) { [weak self] in
            guard let self = self else { return }
            self.isOpening = false;
            
            if !self.isBoss {
                self.startBlinking();
            }
            
            completion?();
        }
    }
    
    func animateClosing(completion: (() -> Void)? = nil) {
        eyeContainerNode.removeAllActions();
        upperEyelidNode.removeAllActions();
        lowerEyelidNode.removeAllActions();
        
        let actualEyeHeight = eyeballNode.size.height * eyeballNode.yScale;
        let eyelidPositionY: CGFloat
        
        if eyeballNode.yScale >= 1.0 {
            eyelidPositionY = actualEyeHeight / 1.0
        } else {
            eyelidPositionY = actualEyeHeight / 1.5
        }
        
        upperEyelidNode.position.y = eyelidPositionY;
        lowerEyelidNode.position.y = -eyelidPositionY;
        
        let targetScale: CGFloat
        if isBoss {
            targetScale = 2.0
        } else if eyeballNode.yScale >= 1.0 {
            targetScale = 1.3
        } else {
            targetScale = eyelidMaxScale
        }
        
        let close = SKAction.scaleY(to: targetScale, duration: 0.5);
        close.timingMode = .easeIn;
        
        upperEyelidNode.run(close);
        lowerEyelidNode.run(close) {
            completion?();
        }
    }
    
    func setAngry(_ angry: Bool) {
        guard angry != isAngry else { return }
        isAngry = angry;
        
        if angry {
            enterAngryMode();
        } else {
            exitAngryMode();
        }
    }
    
    func update(facePosition: CGPoint, faceDetected: Bool) {
        isFaceTracked = faceDetected;
        
        if faceDetected {
            targetFacePosition = facePosition;
        } else {
            targetFacePosition = randomLookPosition;
        }
        
        updatePupilPosition();
    }
    
    private func startBlinking() {
        scheduleNextBlink();
    }
    
    private func scheduleNextBlink() {
        guard !isAngry else { return }
        
        let interval = TimeInterval.random(in: minBlinkInterval...maxBlinkInterval);
        
        let wait = SKAction.wait(forDuration: interval);
        let blink = SKAction.run { [weak self] in
            self?.performBlink();
        }
        
        eyeContainerNode.run(SKAction.sequence([wait, blink]));
    }
    
    private func performBlink() {
        guard !isAngry && !isBlinking && !isSquinting && !isOpening else {
            scheduleNextBlink();
            return;
        }
        
        isBlinking = true;
        blinkCounter += 1;
        
        let close = SKAction.scaleY(to: eyelidMaxScale, duration: blinkDuration * 0.5);
        close.timingMode = .easeIn;
        
        let open = SKAction.scaleY(to: 0.0, duration: blinkDuration * 0.5);
        open.timingMode = .easeOut;
        
        let sequence = SKAction.sequence([close, open]);
        
        upperEyelidNode.run(sequence);
        lowerEyelidNode.run(sequence) { [weak self] in
            self?.isBlinking = false
            self?.checkForSquint()
            self?.scheduleNextBlink()
        }
    }
    
    private func checkForSquint() {
        guard blinkCounter >= blinksUntilSquint else { return }
        guard !isAngry && !isSquinting else { return }
        
        performSquint();
    }
    
    private func performSquint() {
        isSquinting = true;
        blinkCounter = 0;
        blinksUntilSquint = Int.random(in: minBlinksBeforeSquint...maxBlinksBeforeSquint);
        
        let squintScale = eyelidMaxScale * squintIntensity;
        let duration = TimeInterval.random(in: minSquintDuration...maxSquintDuration);
        
        let squintDown = SKAction.scaleY(to: squintScale, duration: duration * 0.3);
        squintDown.timingMode = .easeOut;
        
        let hold = SKAction.wait(forDuration: duration * 0.4);
        
        let squintUp = SKAction.scaleY(to: 0.0, duration: duration * 0.3);
        squintUp.timingMode = .easeIn;
        
        let sequence = SKAction.sequence([squintDown, hold, squintUp]);
        
        upperEyelidNode.run(sequence);
        lowerEyelidNode.run(sequence) { [weak self] in
            self?.isSquinting = false
        }
    }
    
    private func enterAngryMode() {
        upperEyelidNode.removeAllActions();
        lowerEyelidNode.removeAllActions();
        
        isBlinking = false;
        isSquinting = false;
        
        upperEyelidNode.yScale = 0.0;
        lowerEyelidNode.yScale = 0.0;
        
        irisNode.color = .red;
        irisNode.colorBlendFactor = 1.0;
        
        stopRandomLooking();
        startRandomLooking();
        
        let eyeballScale = SKAction.scaleY(to: 1.0, duration: 0.3);
        eyeballScale.timingMode = .easeOut;
        eyeballNode.run(eyeballScale);
        
        let actualAngryEyeHeight = eyeballNode.size.height * 1.0;
        let moveEyelidsUp = SKAction.moveTo(y: actualAngryEyeHeight / 1.0, duration: 0.3);
        moveEyelidsUp.timingMode = .easeOut;
        let moveEyelidsDown = SKAction.moveTo(y: -actualAngryEyeHeight / 1.0, duration: 0.3);
        moveEyelidsDown.timingMode = .easeOut;
        upperEyelidNode.run(moveEyelidsUp);
        lowerEyelidNode.run(moveEyelidsDown);
        
        let scaleAction = SKAction.scale(to: angryEyeSize, duration: 0.3);
        scaleAction.timingMode = .easeOut;
        eyeContainerNode.run(scaleAction) { [weak self] in
            self?.currentEyeSize = self?.angryEyeSize ?? 1.0;
        }
        
        let scalePupil = SKAction.scale(to: angryPupilSize, duration: 0.3);
        scalePupil.timingMode = .easeOut;
        pupilNode.run(scalePupil);
        
        startVibration();
    }
    
    private func exitAngryMode() {
        eyeContainerNode.removeAction(forKey: "vibration");
        
        irisNode.color = .blue;
        irisNode.colorBlendFactor = 0.6;
        
        let eyeballScale = SKAction.scaleY(to: 0.8, duration: 0.3);
        eyeballScale.timingMode = .easeIn;
        eyeballNode.run(eyeballScale);
        
        let actualNormalEyeHeight = eyeballNode.size.height * 0.8;
        let moveEyelidsUp = SKAction.moveTo(y: actualNormalEyeHeight / 1.5, duration: 0.3);
        moveEyelidsUp.timingMode = .easeIn;
        let moveEyelidsDown = SKAction.moveTo(y: -actualNormalEyeHeight / 1.5, duration: 0.3);
        moveEyelidsDown.timingMode = .easeIn;
        upperEyelidNode.run(moveEyelidsUp);
        lowerEyelidNode.run(moveEyelidsDown);
        
        let scaleAction = SKAction.scale(to: normalEyeSize, duration: 0.3);
        scaleAction.timingMode = .easeIn;
        eyeContainerNode.run(scaleAction) { [weak self] in
            self?.currentEyeSize = self?.normalEyeSize ?? 0.8;
        }
        
        let scalePupil = SKAction.scale(to: normalPupilSize, duration: 0.3);
        scalePupil.timingMode = .easeIn;
        pupilNode.run(scalePupil);
        
        startBlinking();
        stopRandomLooking();
        startRandomLooking();
    }
    
    private var originalContainerPosition: CGPoint = .zero
    
    private func startVibration() {
        originalContainerPosition = eyeContainerNode.position;
        
        let vibrationAmount: CGFloat = 2.0;
        let vibrationSpeed: TimeInterval = 0.03;
        
        let randomVibrate = SKAction.run { [weak self] in
            guard let self = self else { return }
            let offsetX = CGFloat.random(in: -vibrationAmount...vibrationAmount);
            let offsetY = CGFloat.random(in: -vibrationAmount...vibrationAmount);
            self.eyeContainerNode.position = CGPoint(
                x: self.originalContainerPosition.x + offsetX, 
                y: self.originalContainerPosition.y + offsetY
            );
        }
        
        let wait = SKAction.wait(forDuration: vibrationSpeed);
        let sequence = SKAction.sequence([randomVibrate, wait]);
        let vibrate = SKAction.repeatForever(sequence);
        eyeContainerNode.run(vibrate, withKey: "vibration");
    }
    
    private func updatePupilPosition() {
        let offsetX = targetFacePosition.x * maxPupilOffset;
        let offsetY = targetFacePosition.y * maxPupilOffset;
        
        let scaleFactor = currentEyeSize / angryEyeSize;
        let scaledOffsetX = offsetX * scaleFactor;
        let scaledOffsetY = offsetY * scaleFactor;
        
        let duration: TimeInterval = isFaceTracked ? 0.1 : 0.5;
        let move = SKAction.move(to: CGPoint(x: scaledOffsetX, y: scaledOffsetY), duration: duration);
        move.timingMode = .easeOut;
        
        irisNode.run(move);
        pupilNode.run(move);
    }
    
    // MARK: - Random Looking
    private func startRandomLooking() {
        stopRandomLooking();
        scheduleNextRandomLook();
    }
    
    private func stopRandomLooking() {
        randomLookTimer?.invalidate();
        randomLookTimer = nil;
    }
    
    private func scheduleNextRandomLook() {
        let interval: TimeInterval;
        let lookRange: (x: ClosedRange<CGFloat>, y: ClosedRange<CGFloat>);
        
        if isAngry {
            interval = TimeInterval.random(in: angryLookInterval.min...angryLookInterval.max);
            lookRange = (x: -1.5...1.5, y: -1.5...1.5);
        } else {
            interval = TimeInterval.random(in: normalLookInterval.min...normalLookInterval.max);
            lookRange = (x: -0.8...0.8, y: -0.7...0.7);
        }
        
        randomLookTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            self?.performRandomLook();
        }
    }
    
    private func performRandomLook() {
        let lookRange: (x: ClosedRange<CGFloat>, y: ClosedRange<CGFloat>);
        
        if isAngry {
            lookRange = (x: -1.0...1.0, y: -1.0...1.0);
        } else {
            lookRange = (x: -0.8...0.8, y: -0.7...0.7);
        }
        
        let randomX = CGFloat.random(in: lookRange.x);
        let randomY = CGFloat.random(in: lookRange.y);
        
        randomLookPosition = CGPoint(x: randomX, y: randomY);
        
        scheduleNextRandomLook();
    }
}
