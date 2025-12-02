import SpriteKit
import GameplayKit

class GameScene: SKScene {
    
    override func didMove(to view: SKView) {
        FaceTracker.shared.startTracking();
        
        let testBox = SKShapeNode(rectOf: CGSize(width: 100, height: 100));
        testBox.fillColor = .green;
        testBox.strokeColor = .clear;
        addChild(testBox);
        
        FaceTracker.shared.onFaceUpdate = { position, detected in
            if detected {
                testBox.position = CGPoint(x: position.x * 400, y: position.y * 300);
                testBox.alpha = 1.0;
            } else {
                testBox.alpha = 0.3;
            }
        }
    }
    
    override func update(_ currentTime: TimeInterval) {
        // Called before each frame is rendered (Unity's Update() function)
    }
}
