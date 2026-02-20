//
//  GestureCoordinator.swift
//  UIKitGesturesForSwiftUI
//
//  Created by Jacob Van Order on 2/20/26.
//

import Foundation
import UIKit

/// A shared `UIGestureRecognizerDelegate` implementation used by all gesture
/// structs in this library.
///
/// `GestureCoordinator` implements all seven `UIGestureRecognizerDelegate` methods,
/// forwarding each decision to an optional closure. When a closure is `nil`, the
/// coordinator falls back to a sensible default that matches UIKit's behavior —
/// except for `shouldRecognizeSimultaneouslyWith`, which defaults to `true` (rather
/// than UIKit's `false`) so that multi-gesture setups work out of the box.
///
/// ## Delegate methods and defaults
///
/// | Delegate Method | Closure | Default |
/// |----------------|---------|---------|
/// | `gestureRecognizerShouldBegin(_:)` | `shouldBegin` | `true` |
/// | `shouldRecognizeSimultaneouslyWith` | `shouldRecognizeSimultaneouslyWith` | `true` |
/// | `shouldReceive(_:UITouch)` | `shouldReceiveTouch` | `true` |
/// | `shouldReceive(_:UIPress)` | `shouldReceivePress` | `true` |
/// | `shouldReceive(_:UIEvent)` | `shouldReceiveEvent` | `true` |
/// | `shouldRequireFailureOf` | `shouldRequireFailureOf` | `false` |
/// | `shouldBeRequiredToFailBy` | `shouldBeRequiredToFailBy` | `false` |
public class GestureCoordinator: NSObject, UIGestureRecognizerDelegate {

    /// Determines whether the gesture recognizer should begin interpreting touches.
    /// When `nil`, defaults to `true`.
    let shouldBegin: ((UIGestureRecognizer) -> Bool)?

    /// Determines whether this gesture recognizer should recognize simultaneously
    /// with another. When `nil`, defaults to `true`.
    let shouldRecognizeSimultaneouslyWith: ((UIGestureRecognizer) -> Bool)?

    /// Determines whether the gesture recognizer should receive a given touch.
    /// When `nil`, defaults to `true`.
    let shouldReceiveTouch: ((UIGestureRecognizer, UITouch) -> Bool)?

    /// Determines whether the gesture recognizer should receive a given press.
    /// When `nil`, defaults to `true`.
    let shouldReceivePress: ((UIGestureRecognizer, UIPress) -> Bool)?

    /// Determines whether the gesture recognizer should receive a given event.
    /// When `nil`, defaults to `true`.
    let shouldReceiveEvent: ((UIGestureRecognizer, UIEvent) -> Bool)?

    /// Determines whether this gesture recognizer should require the other
    /// gesture recognizer to fail before it can begin. When `nil`, defaults to `false`.
    let shouldRequireFailureOf: ((UIGestureRecognizer) -> Bool)?

    /// Determines whether this gesture recognizer should be required to fail
    /// by the other gesture recognizer. When `nil`, defaults to `false`.
    let shouldBeRequiredToFailBy: ((UIGestureRecognizer) -> Bool)?

    internal init(shouldBegin: ((UIGestureRecognizer) -> Bool)? = nil,
                  shouldRecognizeSimultaneouslyWith: ((UIGestureRecognizer) -> Bool)? = nil,
                  shouldReceiveTouch: ((UIGestureRecognizer, UITouch) -> Bool)? = nil,
                  shouldReceivePress: ((UIGestureRecognizer, UIPress) -> Bool)? = nil,
                  shouldReceiveEvent: ((UIGestureRecognizer, UIEvent) -> Bool)? = nil,
                  shouldRequireFailureOf: ((UIGestureRecognizer) -> Bool)? = nil,
                  shouldBeRequiredToFailBy: ((UIGestureRecognizer) -> Bool)? = nil) {
        self.shouldBegin = shouldBegin
        self.shouldRecognizeSimultaneouslyWith = shouldRecognizeSimultaneouslyWith
        self.shouldReceiveTouch = shouldReceiveTouch
        self.shouldReceivePress = shouldReceivePress
        self.shouldReceiveEvent = shouldReceiveEvent
        self.shouldRequireFailureOf = shouldRequireFailureOf
        self.shouldBeRequiredToFailBy = shouldBeRequiredToFailBy
    }

    // MARK: - UIGestureRecognizerDelegate

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return self.shouldBegin?(gestureRecognizer) ?? true
    }

    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                                  shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return self.shouldRecognizeSimultaneouslyWith?(otherGestureRecognizer) ?? true
    }

    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                                  shouldReceive touch: UITouch) -> Bool {
        return self.shouldReceiveTouch?(gestureRecognizer, touch) ?? true
    }

    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                                  shouldReceive press: UIPress) -> Bool {
        return self.shouldReceivePress?(gestureRecognizer, press) ?? true
    }

    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                                  shouldReceive event: UIEvent) -> Bool {
        return self.shouldReceiveEvent?(gestureRecognizer, event) ?? true
    }

    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                                  shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return self.shouldRequireFailureOf?(otherGestureRecognizer) ?? false
    }

    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                                  shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return self.shouldBeRequiredToFailBy?(otherGestureRecognizer) ?? false
    }
}
