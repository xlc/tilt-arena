import Foundation

struct ArenaRunSessionState: Equatable {
    private(set) var selectedMode: ArenaModeKind = .classic
    private(set) var previousBestScore = 0
    private(set) var progressionResult: ArenaProgressionResult?
    private(set) var hasPersistedFinalRun = false
    private(set) var isResolvingDeath = false
    private(set) var postRunTransitionTimeRemaining: TimeInterval?
    var deathReplayTrace = DeathReplayTrace()
    private(set) var lastDeathCollisionSnapshot: DeathCollisionSnapshot?

    var needsFinalRunPersistence: Bool {
        !hasPersistedFinalRun
    }

    mutating func selectMode(_ mode: ArenaModeKind) {
        selectedMode = mode
    }

    mutating func preparePreRun() {
        hasPersistedFinalRun = false
    }

    mutating func prepareNewRun() {
        hasPersistedFinalRun = false
        isResolvingDeath = false
        postRunTransitionTimeRemaining = nil
        progressionResult = nil
        lastDeathCollisionSnapshot = nil
        deathReplayTrace.reset()
    }

    mutating func resetGameplayTransition() {
        isResolvingDeath = false
        postRunTransitionTimeRemaining = nil
    }

    mutating func beginRunCompletion(
        previousBestScore: Int,
        collision: DeathCollisionSnapshot?,
        transitionDuration: TimeInterval?
    ) {
        self.previousBestScore = previousBestScore
        lastDeathCollisionSnapshot = collision
        let duration = transitionDuration.map { max(0, $0) }
        postRunTransitionTimeRemaining = duration
        isResolvingDeath = duration != nil
    }

    mutating func advancePostRunTransition(by deltaTime: TimeInterval) -> Bool {
        guard let timeRemaining = postRunTransitionTimeRemaining else {
            return false
        }

        let updatedTimeRemaining = max(0, timeRemaining - max(0, deltaTime))
        postRunTransitionTimeRemaining = updatedTimeRemaining
        return updatedTimeRemaining == 0
    }

    mutating func completePostRunTransition() {
        postRunTransitionTimeRemaining = nil
        isResolvingDeath = false
    }

    mutating func recordProgression(_ result: ArenaProgressionResult) {
        progressionResult = result
        hasPersistedFinalRun = true
    }

    mutating func resetProfileSelection() {
        selectedMode = .classic
        progressionResult = nil
    }

    mutating func clearDeathPresentation() {
        lastDeathCollisionSnapshot = nil
        deathReplayTrace.reset()
    }

    #if DEBUG
    mutating func prepareSnapshot(selectedMode: ArenaModeKind, previousBestScore: Int = 0) {
        self.selectedMode = selectedMode
        self.previousBestScore = previousBestScore
        progressionResult = nil
        hasPersistedFinalRun = false
        isResolvingDeath = false
        postRunTransitionTimeRemaining = nil
        lastDeathCollisionSnapshot = nil
        deathReplayTrace.reset()
    }

    mutating func finishSnapshot(
        progressionResult: ArenaProgressionResult,
        collision: DeathCollisionSnapshot
    ) {
        self.progressionResult = progressionResult
        hasPersistedFinalRun = true
        lastDeathCollisionSnapshot = collision
    }
    #endif
}
