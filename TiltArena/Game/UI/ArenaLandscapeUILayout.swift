import UIKit

struct ArenaLandscapeUILayout: Equatable {
    let sceneSize: CGSize
    let safeAreaInsets: UIEdgeInsets
    let margin: CGFloat

    var safeRect: CGRect {
        Self.safeRect(sceneSize: sceneSize, safeAreaInsets: safeAreaInsets, margin: margin)
    }

    var titlePosition: CGPoint {
        CGPoint(x: safeRect.minX, y: safeRect.maxY)
    }

    var topRightControlPosition: CGPoint {
        CGPoint(x: safeRect.maxX, y: safeRect.maxY)
    }

    var bottomCenterPosition: CGPoint {
        CGPoint(x: safeRect.midX, y: safeRect.minY)
    }

    var lowerRightButtonFrame: CGRect {
        CGRect(x: safeRect.maxX - 156, y: safeRect.minY, width: 156, height: 48)
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
        let minX = safeRect.midX - totalWidth / 2
        return CGRect(
            x: minX + CGFloat(index) * (buttonSize.width + spacing),
            y: safeRect.minY,
            width: buttonSize.width,
            height: buttonSize.height
        )
    }

    static func safeRect(
        sceneSize: CGSize,
        safeAreaInsets: UIEdgeInsets,
        margin: CGFloat
    ) -> CGRect {
        let width = max(0, sceneSize.width)
        let height = max(0, sceneSize.height)
        let leftInset = max(0, min(safeAreaInsets.left, width))
        let rightInset = max(0, min(safeAreaInsets.right, width - leftInset))
        let bottomInset = max(0, min(safeAreaInsets.bottom, height))
        let topInset = max(0, min(safeAreaInsets.top, height - bottomInset))
        let minX = leftInset + margin
        let maxX = max(minX, width - rightInset - margin)
        let minY = bottomInset + margin
        let maxY = max(minY, height - topInset - margin)

        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}
