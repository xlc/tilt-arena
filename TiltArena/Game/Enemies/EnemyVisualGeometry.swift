import CoreGraphics
import Foundation

enum EnemyVisualGeometry {
    static func travelRotation(for behavior: EnemyBehavior) -> CGFloat {
        switch behavior {
        case let .formationLine(velocity, _):
            return travelRotation(for: velocity)
        case let .arrowRush(velocity):
            return travelRotation(for: velocity)
        case let .paddleTrapDot(_, velocity, _, _):
            return travelRotation(for: velocity)
        case let .paddleTrapBar(_, orientation, _):
            return orientation == .vertical ? .pi / 2 : 0
        case .chaser, .mineDot, .hunterDot, .splitter, .splitterChild:
            return 0
        }
    }

    static func bodyPath(for kind: EnemyKind, radius: CGFloat) -> CGPath {
        switch kind {
        case .chaser:
            return circlePath(radius: radius)
        case .formation:
            return formationPath(radius: radius)
        case .arrowRush:
            return arrowRushPath(radius: radius)
        case .mine:
            return minePath(radius: radius)
        case .hunter:
            return trianglePath(radius: radius)
        case .paddleBar:
            return paddleBarPath(radius: radius)
        case .paddlePuck:
            return paddlePuckPath(radius: radius)
        case .splitter:
            return diamondPath(radius: radius)
        case .splitterChild:
            return splitterChildPath(radius: radius)
        }
    }

    static func markerPath(
        for kind: EnemyKind,
        radius: CGFloat,
        isShatterableFrozen: Bool
    ) -> CGPath? {
        if isShatterableFrozen {
            return snowflakePath(radius: radius)
        }

        switch kind {
        case .chaser:
            return nil
        case .formation:
            return formationMarkerPath(radius: radius)
        case .arrowRush:
            return arrowRushMarkerPath(radius: radius)
        case .mine:
            return mineMarkerPath(radius: radius)
        case .hunter:
            return hunterMarkerPath(radius: radius)
        case .paddleBar:
            return paddleBarMarkerPath(radius: radius)
        case .paddlePuck:
            return paddlePuckMarkerPath(radius: radius)
        case .splitter:
            return splitterMarkerPath(radius: radius)
        case .splitterChild:
            return splitterChildMarkerPath(radius: radius)
        }
    }

