import SpriteKit

@MainActor
final class WeaponPickupNode: SKNode {
    private let bodyNode: SKShapeNode
    private let ringNode: SKShapeNode
    private let markNode: SKShapeNode
    private var theme: ArenaTheme

    init(pickup: WeaponPickup, theme: ArenaTheme) {
        bodyNode = SKShapeNode()
        ringNode = SKShapeNode()
        markNode = SKShapeNode()
        self.theme = theme
        super.init()

        zPosition = 14

        applyAppearance(for: pickup.kind, radius: pickup.radius)
        addChild(ringNode)
        addChild(bodyNode)
        addChild(markNode)
        apply(pickup)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("WeaponPickupNode does not support storyboard initialization.")
    }

    func apply(_ pickup: WeaponPickup) {
        position = pickup.position
    }

    func applyTheme(_ theme: ArenaTheme, pickup: WeaponPickup) {
        self.theme = theme
        applyAppearance(for: pickup.kind, radius: pickup.radius)
    }

    private func applyAppearance(for kind: WeaponKind, radius: CGFloat) {
        let color = Self.color(for: kind, theme: theme)
        ringNode.strokeColor = color.withAlphaComponent(0.45)
        ringNode.lineWidth = 1
        ringNode.fillColor = .clear
        ringNode.glowWidth = 1
        ringNode.path = Self.circlePath(radius: radius * 1.45)

        bodyNode.path = Self.bodyPath(for: kind, radius: radius)
        bodyNode.fillColor = color.withAlphaComponent(0.9)
        bodyNode.strokeColor = theme.playerColor.withAlphaComponent(0.8)
        bodyNode.lineWidth = 1.1
        bodyNode.glowWidth = 2

        if let markPath = Self.markPath(for: kind, radius: radius) {
            markNode.path = markPath
            markNode.isHidden = false
        } else {
            markNode.path = nil
            markNode.isHidden = true
        }
        markNode.fillColor = .clear
        markNode.strokeColor = theme.playerColor.withAlphaComponent(0.95)
        markNode.lineWidth = 1.5
        markNode.lineCap = .round
        markNode.lineJoin = .round
        markNode.glowWidth = 1
    }

    private static func color(for kind: WeaponKind, theme: ArenaTheme) -> SKColor {
        switch kind {
        case .shockwave:
            return theme.pickupAmber
        case .seekerSwarm:
            return theme.pickupViolet
        case .razorShield:
            return theme.pickupBlue
        case .freezeBurst:
            return theme.pickupBlue
        case .gravityWell:
            return theme.pickupViolet
        case .chainLightning:
            return theme.pickupBlue
        case .flameTrail:
            return theme.pickupAmber
        case .warpDash:
            return theme.pickupViolet
        case .decoyBeacon:
            return theme.pickupViolet
        case .novaBomb:
            return theme.pickupAmber
        }
    }

    private static func bodyPath(for kind: WeaponKind, radius: CGFloat) -> CGPath {
        switch kind {
        case .shockwave:
            return diamondPath(radius: radius)
        case .seekerSwarm:
            return circlePath(radius: radius * 0.92)
        case .razorShield:
            return shieldPath(radius: radius)
        case .freezeBurst:
            return hexagonPath(radius: radius)
        case .gravityWell:
            return circlePath(radius: radius * 0.96)
        case .chainLightning:
            return boltPath(radius: radius)
        case .flameTrail:
            return flamePath(radius: radius)
        case .warpDash:
            return trianglePath(radius: radius)
        case .decoyBeacon:
            return squarePath(radius: radius)
        case .novaBomb:
            return starPath(radius: radius)
        }
    }

