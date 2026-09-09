import CoreGraphics
import UIKit

enum ArenaGeometry {
    static let arenaBorderInset: CGFloat = 14
    static let logicalGameplayBounds = CGRect(x: 0, y: 0, width: 718, height: 377)

    static func fittedGameplayRect(in availableRect: CGRect) -> CGRect {
        guard availableRect.isFinite, availableRect.width > 0, availableRect.height > 0 else { return .zero }
        let scale = min(availableRect.width / logicalGameplayBounds.width, availableRect.height / logicalGameplayBounds.height)
        let size = CGSize(width: logicalGameplayBounds.width * scale, height: logicalGameplayBounds.height * scale)
        return CGRect(x: availableRect.midX - size.width / 2, y: availableRect.midY - size.height / 2,
                      width: size.width, height: size.height)
    }

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

extension CGPoint {
    var isFinite: Bool {
        x.isFinite && y.isFinite
    }
}

extension CGSize {
    var isFinite: Bool {
        width.isFinite && height.isFinite
    }
}

extension CGRect {
    var isFinite: Bool {
        origin.isFinite
            && size.isFinite
            && minX.isFinite
            && maxX.isFinite
            && minY.isFinite
            && maxY.isFinite
    }
}

extension CGVector {
    var isFinite: Bool {
        dx.isFinite && dy.isFinite
    }

    var length: CGFloat {
        hypot(dx, dy)
    }

    var normalized: CGVector {
        normalized(or: .zero)
    }

    func normalized(or fallback: CGVector) -> CGVector {
        let length = length
        guard isFinite, length.isFinite, length > 0 else {
            return fallback.isFinite ? fallback : .zero
        }

        return CGVector(dx: dx / length, dy: dy / length)
    }

    func clamped(toMaximumLength maximumLength: CGFloat) -> CGVector {
        guard isFinite, maximumLength.isFinite, maximumLength >= 0 else {
            return .zero
        }

        let length = length
        guard length.isFinite else {
            return .zero
        }
        guard length > maximumLength else {
            return self
        }

        let scale = maximumLength / length
        return CGVector(dx: dx * scale, dy: dy * scale)
    }
}
