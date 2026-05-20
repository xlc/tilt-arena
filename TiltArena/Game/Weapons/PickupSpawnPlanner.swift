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
        .gravityWell,
        .shockwave,
        .seekerSwarm,
        .razorShield,
        .freezeBurst,
        .chainLightning,
        .flameTrail,
        .novaBomb
    ]

    var initialSpawnDelay: TimeInterval = 4.5
    var spawnInterval: TimeInterval = 4.5
    var maxActivePickups: Int = 2
    var pickupRadius: CGFloat = 12
    var edgeInset: CGFloat = 44
    var playerClearance: CGFloat = 84
    var enemyClearance: CGFloat = 8
    var weaponKindCycle: [WeaponKind] = PickupSpawnConfiguration.defaultWeaponKindCycle
}

struct PickupSpawnPlanner {
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

    private(set) var nextPickupID = 1
    private var nextKindIndex = 0
    private var nextCandidateIndex = 0
    private var timeUntilNextSpawn: TimeInterval

    init(configuration: PickupSpawnConfiguration = PickupSpawnConfiguration()) {
        timeUntilNextSpawn = configuration.initialSpawnDelay
    }

    mutating func reset(configuration: PickupSpawnConfiguration = PickupSpawnConfiguration()) {
        nextPickupID = 1
        nextKindIndex = 0
        nextCandidateIndex = 0
        timeUntilNextSpawn = configuration.initialSpawnDelay
    }

    mutating func update(
        deltaTime: TimeInterval,
        phase: ClassicRunPhase,
        activePickupCount: Int,
        playableRect: CGRect,
        playerPosition: CGPoint,
        enemyCircles: [CollisionCircle],
        configuration: PickupSpawnConfiguration = PickupSpawnConfiguration()
    ) -> WeaponPickup? {
        guard phase == .active else {
            return nil
        }

        guard configuration.spawnInterval > 0, configuration.maxActivePickups > 0 else {
            return nil
        }

        guard activePickupCount < configuration.maxActivePickups else {
            timeUntilNextSpawn = max(timeUntilNextSpawn, configuration.spawnInterval)
            return nil
        }

        timeUntilNextSpawn -= max(0, deltaTime)

        guard timeUntilNextSpawn <= 0 else {
            return nil
        }

        guard let pickup = spawnPickup(
            in: playableRect,
            avoiding: playerPosition,
            enemyCircles: enemyCircles,
            configuration: configuration
        ) else {
            timeUntilNextSpawn = configuration.spawnInterval
            return nil
        }

        timeUntilNextSpawn = configuration.spawnInterval
        return pickup
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

            let pickup = WeaponPickup(
                id: nextPickupID,
                kind: nextKind(configuration: configuration),
                position: position,
                radius: configuration.pickupRadius
            )
            nextPickupID += 1
            return pickup
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
        guard squaredDistance(from: position, to: playerPosition) >= playerClearance * playerClearance else {
            return false
        }

        return enemyCircles.allSatisfy { enemyCircle in
            let clearance = enemyCircle.radius + configuration.pickupRadius + configuration.enemyClearance
            return squaredDistance(from: position, to: enemyCircle.center) >= clearance * clearance
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

    private func squaredDistance(from lhs: CGPoint, to rhs: CGPoint) -> CGFloat {
        let dx = lhs.x - rhs.x
        let dy = lhs.y - rhs.y
        return dx * dx + dy * dy
    }
}