    private static func markPath(for kind: WeaponKind, radius: CGFloat) -> CGPath? {
        switch kind {
        case .shockwave:
            return ringMarkPath(radius: radius)
        case .seekerSwarm:
            return swarmMarkPath(radius: radius)
        case .razorShield:
            return shieldMarkPath(radius: radius)
        case .freezeBurst:
            return snowflakeMarkPath(radius: radius)
        case .gravityWell:
            return orbitMarkPath(radius: radius)
        case .chainLightning:
            return nil
        case .flameTrail:
            return flameMarkPath(radius: radius)
        case .warpDash:
            return dashMarkPath(radius: radius)
        case .decoyBeacon:
            return beaconMarkPath(radius: radius)
        case .novaBomb:
            return burstMarkPath(radius: radius)
        }
    }

    private static func circlePath(radius: CGFloat) -> CGPath {
        CGPath(
            ellipseIn: CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2),
            transform: nil
        )
    }

    private static func diamondPath(radius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: radius))
        path.addLine(to: CGPoint(x: radius * 0.78, y: 0))
        path.addLine(to: CGPoint(x: 0, y: -radius))
        path.addLine(to: CGPoint(x: -radius * 0.78, y: 0))
        path.closeSubpath()
        return path
    }

    private static func trianglePath(radius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: radius * 1.05))
        path.addLine(to: CGPoint(x: -radius * 0.88, y: -radius * 0.72))
        path.addLine(to: CGPoint(x: radius * 0.88, y: -radius * 0.72))
        path.closeSubpath()
        return path
    }

    private static func shieldPath(radius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: radius * 1.05))
        path.addLine(to: CGPoint(x: radius * 0.78, y: radius * 0.48))
        path.addLine(to: CGPoint(x: radius * 0.58, y: -radius * 0.52))
        path.addLine(to: CGPoint(x: 0, y: -radius * 1.02))
        path.addLine(to: CGPoint(x: -radius * 0.58, y: -radius * 0.52))
        path.addLine(to: CGPoint(x: -radius * 0.78, y: radius * 0.48))
        path.closeSubpath()
        return path
    }

    private static func hexagonPath(radius: CGFloat) -> CGPath {
        polygonPath(points: 6, radius: radius, rotation: .pi / 6)
    }

    private static func squarePath(radius: CGFloat) -> CGPath {
        let side = radius * 1.45
        return CGPath(
            rect: CGRect(x: -side / 2, y: -side / 2, width: side, height: side),
            transform: nil
        )
    }

    private static func boltPath(radius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -radius * 0.08, y: radius))
        path.addLine(to: CGPoint(x: -radius * 0.68, y: radius * -0.08))
        path.addLine(to: CGPoint(x: -radius * 0.12, y: radius * -0.08))
        path.addLine(to: CGPoint(x: radius * 0.06, y: -radius))
        path.addLine(to: CGPoint(x: radius * 0.72, y: radius * 0.18))
        path.addLine(to: CGPoint(x: radius * 0.12, y: radius * 0.18))
        path.closeSubpath()
        return path
    }

    private static func flamePath(radius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: radius * 1.08))
        path.addCurve(
            to: CGPoint(x: radius * 0.62, y: -radius * 0.5),
            control1: CGPoint(x: radius * 0.68, y: radius * 0.38),
            control2: CGPoint(x: radius * 0.86, y: -radius * 0.1)
        )
        path.addCurve(
            to: CGPoint(x: 0, y: -radius),
            control1: CGPoint(x: radius * 0.42, y: -radius * 0.9),
            control2: CGPoint(x: radius * 0.15, y: -radius)
        )
        path.addCurve(
            to: CGPoint(x: -radius * 0.62, y: -radius * 0.5),
            control1: CGPoint(x: -radius * 0.15, y: -radius),
            control2: CGPoint(x: -radius * 0.42, y: -radius * 0.9)
        )
        path.addCurve(
            to: CGPoint(x: 0, y: radius * 1.08),
            control1: CGPoint(x: -radius * 0.82, y: -radius * 0.04),
            control2: CGPoint(x: -radius * 0.42, y: radius * 0.4)
        )
        path.closeSubpath()
        return path
    }

    private static func starPath(radius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        for index in 0..<10 {
            let angle = CGFloat(index) * .pi / 5 + .pi / 2
            let pointRadius = index.isMultiple(of: 2) ? radius : radius * 0.48
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

    private static func polygonPath(points: Int, radius: CGFloat, rotation: CGFloat = 0) -> CGPath {
        let path = CGMutablePath()
        for index in 0..<points {
            let angle = CGFloat(index) * 2 * .pi / CGFloat(points) + rotation
            let point = CGPoint(x: cos(angle) * radius, y: sin(angle) * radius)
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }

    private static func ringMarkPath(radius: CGFloat) -> CGPath {
        circlePath(radius: radius * 0.38)
    }

    private static func swarmMarkPath(radius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        let dotRadius = radius * 0.15
        for point in [
            CGPoint(x: -radius * 0.3, y: -radius * 0.12),
            CGPoint(x: radius * 0.24, y: -radius * 0.18),
            CGPoint(x: 0, y: radius * 0.3)
        ] {
            path.addEllipse(in: CGRect(
                x: point.x - dotRadius,
                y: point.y - dotRadius,
                width: dotRadius * 2,
                height: dotRadius * 2
            ))
        }
        return path
    }

    private static func shieldMarkPath(radius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: radius * 0.58))
        path.addLine(to: CGPoint(x: 0, y: -radius * 0.58))
        return path
    }

    private static func snowflakeMarkPath(radius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        let lineRadius = radius * 0.56
        for rawAngle in stride(from: 0.0, to: Double.pi, by: Double.pi / 3) {
            let angle = CGFloat(rawAngle)
            let dx = cos(angle) * lineRadius
            let dy = sin(angle) * lineRadius
            path.move(to: CGPoint(x: -dx, y: -dy))
            path.addLine(to: CGPoint(x: dx, y: dy))
        }
        return path
    }

    private static func orbitMarkPath(radius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.addArc(
            center: .zero,
            radius: radius * 0.5,
            startAngle: .pi * 0.12,
            endAngle: .pi * 1.45,
            clockwise: false
        )
        path.move(to: CGPoint(x: radius * 0.22, y: radius * 0.42))
        path.addLine(to: CGPoint(x: radius * 0.5, y: radius * 0.4))
        return path
    }

    private static func flameMarkPath(radius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: radius * 0.54))
        path.addCurve(
            to: CGPoint(x: 0, y: -radius * 0.55),
            control1: CGPoint(x: radius * 0.3, y: radius * 0.08),
            control2: CGPoint(x: -radius * 0.24, y: -radius * 0.08)
        )
        return path
    }

    private static func dashMarkPath(radius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        for x in [-radius * 0.32, radius * 0.08] {
            path.move(to: CGPoint(x: x - radius * 0.16, y: -radius * 0.34))
            path.addLine(to: CGPoint(x: x + radius * 0.18, y: 0))
            path.addLine(to: CGPoint(x: x - radius * 0.16, y: radius * 0.34))
        }
        return path
    }

    private static func beaconMarkPath(radius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -radius * 0.5, y: 0))
        path.addLine(to: CGPoint(x: radius * 0.5, y: 0))
        path.move(to: CGPoint(x: 0, y: -radius * 0.5))
        path.addLine(to: CGPoint(x: 0, y: radius * 0.5))
        return path
    }

    private static func burstMarkPath(radius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        let inner = radius * 0.18
        let outer = radius * 0.58
        for rawAngle in stride(from: 0.0, to: Double.pi * 2, by: Double.pi / 4) {
            let angle = CGFloat(rawAngle)
            path.move(to: CGPoint(x: cos(angle) * inner, y: sin(angle) * inner))
            path.addLine(to: CGPoint(x: cos(angle) * outer, y: sin(angle) * outer))
        }
        return path
    }
}
