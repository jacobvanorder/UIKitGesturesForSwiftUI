import Testing
import UIKit
@testable import UIKitGesturesForSwiftUI

// MARK: - GestureCoordinator Tests

/// Tests for `GestureCoordinator.gestureRecognizerShouldBegin(_:)`
@Suite("GestureCoordinator - shouldBegin", .serialized)
struct GestureCoordinatorShouldBeginTests {
    
    @Test("Calls shouldBegin closure when provided")
    func callsShouldBeginClosure() {
        nonisolated(unsafe) var wasCalled = false
        let coordinator = GestureCoordinator(
            shouldBegin: { _ in
                wasCalled = true
                return false
            }
        )
        
        let recognizer = UIPanGestureRecognizer()
        let result = coordinator.gestureRecognizerShouldBegin(recognizer)
        
        #expect(wasCalled)
        #expect(result == false)
    }
    
    @Test("Defaults to true when shouldBegin is nil")
    func defaultsToTrueWhenNil() {
        let coordinator = GestureCoordinator(shouldBegin: nil)
        let recognizer = UIPanGestureRecognizer()
        
        let result = coordinator.gestureRecognizerShouldBegin(recognizer)
        
        #expect(result == true)
    }
    
    @Test("Passes correct recognizer to closure")
    func passesCorrectRecognizer() {
        let expectedRecognizer = UIPanGestureRecognizer()
        nonisolated(unsafe) var receivedRecognizer: UIGestureRecognizer?
        
        let coordinator = GestureCoordinator(
            shouldBegin: { recognizer in
                receivedRecognizer = recognizer
                return true
            }
        )
        
        _ = coordinator.gestureRecognizerShouldBegin(expectedRecognizer)
        
        #expect(receivedRecognizer === expectedRecognizer)
    }
}

/// Tests for `GestureCoordinator.shouldRecognizeSimultaneouslyWith`
@Suite("GestureCoordinator - shouldRecognizeSimultaneouslyWith", .serialized)
struct GestureCoordinatorSimultaneousRecognitionTests {
    
    @Test("Calls shouldRecognizeSimultaneouslyWith closure when provided")
    func callsSimultaneousClosure() {
        nonisolated(unsafe) var wasCalled = false
        let coordinator = GestureCoordinator(
            shouldRecognizeSimultaneouslyWith: { _ in
                wasCalled = true
                return false
            }
        )
        
        let recognizer = UIPanGestureRecognizer()
        let otherRecognizer = UIPinchGestureRecognizer()
        let result = coordinator.gestureRecognizer(recognizer, shouldRecognizeSimultaneouslyWith: otherRecognizer)
        
        #expect(wasCalled)
        #expect(result == false)
    }
    
    @Test("Defaults to true when closure is nil - CUSTOM DEFAULT")
    func defaultsToTrueNotUIKitDefault() {
        let coordinator = GestureCoordinator(shouldRecognizeSimultaneouslyWith: nil)
        
        let recognizer = UIPanGestureRecognizer()
        let otherRecognizer = UIPinchGestureRecognizer()
        let result = coordinator.gestureRecognizer(recognizer, shouldRecognizeSimultaneouslyWith: otherRecognizer)
        
        // This is YOUR library's default, not UIKit's default (which is false)
        #expect(result == true)
    }
    
    @Test("Passes other recognizer to closure, not self")
    func passesOtherRecognizer() {
        let selfRecognizer = UIPanGestureRecognizer()
        let otherRecognizer = UIPinchGestureRecognizer()
        nonisolated(unsafe) var receivedRecognizer: UIGestureRecognizer?
        
        let coordinator = GestureCoordinator(
            shouldRecognizeSimultaneouslyWith: { recognizer in
                receivedRecognizer = recognizer
                return true
            }
        )
        
        _ = coordinator.gestureRecognizer(selfRecognizer, shouldRecognizeSimultaneouslyWith: otherRecognizer)
        
        #expect(receivedRecognizer === otherRecognizer)
        #expect(receivedRecognizer !== selfRecognizer)
    }
}

/// Tests for `GestureCoordinator.shouldReceive(_:UITouch)`
@Suite("GestureCoordinator - shouldReceiveTouch", .serialized)
struct GestureCoordinatorShouldReceiveTouchTests {
    
