import UIKit

struct ArenaHUDLayout: Equatable {
    let scoreCapsuleFrame: CGRect
    let bestCapsuleFrame: CGRect
    let comboCapsuleFrame: CGRect
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

        let topCapsuleHeight: CGFloat = 28
        let scoreCapsuleWidth = min(190, safeRect.width * 0.42)
        let bestCapsuleWidth = min(126, safeRect.width * 0.3)
        let comboCapsuleWidth = min(300, safeRect.width * 0.58)

        scoreCapsuleFrame = CGRect(
            x: safeRect.minX - 6,
            y: safeRect.maxY - topCapsuleHeight,
            width: scoreCapsuleWidth,
            height: topCapsuleHeight
        )
        bestCapsuleFrame = CGRect(
            x: safeRect.maxX - bestCapsuleWidth + 6,
            y: safeRect.maxY - topCapsuleHeight,
            width: bestCapsuleWidth,
            height: topCapsuleHeight
        )
        comboCapsuleFrame = CGRect(
            x: safeRect.midX - comboCapsuleWidth / 2,
            y: safeRect.minY - 6,
            width: comboCapsuleWidth,
            height: 30
        )

        timerPosition = CGPoint(x: scoreCapsuleFrame.minX + 10, y: scoreCapsuleFrame.midY)
        comboPosition = CGPoint(x: comboCapsuleFrame.midX, y: comboCapsuleFrame.midY)
        bestMarkerPosition = CGPoint(x: bestCapsuleFrame.maxX - 10, y: bestCapsuleFrame.midY)
    }
}
