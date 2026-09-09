import UIKit

struct ArenaLandscapeUILayout: Equatable {
    private static let controlBorderGap: CGFloat = 12
    private static let gameplayEdgeMargin: CGFloat = 8

    let sceneSize: CGSize
    let safeAreaInsets: UIEdgeInsets
    let margin: CGFloat

    var safeRect: CGRect {
        ArenaGeometry.safeRect(sceneSize: sceneSize, safeAreaInsets: safeAreaInsets, margin: margin)
    }

    var gameplayRect: CGRect {
        ArenaGeometry.landscapeGameplayRect(
            sceneSize: sceneSize,
            safeAreaInsets: safeAreaInsets,
            edgeMargin: Self.gameplayEdgeMargin
        )
    }

    var controlRect: CGRect {
        let inset = ArenaGeometry.arenaBorderInset + Self.controlBorderGap
        return safeRect.insetBy(dx: inset, dy: inset)
    }

    var gameplayWorldFrame: CGRect {
        ArenaGeometry.fittedGameplayRect(in: gameplayRect)
    }

    var gameplayWorldScale: CGFloat {
        gameplayWorldFrame.width / ArenaGeometry.logicalGameplayBounds.width
    }

    var lowerRightButtonFrame: CGRect {
        CGRect(x: controlRect.maxX - 156, y: controlRect.minY, width: 156, height: 48)
    }

    func rightColumnFrame(width: CGFloat) -> CGRect {
        let resolvedWidth = min(width, safeRect.width * 0.42)
        return CGRect(
            x: safeRect.maxX - resolvedWidth,
            y: safeRect.minY + 56,
            width: resolvedWidth,
            height: max(0, safeRect.height - 96)
        )
    }

    func bottomButtonFrame(index: Int, count: Int, buttonSize: CGSize) -> CGRect {
        let spacing: CGFloat = 12
        let totalWidth = CGFloat(count) * buttonSize.width + CGFloat(max(0, count - 1)) * spacing
        let minX = controlRect.midX - totalWidth / 2
        return CGRect(
            x: minX + CGFloat(index) * (buttonSize.width + spacing),
            y: controlRect.minY,
            width: buttonSize.width,
            height: buttonSize.height
        )
    }

}