    @Test("Calls shouldReceiveTouch closure when provided")
    func callsShouldReceiveTouchClosure() {
        nonisolated(unsafe) var wasCalled = false
        let coordinator = GestureCoordinator(
            shouldReceiveTouch: { _, _ in
                wasCalled = true
                return false
            }
        )
        
        let recognizer = UIPanGestureRecognizer()
        let touch = UITouch()
        let result = coordinator.gestureRecognizer(recognizer, shouldReceive: touch)
        
        #expect(wasCalled)
        #expect(result == false)
    }
    
    @Test("Defaults to true when shouldReceiveTouch is nil")
    func defaultsToTrueWhenNil() {
        let coordinator = GestureCoordinator(shouldReceiveTouch: nil)
        
        let recognizer = UIPanGestureRecognizer()
        let touch = UITouch()
        let result = coordinator.gestureRecognizer(recognizer, shouldReceive: touch)
        
        #expect(result == true)
    }
    
    @Test("Passes both recognizer and touch to closure")
    func passesBothParameters() {
        let expectedRecognizer = UIPanGestureRecognizer()
        let expectedTouch = UITouch()
        nonisolated(unsafe) var receivedRecognizer: UIGestureRecognizer?
        nonisolated(unsafe) var receivedTouch: UITouch?
        
        let coordinator = GestureCoordinator(
            shouldReceiveTouch: { recognizer, touch in
                receivedRecognizer = recognizer
                receivedTouch = touch
                return true
            }
        )
        
        _ = coordinator.gestureRecognizer(expectedRecognizer, shouldReceive: expectedTouch)
        
        #expect(receivedRecognizer === expectedRecognizer)
        #expect(receivedTouch === expectedTouch)
    }
}

/// Tests for `GestureCoordinator.shouldReceive(_:UIPress)`
@Suite("GestureCoordinator - shouldReceivePress", .serialized)
struct GestureCoordinatorShouldReceivePressTests {
    
    @Test("Calls shouldReceivePress closure when provided")
    func callsShouldReceivePressClosure() {
        nonisolated(unsafe) var wasCalled = false
        let coordinator = GestureCoordinator(
            shouldReceivePress: { _, _ in
                wasCalled = true
                return false
            }
        )
        
        let recognizer = UIPanGestureRecognizer()
        let press = UIPress()
        let result = coordinator.gestureRecognizer(recognizer, shouldReceive: press)
        
        #expect(wasCalled)
        #expect(result == false)
    }
    
    @Test("Defaults to true when shouldReceivePress is nil")
    func defaultsToTrueWhenNil() {
        let coordinator = GestureCoordinator(shouldReceivePress: nil)
        
        let recognizer = UIPanGestureRecognizer()
        let press = UIPress()
        let result = coordinator.gestureRecognizer(recognizer, shouldReceive: press)
        
        #expect(result == true)
    }
    
    @Test("Passes both recognizer and press to closure")
    func passesBothParameters() {
        let expectedRecognizer = UIPanGestureRecognizer()
        let expectedPress = UIPress()
        nonisolated(unsafe) var receivedRecognizer: UIGestureRecognizer?
        nonisolated(unsafe) var receivedPress: UIPress?
        
        let coordinator = GestureCoordinator(
            shouldReceivePress: { recognizer, press in
                receivedRecognizer = recognizer
                receivedPress = press
                return true
            }
        )
        
        _ = coordinator.gestureRecognizer(expectedRecognizer, shouldReceive: expectedPress)
        
        #expect(receivedRecognizer === expectedRecognizer)
        #expect(receivedPress === expectedPress)
    }
}

/// Tests for `GestureCoordinator.shouldReceive(_:UIEvent)`
@Suite("GestureCoordinator - shouldReceiveEvent", .serialized)
struct GestureCoordinatorShouldReceiveEventTests {
    
    @Test("Calls shouldReceiveEvent closure when provided")
    func callsShouldReceiveEventClosure() {
        nonisolated(unsafe) var wasCalled = false
        let coordinator = GestureCoordinator(
            shouldReceiveEvent: { _, _ in
                wasCalled = true
                return false
            }
        )
        
        let recognizer = UIPanGestureRecognizer()
        let event = UIEvent()
        let result = coordinator.gestureRecognizer(recognizer, shouldReceive: event)
        
        #expect(wasCalled)
        #expect(result == false)
    }
    
