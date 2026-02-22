//
//  MultiFingerLongPressGesture.swift
//  UIKitGesturesForSwiftUI
//
//  Created by Jacob Van Order on 2/18/26.
//

import Foundation
import SwiftUI
import UIKit

/// A SwiftUI bridge for UIKit's `UILongPressGestureRecognizer`.
///
/// `MultiFingerLongPressGesture` wraps `UILongPressGestureRecognizer` using the
/// `UIGestureRecognizerRepresentable` protocol, exposing UIKit's long-press gesture
/// configuration directly within SwiftUI views.
///
/// ## Why use this instead of SwiftUI's `.onLongPressGesture`?
///
/// SwiftUI's built-in long press gesture modifier is limited in configuration.
/// `UILongPressGestureRecognizer` provides additional control over:
/// - The number of fingers required (`numberOfTouchesRequired`)
/// - The number of taps required before the press (`numberOfTapsRequired`)
/// - The allowable finger movement before failure (`allowableMovement`)
/// - The minimum press duration (`minimumPressDuration`)
///
/// ## Continuous gesture lifecycle
///
/// `UILongPressGestureRecognizer` is a **continuous** gesture recognizer, meaning it
/// transitions through multiple states and calls your action handlers many times:
///
/// 1. **Began** — The user has held their finger(s) down long enough to meet the
///    `minimumPressDuration` threshold and hasn't moved beyond `allowableMovement`.
///    This is typically where you'd show visual feedback (e.g., highlighting, a context menu).
///
/// 2. **Changed** — The user's finger(s) moved while still pressing down. The gesture
///    recognizer fires this state each time the touch location updates. You can use
///    `location(in:)` on the recognizer to track the finger position.
///
/// 3. **Ended** — The user lifted all fingers from the screen. The long-press interaction
///    is complete.
///
/// ## Usage
///
/// ```swift
/// Rectangle()
///     .fill(.blue)
///     .gesture(
///         MultiFingerLongPressGesture(
///             minimumPressDuration: 0.5,
///             numberOfTouchesRequired: 2
///         )
///         .onBegan { recognizer in
///             print("Long press began at: \(recognizer.location(in: recognizer.view))")
///         }
///         .onChanged { recognizer in
///             print("Finger moved to: \(recognizer.location(in: recognizer.view))")
///         }
///         .onEnded { recognizer in
///             print("Long press ended")
///         }
///     )
/// ```
public struct MultiFingerLongPressGesture: UIGestureRecognizerRepresentable {

    // MARK: - Configuration Properties

    /// The minimum duration (in seconds) that the user must press for the gesture
    /// to be recognized.
    ///
    /// The default value mirrors UIKit's default of `0.5` seconds. Once this duration
    /// elapses (and the finger hasn't moved beyond `allowableMovement`), the gesture
    /// transitions to the `.began` state.
    public let minimumPressDuration: TimeInterval

    /// The number of fingers that must simultaneously touch the view for the gesture
    /// to be recognized.
    ///
    /// For example, setting this to `2` requires a two-finger long press. The default
    /// value is `1`.
    public let numberOfTouchesRequired: Int

    /// The number of taps required before the long press is evaluated.
    ///
    /// A value of `0` (the default) means no tap is needed — the user simply presses
    /// and holds. A value of `1` means the user must tap once, then press and hold.
    public let numberOfTapsRequired: Int

    /// The maximum distance (in points) the finger(s) can move before the gesture fails.
    ///
    /// If the user's fingers drift more than this distance from their initial touch
    /// point during the press duration, the gesture recognizer transitions to the
    /// `.failed` state and the `onBegan` closure is never called.
    /// The default value mirrors UIKit's default of `10` points.
    public let allowableMovement: CGFloat

    // MARK: - Lifecycle Closures

    /// Called when the gesture transitions to the `.began` state.
    ///
    /// At this point the user has held their finger(s) for at least `minimumPressDuration`
    /// without moving beyond `allowableMovement`. The recognizer is passed so you can
    /// query `location(in:)` or `numberOfTouches`.
    private let onBegan: (@MainActor (UILongPressGestureRecognizer) -> Void)?

    /// Called each time the gesture transitions to the `.changed` state.
    ///
    /// This fires whenever the user's finger(s) move while still pressing down.
    /// Use `location(in:)` on the recognizer to track the current position.
    private let onChanged: (@MainActor (UILongPressGestureRecognizer) -> Void)?

    /// Called when the gesture transitions to the `.ended` state.
    ///
    /// This fires when the user lifts all fingers from the screen, completing the
    /// long-press interaction.
    private let onEnded: (@MainActor (UILongPressGestureRecognizer) -> Void)?

