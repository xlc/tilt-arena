import CoreGraphics
import GameController

struct KeyboardMovementInput: Equatable {
    var left = false
    var right = false
    var upward = false
    var downward = false

    var isActive: Bool {
        left || right || upward || downward
    }

    var vector: CGVector {
        let horizontal = (right ? 1 : 0) - (left ? 1 : 0)
        let vertical = (upward ? 1 : 0) - (downward ? 1 : 0)

        return CGVector(
            dx: CGFloat(horizontal),
            dy: CGFloat(vertical)
        ).clamped(toMaximumLength: 1)
    }
}

@MainActor
final class KeyboardInputController {
    func movementInput() -> KeyboardMovementInput {
        guard let keyboardInput = GCKeyboard.coalesced?.keyboardInput else {
            return KeyboardMovementInput()
        }

        return KeyboardMovementInput(
            left: isPressed([.leftArrow, .keyA], in: keyboardInput),
            right: isPressed([.rightArrow, .keyD], in: keyboardInput),
            upward: isPressed([.upArrow, .keyW], in: keyboardInput),
            downward: isPressed([.downArrow, .keyS], in: keyboardInput)
        )
    }

    private func isPressed(_ keyCodes: [GCKeyCode], in keyboardInput: GCKeyboardInput) -> Bool {
        keyCodes.contains { keyCode in
            keyboardInput.button(forKeyCode: keyCode)?.isPressed == true
        }
    }
}
