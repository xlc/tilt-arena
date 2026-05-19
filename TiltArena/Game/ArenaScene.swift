import SpriteKit

final class ArenaScene: SKScene {
    private let theme = ArenaTheme.darkTacticalRadar
    private var arenaRoot = SKNode()

    override init(size: CGSize) {
        super.init(size: size)
        anchorPoint = .zero
        backgroundColor = theme.backgroundColor
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("ArenaScene does not support storyboard initialization.")
    }

    override func didMove(to view: SKView) {
        rebuildArena()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        rebuildArena()
    }

    private func rebuildArena() {
        arenaRoot.removeFromParent()
        arenaRoot = ArenaThemeRenderer(theme: theme).makeArenaBackground(size: size)
        addChild(arenaRoot)
    }
}