    // MARK: - Delegate Closures

    /// An optional closure that determines whether the gesture recognizer should begin
    /// interpreting touches. When `nil`, defaults to `true`.
    private let shouldBegin: (@MainActor (UIGestureRecognizer) -> Bool)?

    /// An optional closure that determines whether this gesture recognizer should
    /// recognize simultaneously with another gesture recognizer.
    ///
    /// Return `true` to allow both gestures to proceed at the same time, or `false`
    /// to prevent simultaneous recognition. When `nil`, the default behavior is to
    /// allow simultaneous recognition (`true`).
    private let shouldRecognizeSimultaneouslyWith: (@MainActor (UIGestureRecognizer) -> Bool)?

    /// An optional closure that determines whether the gesture recognizer should
    /// receive a given touch. When `nil`, defaults to `true`.
    private let shouldReceiveTouch: (@MainActor (UIGestureRecognizer, UITouch) -> Bool)?

    /// An optional closure that determines whether the gesture recognizer should
    /// receive a given press. When `nil`, defaults to `true`.
    private let shouldReceivePress: (@MainActor (UIGestureRecognizer, UIPress) -> Bool)?

    /// An optional closure that determines whether the gesture recognizer should
    /// receive a given event. When `nil`, defaults to `true`.
    private let shouldReceiveEvent: (@MainActor (UIGestureRecognizer, UIEvent) -> Bool)?

    /// An optional closure that determines whether this gesture recognizer should
    /// require the other gesture recognizer to fail before it can begin.
    /// When `nil`, defaults to `false`.
    private let shouldRequireFailureOf: (@MainActor (UIGestureRecognizer) -> Bool)?

    /// An optional closure that determines whether this gesture recognizer should
    /// be required to fail by the other gesture recognizer.
    /// When `nil`, defaults to `false`.
    private let shouldBeRequiredToFailBy: (@MainActor (UIGestureRecognizer) -> Bool)?

    // MARK: - Initializer

    /// Creates a new `MultiFingerLongPressGesture` with the specified configuration.
    ///
    /// - Parameters:
    ///   - minimumPressDuration: How long (in seconds) the user must press before the
    ///     gesture begins. Defaults to `0.5`.
    ///   - numberOfTouchesRequired: The number of fingers required. Defaults to `1`.
    ///   - numberOfTapsRequired: The number of taps required before the press. Defaults to `0`.
    ///   - allowableMovement: The maximum distance (in points) fingers can move before the
    ///     gesture fails. Defaults to `10`.
    ///   - onBegan: Closure called when the long press is first recognized. Defaults to `nil`.
    ///   - onChanged: Closure called each time the finger position changes during the press.
    ///     Defaults to `nil`.
    ///   - onEnded: Closure called when the user lifts their fingers. Defaults to `nil`.
    ///   - shouldBegin: Closure to control whether the gesture should begin. Defaults to `nil` (`true`).
    ///   - shouldRecognizeSimultaneouslyWith: Closure to control simultaneous gesture
    ///     recognition. Defaults to `nil` (allows simultaneous recognition).
    ///   - shouldReceiveTouch: Closure to control whether the gesture receives a touch.
    ///     Defaults to `nil` (`true`).
    ///   - shouldReceivePress: Closure to control whether the gesture receives a press.
    ///     Defaults to `nil` (`true`).
    ///   - shouldReceiveEvent: Closure to control whether the gesture receives an event.
    ///     Defaults to `nil` (`true`).
    ///   - shouldRequireFailureOf: Closure to control failure requirements.
    ///     Defaults to `nil` (`false`).
    ///   - shouldBeRequiredToFailBy: Closure to control failure requirements.
    ///     Defaults to `nil` (`false`).
    public init(minimumPressDuration: TimeInterval = 0.5,
                numberOfTouchesRequired: Int = 1,
                numberOfTapsRequired: Int = 0,
                allowableMovement: CGFloat = 10,
                onBegan: (@MainActor (UILongPressGestureRecognizer) -> Void)? = nil,
                onChanged: (@MainActor (UILongPressGestureRecognizer) -> Void)? = nil,
                onEnded: (@MainActor (UILongPressGestureRecognizer) -> Void)? = nil,
                shouldBegin: (@MainActor (UIGestureRecognizer) -> Bool)? = nil,
                shouldRecognizeSimultaneouslyWith: (@MainActor (UIGestureRecognizer) -> Bool)? = nil,
                shouldReceiveTouch: (@MainActor (UIGestureRecognizer, UITouch) -> Bool)? = nil,
                shouldReceivePress: (@MainActor (UIGestureRecognizer, UIPress) -> Bool)? = nil,
                shouldReceiveEvent: (@MainActor (UIGestureRecognizer, UIEvent) -> Bool)? = nil,
                shouldRequireFailureOf: (@MainActor (UIGestureRecognizer) -> Bool)? = nil,
                shouldBeRequiredToFailBy: (@MainActor (UIGestureRecognizer) -> Bool)? = nil) {
        self.minimumPressDuration = minimumPressDuration
        self.numberOfTouchesRequired = numberOfTouchesRequired
        self.numberOfTapsRequired = numberOfTapsRequired
        self.allowableMovement = allowableMovement
        self.onBegan = onBegan
        self.onChanged = onChanged
        self.onEnded = onEnded
        self.shouldBegin = shouldBegin
        self.shouldRecognizeSimultaneouslyWith = shouldRecognizeSimultaneouslyWith
        self.shouldReceiveTouch = shouldReceiveTouch
        self.shouldReceivePress = shouldReceivePress
        self.shouldReceiveEvent = shouldReceiveEvent
        self.shouldRequireFailureOf = shouldRequireFailureOf
        self.shouldBeRequiredToFailBy = shouldBeRequiredToFailBy
    }

