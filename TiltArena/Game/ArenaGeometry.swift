import CoreGraphics
import UIKit

enum ArenaGeometry {
    static let arenaBorderInset: CGFloat = 14

    static func squaredDistance(from lhs: CGPoint, to rhs: CGPoint) -> CGFloat {
        let dx = lhs.x - rhs.x
        let dy = lhs.y - rhs.y
        return dx * dx + dy * dy
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

    static func landscapeGameplayRect(
        sceneSize: CGSize,
        safeAreaInsets: UIEdgeInsets,
        edgeMargin: CGFloat
    ) -> CGRect {
        let width = max(0, sceneSize.width)
        let height = max(0, sceneSize.height)
        let margin = max(0, edgeMargin)
        let leftInset = max(0, min(safeAreaInsets.left, width))
        let rightInset = max(0, min(safeAreaInsets.right, width - leftInset))
        let minX = leftInset + margin
        let maxX = max(minX, width - rightInset - margin)
        let minY = min(margin, height)
        let maxY = max(minY, height - margin)

        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}
