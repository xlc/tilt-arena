import CoreGraphics
import Foundation

struct PickupSpawnConfiguration: Equatable {
    static let defaultWeaponKindCycle: [WeaponKind] = [
        .shockwave,
        .seekerSwarm,
        .razorShield,
        .freezeBurst,
        .gravityWell,
        .shockwave,
        .seekerSwarm,
        .razorShield,
        .chainLightning,
        .freezeBurst,
        .shockwave,
        .seekerSwarm,
        .razorShield,
        .flameTrail,
        .warpDash,
        .gravityWell,
        .shockwave,
        .seekerSwarm,
        .razorShield,
        .freezeBurst,
        .chainLightning,
        .flameTrail,
        .warpDash,
        .powerWave,
        .ricochetLance,
        .novaBomb
    ]

    var refillDelay: TimeInterval = 0.5
    var maxActivePickups: Int = 3
    var pickupRadius: CGFloat = 8.5
    var edgeInset: CGFloat = 44
    var playerClearance: CGFloat = 84
    var enemyClearance: CGFloat = 8
    var weaponKindCycle: [WeaponKind] = PickupSpawnConfiguration.defaultWeaponKindCycle
}

struct PickupSpawnPlanner {
    private static let spawnTimerEpsilon: TimeInterval = 0.000_001
    private static let candidatePositions: [(x: CGFloat, y: CGFloat)] = [
        (0.50, 0.28),
        (0.24, 0.52),
        (0.76, 0.52),
        (0.42, 0.72),
        (0.58, 0.38),
        (0.32, 0.34),
        (0.68, 0.68),
        (0.50, 0.58)
    ]
    private static let fallbackGridColumns = 11
    private static let fallbackGridRows = 9
    private static let fallbackCandidateStep = 37
    private static var fallbackCandidateCount: Int {
        fallbackGridColumns * fallbackGridRows
    }

    private(set) var nextPickupID = 1
    private var nextKindIndex = 0
    private var nextCandidateIndex = 0
    private var nextFallbackCandidateIndex = 0
    private var timeUntilNextSpawn: TimeInterval = 0

    init(
        configuration: PickupSpawnConfiguration = PickupSpawnConfiguration(),
        sequenceSeed: Int? = nil
    ) {
        applySequenceSeed(sequenceSeed, configuration: configuration)
    }

    mutating func reset(
        configuration: PickupSpawnConfiguration = PickupSpawnConfiguration(),
        sequenceSeed: Int? = nil
    ) {
        nextPickupID = 1
        nextKindIndex = 0
        nextCandidateIndex = 0
        nextFallbackCandidateIndex = 0
        timeUntilNextSpawn = 0
        applySequenceSeed(sequenceSeed, configuration: configuration)
    }

    mutating func update(
        deltaTime: TimeInterval,
        phase: ClassicRunPhase,
        activePickupCount: Int,
        playableRect: CGRect,
        playerPosition: CGPoint,
        enemyCircles: [CollisionCircle],
        configuration: PickupSpawnConfiguration = PickupSpawnConfiguration()
    ) -> [WeaponPickup] {
        guard phase == .active else {
            return []
        }

        guard configuration.maxActivePickups > 0 else {
            return []
        }

        let missingPickupCount = configuration.maxActivePickups - activePickupCount
        guard missingPickupCount > 0 else {
            timeUntilNextSpawn = max(0, configuration.refillDelay)
            return []
        }

        timeUntilNextSpawn -= max(0, deltaTime)
        if abs(timeUntilNextSpawn) <= Self.spawnTimerEpsilon {
            timeUntilNextSpawn = 0
        }

        guard timeUntilNextSpawn <= 0 else {
            return []
        }

        var pickups: [WeaponPickup] = []
        for _ in 0..<missingPickupCount {
            guard let pickup = spawnPickup(
                in: playableRect,
                avoiding: playerPosition,
                enemyCircles: enemyCircles,
                configuration: configuration
            ) else {
                break
            }

            pickups.append(pickup)
        }

        timeUntilNextSpawn = max(0, configuration.refillDelay)
        return pickups
    }