    // MARK: - UIGestureRecognizerRepresentable

    /// Creates and configures the underlying `UILongPressGestureRecognizer`.
    ///
    /// This method is called once by SwiftUI when the gesture is first attached to a view.
    /// The recognizer is configured with the values provided at initialization, and its
    /// delegate is set to the coordinator for simultaneous recognition support.
    public func makeUIGestureRecognizer(context: Context) -> UILongPressGestureRecognizer {
        let longPressGesture = UILongPressGestureRecognizer()
        longPressGesture.minimumPressDuration = minimumPressDuration
        longPressGesture.numberOfTouchesRequired = numberOfTouchesRequired
        longPressGesture.numberOfTapsRequired = numberOfTapsRequired
        longPressGesture.allowableMovement = allowableMovement
        longPressGesture.delegate = context.coordinator
        return longPressGesture
    }

    /// Updates the gesture recognizer when SwiftUI re-evaluates the view.
    ///
    /// If the configuration values change (e.g., `minimumPressDuration` is driven by
    /// state), the existing recognizer is updated in place rather than recreated.
    public func updateUIGestureRecognizer(_ recognizer: UILongPressGestureRecognizer,
                                          context: Context) {
        recognizer.minimumPressDuration = minimumPressDuration
        recognizer.numberOfTouchesRequired = numberOfTouchesRequired
        recognizer.numberOfTapsRequired = numberOfTapsRequired
        recognizer.allowableMovement = allowableMovement
    }

    // MARK: - Factory Methods (Builder Pattern)

    /// Returns a new gesture with the provided `onBegan` closure, preserving all
    /// other configuration.
    ///
    /// Use this to chain callbacks in a declarative style:
    /// ```swift
    /// MultiFingerLongPressGesture(minimumPressDuration: 1.0)
    ///     .onBegan { recognizer in
    ///         // Handle began
    ///     }
    /// ```
    public func onBegan(_ action: @escaping @MainActor (UILongPressGestureRecognizer) -> Void) -> MultiFingerLongPressGesture {
        MultiFingerLongPressGesture(minimumPressDuration: self.minimumPressDuration,
                                    numberOfTouchesRequired: self.numberOfTouchesRequired,
                                    numberOfTapsRequired: self.numberOfTapsRequired,
                                    allowableMovement: self.allowableMovement,
                                    onBegan: action,
                                    onChanged: self.onChanged,
                                    onEnded: self.onEnded,
                                    shouldBegin: self.shouldBegin,
                                    shouldRecognizeSimultaneouslyWith: self.shouldRecognizeSimultaneouslyWith,
                                    shouldReceiveTouch: self.shouldReceiveTouch,
                                    shouldReceivePress: self.shouldReceivePress,
                                    shouldReceiveEvent: self.shouldReceiveEvent,
                                    shouldRequireFailureOf: self.shouldRequireFailureOf,
                                    shouldBeRequiredToFailBy: self.shouldBeRequiredToFailBy)
    }

