import XCTest
@testable import TiltArena

final class RicochetLancePathTests: XCTestCase {
    func testSegmentsBounceOffArenaWallsWithinRange() {
        let segments = RicochetLancePath.segments(
            origin: CGPoint(x: 50, y: 50),
            direction: CGVector(dx: 1, dy: 0),
            playableRect: CGRect(x: 0, y: 0, width: 100, height: 100),
            maximumDistance: 130,
            maximumBounces: 1
        )

        XCTAssertEqual(segments.count, 2)
        XCTAssertEqual(segments[0].start, CGPoint(x: 50, y: 50))
        XCTAssertEqual(segments[0].end, CGPoint(x: 100, y: 50))
        XCTAssertEqual(segments[1].start, CGPoint(x: 100, y: 50))
        XCTAssertEqual(segments[1].end, CGPoint(x: 20, y: 50))
    }

    func testMaximumBounceCountStopsAtFirstWallWhenZero() {
        let segments = RicochetLancePath.segments(
            origin: CGPoint(x: 50, y: 50),
            direction: CGVector(dx: 1, dy: 0),
            playableRect: CGRect(x: 0, y: 0, width: 100, height: 100),
            maximumDistance: 130,
            maximumBounces: 0
        )

        XCTAssertEqual(segments, [
            RicochetLanceSegment(
                start: CGPoint(x: 50, y: 50),
                end: CGPoint(x: 100, y: 50)
            )
        ])
    }

    func testTargetsEnemiesIntersectingBeamWidthAndEnemyRadius() {
        let result = RicochetLancePath.resolve(
            origin: CGPoint(x: 10, y: 10),
            direction: CGVector(dx: 1, dy: 0),
            playableRect: CGRect(x: 0, y: 0, width: 200, height: 120),
            enemies: [
                enemy(id: 1, position: CGPoint(x: 80, y: 17), radius: 4),
                enemy(id: 2, position: CGPoint(x: 90, y: 30), radius: 4),
                enemy(id: 3, position: CGPoint(x: 170, y: 10), radius: 4)
            ],
            configuration: StartingWeaponConfiguration(
                ricochetLanceRange: 120,
                ricochetLanceBeamWidth: 10,
                ricochetLanceMaximumBounces: 0
            )
        )

        XCTAssertEqual(result.destroyedEnemyIDs, [1])
    }

    func testZeroDirectionFallsBackToUpwardBeam() {
        let result = RicochetLancePath.resolve(
            origin: CGPoint(x: 50, y: 50),
            direction: .zero,
            playableRect: CGRect(x: 0, y: 0, width: 100, height: 100),
            enemies: [
                enemy(id: 1, position: CGPoint(x: 50, y: 75), radius: 4),
                enemy(id: 2, position: CGPoint(x: 75, y: 50), radius: 4)
            ],
            configuration: StartingWeaponConfiguration(
                ricochetLanceRange: 30,
                ricochetLanceBeamWidth: 8,
                ricochetLanceMaximumBounces: 1
            )
        )

        XCTAssertEqual(result.segments, [
            RicochetLanceSegment(
                start: CGPoint(x: 50, y: 50),
                end: CGPoint(x: 50, y: 80)
            )
        ])
        XCTAssertEqual(result.destroyedEnemyIDs, [1])
    }

    private func enemy(id: Int, position: CGPoint, radius: CGFloat) -> ArenaEnemy {
        ArenaEnemy(id: id, position: position, radius: radius, speed: 0)
    }
}
