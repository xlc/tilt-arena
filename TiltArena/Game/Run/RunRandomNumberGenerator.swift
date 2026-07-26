import Foundation

/// Small deterministic generator shared by gameplay choices that must replay from a run seed.
struct RunRandomNumberGenerator: RandomNumberGenerator {
    let initialSeed: Int
    private var state: UInt64

    init(seed: Int) {
        initialSeed = seed
        state = UInt64(bitPattern: Int64(truncatingIfNeeded: seed))
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        return value ^ (value >> 31)
    }
}
