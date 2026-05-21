import UIKit

struct ArenaHUDLayout: Equatable {
    let timerPosition: CGPoint
    let comboPosition: CGPoint
    let pauseControlPosition: CGPoint

    init(
        sceneSize: CGSize,
        safeAreaInsets: UIEdgeInsets,
        margin: CGFloat,
        pauseControlSize: CGSize
    ) {
        let safeRect = ArenaGeometry.safeRect(
            sceneSize: sceneSize,
            safeAreaInsets: safeAreaInsets,
            margin: margin
        )
        let halfPauseWidth = pauseControlSize.width / 2
        let halfPauseHeight = pauseControlSize.height / 2

        timerPosition = CGPoint(x: safeRect.minX, y: safeRect.maxY)
        comboPosition = CGPoint(x: safeRect.midX, y: safeRect.minY)
        pauseControlPosition = CGPoint(
            x: max(safeRect.minX + halfPauseWidth, safeRect.maxX - halfPauseWidth),
            y: max(safeRect.minY + halfPauseHeight, safeRect.maxY - halfPauseHeight)
        )
    }
}