    @Test("Defaults to true when shouldReceiveEvent is nil")
    func defaultsToTrueWhenNil() {
        let coordinator = GestureCoordinator(shouldReceiveEvent: nil)
        
        let recognizer = UIPanGestureRecognizer()
        let event = UIEvent()
        let result = coordinator.gestureRecognizer(recognizer, shouldReceive: event)
        
        #expect(result == true)
    }
    
    @Test("Passes both recognizer and event to closure")
    func passesBothParameters() {
        let expectedRecognizer = UIPanGestureRecognizer()
        let expectedEvent = UIEvent()
        nonisolated(unsafe) var receivedRecognizer: UIGestureRecognizer?
        nonisolated(unsafe) var receivedEvent: UIEvent?
        
        let coordinator = GestureCoordinator(
            shouldReceiveEvent: { recognizer, event in
                receivedRecognizer = recognizer
                receivedEvent = event
                return true
            }
        )
        
        _ = coordinator.gestureRecognizer(expectedRecognizer, shouldReceive: expectedEvent)
        
        #expect(receivedRecognizer === expectedRecognizer)
        #expect(receivedEvent === expectedEvent)
    }
}

/// Tests for `GestureCoordinator.shouldRequireFailureOf`
@Suite("GestureCoordinator - shouldRequireFailureOf", .serialized)
struct GestureCoordinatorShouldRequireFailureTests {
    
    @Test("Calls shouldRequireFailureOf closure when provided")
    func callsShouldRequireFailureClosure() {
        nonisolated(unsafe) var wasCalled = false
        let coordinator = GestureCoordinator(
            shouldRequireFailureOf: { _ in
                wasCalled = true
                return true
            }
        )
        
        let recognizer = UIPanGestureRecognizer()
        let otherRecognizer = UIPinchGestureRecognizer()
        let result = coordinator.gestureRecognizer(recognizer, shouldRequireFailureOf: otherRecognizer)
        
        #expect(wasCalled)
        #expect(result == true)
    }
    
    @Test("Defaults to false when shouldRequireFailureOf is nil")
    func defaultsToFalseWhenNil() {
        let coordinator = GestureCoordinator(shouldRequireFailureOf: nil)
        
        let recognizer = UIPanGestureRecognizer()
        let otherRecognizer = UIPinchGestureRecognizer()
        let result = coordinator.gestureRecognizer(recognizer, shouldRequireFailureOf: otherRecognizer)
        
        #expect(result == false)
    }
    
    @Test("Passes other recognizer to closure")
    func passesOtherRecognizer() {
        let selfRecognizer = UIPanGestureRecognizer()
        let otherRecognizer = UIPinchGestureRecognizer()
        nonisolated(unsafe) var receivedRecognizer: UIGestureRecognizer?
        
        let coordinator = GestureCoordinator(
            shouldRequireFailureOf: { recognizer in
                receivedRecognizer = recognizer
                return false
            }
        )
        
        _ = coordinator.gestureRecognizer(selfRecognizer, shouldRequireFailureOf: otherRecognizer)
        
        #expect(receivedRecognizer === otherRecognizer)
        #expect(receivedRecognizer !== selfRecognizer)
    }
}

/// Tests for `GestureCoordinator.shouldBeRequiredToFailBy`
@Suite("GestureCoordinator - shouldBeRequiredToFailBy", .serialized)
struct GestureCoordinatorShouldBeRequiredToFailByTests {
    
    @Test("Calls shouldBeRequiredToFailBy closure when provided")
    func callsShouldBeRequiredToFailByClosure() {
        nonisolated(unsafe) var wasCalled = false
        let coordinator = GestureCoordinator(
            shouldBeRequiredToFailBy: { _ in
                wasCalled = true
                return true
            }
        )
        
        let recognizer = UIPanGestureRecognizer()
        let otherRecognizer = UIPinchGestureRecognizer()
        let result = coordinator.gestureRecognizer(recognizer, shouldBeRequiredToFailBy: otherRecognizer)
        
        #expect(wasCalled)
        #expect(result == true)
    }
    
    @Test("Defaults to false when shouldBeRequiredToFailBy is nil")
    func defaultsToFalseWhenNil() {
        let coordinator = GestureCoordinator(shouldBeRequiredToFailBy: nil)
        
        let recognizer = UIPanGestureRecognizer()
        let otherRecognizer = UIPinchGestureRecognizer()
        let result = coordinator.gestureRecognizer(recognizer, shouldBeRequiredToFailBy: otherRecognizer)
        
        #expect(result == false)
    }
    
