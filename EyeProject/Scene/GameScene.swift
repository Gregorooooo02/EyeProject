import SpriteKit
import GameplayKit

class GameScene: SKScene {
    private var gameManager: GameManager?;
    
    override func didMove(to view: SKView) {
        backgroundColor = .black;
        
        gameManager = GameManager(scene: self);
        
        FaceTracker.shared.startTracking();
        
        gameManager?.start();
    }
    
    override func update(_ currentTime: TimeInterval) {
        gameManager?.update(currentTime: currentTime);
    }
}
