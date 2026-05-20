import SpriteKit
import UIKit

final class GameViewController: UIViewController {
    private var hasPresentedScene = false

    override func loadView() {
        view = SKView(frame: .zero)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureSpriteView()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        guard let spriteView = view as? SKView else {
            return
        }

        if hasPresentedScene {
            spriteView.scene?.size = spriteView.bounds.size
        } else {
            let scene = ArenaScene(size: spriteView.bounds.size)
            scene.scaleMode = .resizeFill
            spriteView.presentScene(scene)
            hasPresentedScene = true
        }
    }

    override var prefersStatusBarHidden: Bool {
        true
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        .landscape
    }

    override var prefersHomeIndicatorAutoHidden: Bool {
        true
    }

    private func configureSpriteView() {
        guard let spriteView = view as? SKView else {
            return
        }

        spriteView.ignoresSiblingOrder = true
        spriteView.shouldCullNonVisibleNodes = true
        spriteView.preferredFramesPerSecond = 120

        #if DEBUG
        spriteView.showsFPS = true
        spriteView.showsNodeCount = true
        #endif
    }
}
