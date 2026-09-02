import CoreGraphics

struct ArenaWeaponActivationPlan: Equatable {
    let configuration: StartingWeaponConfiguration
    let application: WeaponApplication
}

final class ArenaWeaponRuntime {
    private(set) var resolver = StartingWeaponResolver()
    private(set) var effectTiming = WeaponEffectTiming()
    private var randomNumberGenerator = RunRandomNumberGenerator(seed: 0)

    var initialSeed: Int {
        randomNumberGenerator.initialSeed
    }

    func configure(
        weaponConfiguration: StartingWeaponConfiguration,
        effectTiming: WeaponEffectTiming
    ) {
        resolver.configuration = weaponConfiguration
        self.effectTiming = effectTiming.sanitizedForRuntime()
    }

    func prepareRun(sequenceSeed: Int) {
        randomNumberGenerator = RunRandomNumberGenerator(seed: sequenceSeed)
    }

    func activationPlan(
        for pickup: WeaponPickup,
        playerPosition: CGPoint,
        enemies: [ArenaEnemy]
    ) -> ArenaWeaponActivationPlan {
        let configuration = resolver.configuration.applying(chargeTier: pickup.chargeTier)
        let chargedResolver = StartingWeaponResolver(configuration: configuration)
        let application = WeaponApplicationCoordinator(resolver: chargedResolver).application(
            kind: pickup.kind,
            playerPosition: playerPosition,
            enemies: enemies,
            using: &randomNumberGenerator
        )
        return ArenaWeaponActivationPlan(
            configuration: configuration,
            application: application
        )
    }
}
