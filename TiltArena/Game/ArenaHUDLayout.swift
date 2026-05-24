import UIKit

struct ArenaHUDLayout: Equatable {
    let timerPosition: CGPoint
    let comboPosition: CGPoint
    let bestMarkerPosition: CGPoint

    init(
        sceneSize: CGSize,
        safeAreaInsets: UIEdgeInsets,
        margin: CGFloat
    ) {
        let safeRect = ArenaGeometry.safeRect(
            sceneSize: sceneSize,
            safeAreaInsets: safeAreaInsets,
            margin: margin
        )

        timerPosition = CGPoint(x: safeRect.minX, y: safeRect.maxY)
        comboPosition = CGPoint(x: safeRect.midX, y: safeRect.minY)
        bestMarkerPosition = CGPoint(x: safeRect.maxX, y: safeRect.maxY)
    }
}