    mutating func spawnPickup(
        in playableRect: CGRect,
        avoiding playerPosition: CGPoint,
        enemyCircles: [CollisionCircle],
        configuration: PickupSpawnConfiguration = PickupSpawnConfiguration()
    ) -> WeaponPickup? {
        let spawnRect = playableRect.insetBy(
            dx: min(configuration.edgeInset, playableRect.width / 4),
            dy: min(configuration.edgeInset, playableRect.height / 4)
        )

        guard spawnRect.width > 0, spawnRect.height > 0 else {
            return nil
        }

        guard !configuration.weaponKindCycle.isEmpty else {
            return nil
        }

        guard let position = nextSafePickupPosition(
            in: spawnRect,
            avoiding: playerPosition,
            enemyCircles: enemyCircles,
            configuration: configuration
        ) else {
            return nil
        }

        let pickup = WeaponPickup(
            id: nextPickupID,
            kind: nextKind(configuration: configuration),
            position: position,
            radius: configuration.pickupRadius
        )
        nextPickupID += 1
        return pickup
    }

    private mutating func nextSafePickupPosition(
        in spawnRect: CGRect,
        avoiding playerPosition: CGPoint,
        enemyCircles: [CollisionCircle],
        configuration: PickupSpawnConfiguration
    ) -> CGPoint? {
        for _ in 0..<Self.candidatePositions.count {
            let position = candidatePosition(in: spawnRect, index: nextCandidateIndex)
            nextCandidateIndex += 1

            guard isSafePickupPosition(
                position,
                avoiding: playerPosition,
                enemyCircles: enemyCircles,
                configuration: configuration
            ) else {
                continue
            }

            return position
        }

        for _ in 0..<Self.fallbackCandidateCount {
            let position = fallbackCandidatePosition(in: spawnRect, index: nextFallbackCandidateIndex)
            nextFallbackCandidateIndex += 1

            guard isSafePickupPosition(
                position,
                avoiding: playerPosition,
                enemyCircles: enemyCircles,
                configuration: configuration
            ) else {
                continue
            }

            return position
        }

        return nil
    }

    func isSafePickupPosition(
        _ position: CGPoint,
        avoiding playerPosition: CGPoint,
        enemyCircles: [CollisionCircle],
        configuration: PickupSpawnConfiguration = PickupSpawnConfiguration()
    ) -> Bool {
        let playerClearance = configuration.playerClearance + configuration.pickupRadius
        guard ArenaGeometry.squaredDistance(from: position, to: playerPosition) >= playerClearance * playerClearance else {
            return false
        }

        return enemyCircles.allSatisfy { enemyCircle in
            let clearance = enemyCircle.radius + configuration.pickupRadius + configuration.enemyClearance
            return ArenaGeometry.squaredDistance(from: position, to: enemyCircle.center) >= clearance * clearance
        }
    }

    private mutating func nextKind(configuration: PickupSpawnConfiguration) -> WeaponKind {
        let kind = configuration.weaponKindCycle[nextKindIndex % configuration.weaponKindCycle.count]
        nextKindIndex += 1
        return kind
    }

    private func candidatePosition(in rect: CGRect, index: Int) -> CGPoint {
        let normalized = Self.candidatePositions[index % Self.candidatePositions.count]
        return CGPoint(
            x: rect.minX + rect.width * normalized.x,
            y: rect.minY + rect.height * normalized.y
        )
    }

    private func fallbackCandidatePosition(in rect: CGRect, index: Int) -> CGPoint {
        let candidateIndex = positiveModulo(
            index * Self.fallbackCandidateStep,
            Self.fallbackCandidateCount
        )
        let column = candidateIndex % Self.fallbackGridColumns
        let row = candidateIndex / Self.fallbackGridColumns

        return CGPoint(
            x: rect.minX + rect.width * ((CGFloat(column) + 0.5) / CGFloat(Self.fallbackGridColumns)),
            y: rect.minY + rect.height * ((CGFloat(row) + 0.5) / CGFloat(Self.fallbackGridRows))
        )
    }

    private mutating func applySequenceSeed(_ seed: Int?, configuration: PickupSpawnConfiguration) {
        guard let seed else {
            return
        }

        nextKindIndex = positiveModulo(seed, max(1, configuration.weaponKindCycle.count))
        nextCandidateIndex = positiveModulo(seed / 3, Self.candidatePositions.count)
        nextFallbackCandidateIndex = positiveModulo(seed, Self.fallbackCandidateCount)
    }

    private func positiveModulo(_ value: Int, _ divisor: Int) -> Int {
        let remainder = value % divisor
        return remainder >= 0 ? remainder : remainder + divisor
    }

}
