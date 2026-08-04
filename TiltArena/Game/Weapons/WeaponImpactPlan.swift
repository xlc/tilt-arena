import CoreGraphics

struct WeaponImpactTarget: Equatable {
    let id: Int
    let position: CGPoint
}

struct WeaponImpactPlan {
    static let maximumVisualTargetCount = 16

    let impactEnemyIDs: Set<Int>
    let visualTargets: [WeaponImpactTarget]

    init(targets: [WeaponImpactTarget]) {
        impactEnemyIDs = Set(targets.map(\.id))
        visualTargets = Self.evenlySampled(targets)
    }

    static func evenlySampled<Value>(
        _ values: [Value],
        maximumCount: Int = Self.maximumVisualTargetCount
    ) -> [Value] {
        let limit = max(0, maximumCount)
        guard limit > 0, values.count > limit else {
            return limit > 0 ? values : []
        }
        guard limit > 1 else {
            return [values[0]]
        }

        return (0..<limit).map { index in
            let sourceIndex = index * (values.count - 1) / (limit - 1)
            return values[sourceIndex]
        }
    }
}
