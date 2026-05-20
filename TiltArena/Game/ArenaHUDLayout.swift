import UIKit

struct ArenaHUDLayout: Equatable {
    let timerPosition: CGPoint
    let centerPosition: CGPoint
    let detailPosition: CGPoint
    let comboPosition: CGPoint
    let pauseControlPosition: CGPoint

    init(
        sceneSize: CGSize,
        safeAreaInsets: UIEdgeInsets,
        margin: CGFloat,
        pauseControlSize: CGSize
    ) {
        let safeRect = Self.safeRect(
            sceneSize: sceneSize,
            safeAreaInsets: safeAreaInsets,
            margin: margin
        )
        let halfPauseWidth = pauseControlSize.width / 2
        let halfPauseHeight = pauseControlSize.height / 2

        timerPosition = CGPoint(x: safeRect.minX, y: safeRect.maxY)
        centerPosition = CGPoint(x: safeRect.midX, y: safeRect.midY + 24)
        detailPosition = CGPoint(x: safeRect.midX, y: safeRect.midY - 12)
        comboPosition = CGPoint(x: safeRect.midX, y: safeRect.minY)
        pauseControlPosition = CGPoint(
            x: max(safeRect.minX + halfPauseWidth, safeRect.maxX - halfPauseWidth),
            y: max(safeRect.minY + halfPauseHeight, safeRect.maxY - halfPauseHeight)
        )
    }

    private static func safeRect(
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