    @Test("Passes other recognizer to closure")
    func passesOtherRecognizer() {
        let selfRecognizer = UIPanGestureRecognizer()
        let otherRecognizer = UIPinchGestureRecognizer()
        nonisolated(unsafe) var receivedRecognizer: UIGestureRecognizer?
        
        let coordinator = GestureCoordinator(
            shouldBeRequiredToFailBy: { recognizer in
                receivedRecognizer = recognizer
                return false
            }
        )
        
        _ = coordinator.gestureRecognizer(selfRecognizer, shouldBeRequiredToFailBy: otherRecognizer)
        
        #expect(receivedRecognizer === otherRecognizer)
        #expect(receivedRecognizer !== selfRecognizer)
    }
}

/// Integration tests verifying multiple closures can be set simultaneously
@Suite("GestureCoordinator - Integration", .serialized)
struct GestureCoordinatorIntegrationTests {
    
    @Test("All closures can be set and called independently")
    func allClosuresWorkTogether() {
        nonisolated(unsafe) var shouldBeginCalled = false
        nonisolated(unsafe) var simultaneousCalled = false
        nonisolated(unsafe) var receiveTouchCalled = false
        nonisolated(unsafe) var receivePressCalled = false
        nonisolated(unsafe) var receiveEventCalled = false
        nonisolated(unsafe) var requireFailureCalled = false
        nonisolated(unsafe) var beRequiredToFailCalled = false
        
        let coordinator = GestureCoordinator(
            shouldBegin: { _ in
                shouldBeginCalled = true
                return true
            },
            shouldRecognizeSimultaneouslyWith: { _ in
                simultaneousCalled = true
                return false
            },
            shouldReceiveTouch: { _, _ in
                receiveTouchCalled = true
                return true
            },
            shouldReceivePress: { _, _ in
                receivePressCalled = true
                return true
            },
            shouldReceiveEvent: { _, _ in
                receiveEventCalled = true
                return true
            },
            shouldRequireFailureOf: { _ in
                requireFailureCalled = true
                return false
            },
            shouldBeRequiredToFailBy: { _ in
                beRequiredToFailCalled = true
                return false
            }
        )
        
        let recognizer = UIPanGestureRecognizer()
        let otherRecognizer = UIPinchGestureRecognizer()
        let touch = UITouch()
        let press = UIPress()
        let event = UIEvent()
        
        _ = coordinator.gestureRecognizerShouldBegin(recognizer)
        _ = coordinator.gestureRecognizer(recognizer, shouldRecognizeSimultaneouslyWith: otherRecognizer)
        _ = coordinator.gestureRecognizer(recognizer, shouldReceive: touch)
        _ = coordinator.gestureRecognizer(recognizer, shouldReceive: press)
        _ = coordinator.gestureRecognizer(recognizer, shouldReceive: event)
        _ = coordinator.gestureRecognizer(recognizer, shouldRequireFailureOf: otherRecognizer)
        _ = coordinator.gestureRecognizer(recognizer, shouldBeRequiredToFailBy: otherRecognizer)
        
        #expect(shouldBeginCalled)
        #expect(simultaneousCalled)
        #expect(receiveTouchCalled)
        #expect(receivePressCalled)
        #expect(receiveEventCalled)
        #expect(requireFailureCalled)
        #expect(beRequiredToFailCalled)
    }
    
    @Test("All defaults work when no closures provided")
    func allDefaultsWorkCorrectly() {
        let coordinator = GestureCoordinator()
        
        let recognizer = UIPanGestureRecognizer()
        let otherRecognizer = UIPinchGestureRecognizer()
        let touch = UITouch()
        let press = UIPress()
        let event = UIEvent()
        
        #expect(coordinator.gestureRecognizerShouldBegin(recognizer) == true)
        #expect(coordinator.gestureRecognizer(recognizer, shouldRecognizeSimultaneouslyWith: otherRecognizer) == true)
        #expect(coordinator.gestureRecognizer(recognizer, shouldReceive: touch) == true)
        #expect(coordinator.gestureRecognizer(recognizer, shouldReceive: press) == true)
        #expect(coordinator.gestureRecognizer(recognizer, shouldReceive: event) == true)
        #expect(coordinator.gestureRecognizer(recognizer, shouldRequireFailureOf: otherRecognizer) == false)
        #expect(coordinator.gestureRecognizer(recognizer, shouldBeRequiredToFailBy: otherRecognizer) == false)
    }
}