    static func circlePath(radius: CGFloat) -> CGPath {
        CGPath(
            ellipseIn: CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2),
            transform: nil
        )
    }

    private static func travelRotation(for velocity: CGVector) -> CGFloat {
        guard hypot(velocity.dx, velocity.dy) > 0.001 else {
            return 0
        }

        return atan2(velocity.dy, velocity.dx)
    }

    private static func trianglePath(radius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: radius * 1.05))
        path.addLine(to: CGPoint(x: -radius * 0.9, y: -radius * 0.72))
        path.addLine(to: CGPoint(x: radius * 0.9, y: -radius * 0.72))
        path.closeSubpath()
        return path
    }

    private static func formationPath(radius: CGFloat) -> CGPath {
        CGPath(
            roundedRect: CGRect(
                x: -radius,
                y: -radius * 0.58,
                width: radius * 2,
                height: radius * 1.16
            ),
            cornerWidth: radius * 0.3,
            cornerHeight: radius * 0.3,
            transform: nil
        )
    }

    private static func arrowRushPath(radius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: radius * 1.18, y: 0))
        path.addLine(to: CGPoint(x: -radius * 0.72, y: radius * 0.88))
        path.addLine(to: CGPoint(x: -radius * 0.32, y: 0))
        path.addLine(to: CGPoint(x: -radius * 0.72, y: -radius * 0.88))
        path.closeSubpath()
        return path
    }

    private static func paddleBarPath(radius: CGFloat) -> CGPath {
        CGPath(
            roundedRect: CGRect(
                x: -radius * 1.08,
                y: -radius * 0.62,
                width: radius * 2.16,
                height: radius * 1.24
            ),
            cornerWidth: radius * 0.14,
            cornerHeight: radius * 0.14,
            transform: nil
        )
    }

    private static func paddlePuckPath(radius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: radius * 1.08, y: 0))
        path.addLine(to: CGPoint(x: radius * 0.42, y: radius * 0.82))
        path.addLine(to: CGPoint(x: -radius * 0.7, y: radius * 0.64))
        path.addLine(to: CGPoint(x: -radius, y: 0))
        path.addLine(to: CGPoint(x: -radius * 0.7, y: -radius * 0.64))
        path.addLine(to: CGPoint(x: radius * 0.42, y: -radius * 0.82))
        path.closeSubpath()
        return path
    }

    private static func diamondPath(radius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: radius * 1.05))
        path.addLine(to: CGPoint(x: radius * 1.05, y: 0))
        path.addLine(to: CGPoint(x: 0, y: -radius * 1.05))
        path.addLine(to: CGPoint(x: -radius * 1.05, y: 0))
        path.closeSubpath()
        return path
    }

    private static func splitterChildPath(radius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: radius * 0.92, y: radius * 0.58))
        path.addLine(to: CGPoint(x: radius * 0.52, y: -radius * 0.92))
        path.addLine(to: CGPoint(x: -radius * 0.92, y: -radius * 0.48))
        path.addLine(to: CGPoint(x: -radius * 0.5, y: radius * 0.9))
        path.closeSubpath()
        return path
    }

    private static func minePath(radius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        for index in 0..<8 {
            let angle = CGFloat(index) * .pi / 4 + .pi / 8
            let pointRadius = index.isMultiple(of: 2) ? radius * 1.08 : radius * 0.72
            let point = CGPoint(x: cos(angle) * pointRadius, y: sin(angle) * pointRadius)
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }

    private static func hunterMarkerPath(radius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -radius * 0.36, y: -radius * 0.14))
        path.addLine(to: CGPoint(x: 0, y: radius * 0.42))
        path.addLine(to: CGPoint(x: radius * 0.36, y: -radius * 0.14))
        path.move(to: CGPoint(x: 0, y: radius * 0.42))
        path.addLine(to: CGPoint(x: 0, y: -radius * 0.48))
        return path
    }

    private static func mineMarkerPath(radius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        let lineRadius = radius * 0.52
        path.move(to: CGPoint(x: -lineRadius, y: 0))
        path.addLine(to: CGPoint(x: lineRadius, y: 0))
        path.move(to: CGPoint(x: 0, y: -lineRadius))
        path.addLine(to: CGPoint(x: 0, y: lineRadius))
        return path
    }

    private static func formationMarkerPath(radius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -radius * 0.28, y: -radius * 0.42))
        path.addLine(to: CGPoint(x: -radius * 0.28, y: radius * 0.42))
        path.move(to: CGPoint(x: radius * 0.28, y: -radius * 0.42))
        path.addLine(to: CGPoint(x: radius * 0.28, y: radius * 0.42))
        return path
    }

    private static func arrowRushMarkerPath(radius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -radius * 0.34, y: 0))
        path.addLine(to: CGPoint(x: radius * 0.48, y: 0))
        path.move(to: CGPoint(x: radius * 0.16, y: radius * 0.24))
        path.addLine(to: CGPoint(x: radius * 0.48, y: 0))
        path.addLine(to: CGPoint(x: radius * 0.16, y: -radius * 0.24))
        return path
    }

    private static func paddleBarMarkerPath(radius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: -radius * 0.42))
        path.addLine(to: CGPoint(x: 0, y: radius * 0.42))
        return path
    }

    private static func paddlePuckMarkerPath(radius: CGFloat) -> CGPath {
        circlePath(radius: radius * 0.34)
    }

    private static func splitterChildMarkerPath(radius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -radius * 0.38, y: radius * 0.34))
        path.addLine(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: radius * 0.38, y: -radius * 0.34))
        return path
    }

    private static func splitterMarkerPath(radius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        let halfWidth = radius * 0.42
        path.move(to: CGPoint(x: -halfWidth, y: radius * 0.24))
        path.addLine(to: CGPoint(x: halfWidth, y: radius * 0.24))
        path.move(to: CGPoint(x: -halfWidth, y: -radius * 0.24))
        path.addLine(to: CGPoint(x: halfWidth, y: -radius * 0.24))
        return path
    }

    private static func snowflakePath(radius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        let lineRadius = radius * 0.66
        for rawAngle in stride(from: 0.0, to: Double.pi, by: Double.pi / 3) {
            let angle = CGFloat(rawAngle)
            let dx = cos(angle) * lineRadius
            let dy = sin(angle) * lineRadius
            path.move(to: CGPoint(x: -dx, y: -dy))
            path.addLine(to: CGPoint(x: dx, y: dy))
        }
        return path
    }
}
