import UIKit

struct ArenaLandscapeUILayout: Equatable {
    private static let controlBorderGap: CGFloat = 12

    let sceneSize: CGSize
    let safeAreaInsets: UIEdgeInsets
    let margin: CGFloat

    var safeRect: CGRect {
        ArenaGeometry.safeRect(sceneSize: sceneSize, safeAreaInsets: safeAreaInsets, margin: margin)
    }

    var controlRect: CGRect {
        let inset = ArenaGeometry.arenaBorderInset + Self.controlBorderGap
        return safeRect.insetBy(dx: inset, dy: inset)
    }

    var titlePosition: CGPoint {
        CGPoint(x: safeRect.minX, y: safeRect.maxY)
    }

    var bottomCenterPosition: CGPoint {
        CGPoint(x: safeRect.midX, y: safeRect.minY)
    }

    var lowerRightButtonFrame: CGRect {
        CGRect(x: controlRect.maxX - 156, y: controlRect.minY, width: 156, height: 48)
    }

    func stackedLowerRightButtonFrame(aboveBottomControlHeight bottomControlHeight: CGFloat) -> CGRect {
        let size = CGSize(width: 156, height: 48)
        let preferredY = controlRect.minY + max(0, bottomControlHeight) + 16
        let maximumY = max(controlRect.minY, controlRect.maxY - size.height)

        return CGRect(
            x: controlRect.maxX - size.width,
            y: min(preferredY, maximumY),
            width: size.width,
            height: size.height
        )
    }

    var centerPoint: CGPoint {
        CGPoint(x: safeRect.midX, y: safeRect.midY)
    }

    func leftColumnFrame(width: CGFloat) -> CGRect {
        CGRect(
            x: safeRect.minX,
            y: safeRect.minY + 56,
            width: min(width, safeRect.width * 0.46),
            height: max(0, safeRect.height - 96)
        )
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