    /// Returns a new gesture with the provided `onChanged` closure, preserving all
    /// other configuration.
    ///
    /// ```swift
    /// MultiFingerLongPressGesture()
    ///     .onChanged { recognizer in
    ///         let point = recognizer.location(in: recognizer.view)
    ///         // Track finger movement during press
    ///     }
    /// ```
    public func onChanged(_ action: @escaping @MainActor (UILongPressGestureRecognizer) -> Void) -> MultiFingerLongPressGesture {
        MultiFingerLongPressGesture(minimumPressDuration: self.minimumPressDuration,
                                    numberOfTouchesRequired: self.numberOfTouchesRequired,
                                    numberOfTapsRequired: self.numberOfTapsRequired,
                                    allowableMovement: self.allowableMovement,
                                    onBegan: self.onBegan,
                                    onChanged: action,
                                    onEnded: self.onEnded,
                                    shouldBegin: self.shouldBegin,
                                    shouldRecognizeSimultaneouslyWith: self.shouldRecognizeSimultaneouslyWith,
                                    shouldReceiveTouch: self.shouldReceiveTouch,
                                    shouldReceivePress: self.shouldReceivePress,
                                    shouldReceiveEvent: self.shouldReceiveEvent,
                                    shouldRequireFailureOf: self.shouldRequireFailureOf,
                                    shouldBeRequiredToFailBy: self.shouldBeRequiredToFailBy)
    }

    /// Returns a new gesture with the provided `onEnded` closure, preserving all
    /// other configuration.
    ///
    /// ```swift
    /// MultiFingerLongPressGesture()
    ///     .onEnded { recognizer in
    ///         // User lifted their fingers
    ///     }
    /// ```
    public func onEnded(_ action: @escaping @MainActor (UILongPressGestureRecognizer) -> Void) -> MultiFingerLongPressGesture {
        MultiFingerLongPressGesture(minimumPressDuration: self.minimumPressDuration,
                                    numberOfTouchesRequired: self.numberOfTouchesRequired,
                                    numberOfTapsRequired: self.numberOfTapsRequired,
                                    allowableMovement: self.allowableMovement,
                                    onBegan: self.onBegan,
                                    onChanged: self.onChanged,
                                    onEnded: action,
                                    shouldBegin: self.shouldBegin,
                                    shouldRecognizeSimultaneouslyWith: self.shouldRecognizeSimultaneouslyWith,
                                    shouldReceiveTouch: self.shouldReceiveTouch,
                                    shouldReceivePress: self.shouldReceivePress,
                                    shouldReceiveEvent: self.shouldReceiveEvent,
                                    shouldRequireFailureOf: self.shouldRequireFailureOf,
                                    shouldBeRequiredToFailBy: self.shouldBeRequiredToFailBy)
    }

    // MARK: - Action Handling

    /// Routes gesture recognizer state changes to the appropriate closure.
    ///
    /// This method is called by the `UIGestureRecognizerRepresentable` infrastructure
    /// each time the gesture recognizer's state changes. The state machine for a
    /// continuous gesture is:
    ///
    /// ```
    /// .possible → .began → .changed (repeated) → .ended
    ///                 ↘ .cancelled
    ///                 ↘ .failed
    /// ```
    ///
    /// Only `.began`, `.changed`, and `.ended` are forwarded to the closures.
    /// The `.cancelled` and `.failed` states are intentionally not exposed because
    /// they indicate the gesture was interrupted or never fully recognized.
    public func handleUIGestureRecognizerAction(_ recognizer: UILongPressGestureRecognizer,
                                                context: Context) {
        switch recognizer.state {
        case .possible:
            break
        case .began:
            onBegan?(recognizer)
        case .changed:
            onChanged?(recognizer)
        case .ended:
            onEnded?(recognizer)
        case .cancelled:
            break
        case .failed:
            break
        case .recognized:
            break
        @unknown default:
            break
        }
    }

    // MARK: - Coordinator

    /// Creates the coordinator that serves as the gesture recognizer's delegate.
    ///
    /// The coordinator handles all `UIGestureRecognizerDelegate` methods,
    /// forwarding each decision to the corresponding closure if one was provided.
    public func makeCoordinator(converter: CoordinateSpaceConverter) -> GestureCoordinator {
        GestureCoordinator(shouldBegin: shouldBegin,
                           shouldRecognizeSimultaneouslyWith: shouldRecognizeSimultaneouslyWith,
                           shouldReceiveTouch: shouldReceiveTouch,
                           shouldReceivePress: shouldReceivePress,
                           shouldReceiveEvent: shouldReceiveEvent,
                           shouldRequireFailureOf: shouldRequireFailureOf,
                           shouldBeRequiredToFailBy: shouldBeRequiredToFailBy)
    }
}
