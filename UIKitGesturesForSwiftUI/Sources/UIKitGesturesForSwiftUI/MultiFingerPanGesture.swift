//
//  MultiFingerPanGesture.swift
//  UIKitGesturesForSwiftUI
//
//  Created by Jacob Van Order on 2/17/26.
//

import Foundation
import SwiftUI
import UIKit

/// A SwiftUI bridge for UIKit's `UIPanGestureRecognizer`.
///
/// `MultiFingerPanGesture` wraps `UIPanGestureRecognizer` using the
/// `UIGestureRecognizerRepresentable` protocol, exposing UIKit's pan gesture
/// configuration directly within SwiftUI views.
///
/// ## Why use this instead of SwiftUI's `DragGesture`?
///
/// SwiftUI's built-in `DragGesture` only supports single-finger panning. UIKit's
/// `UIPanGestureRecognizer` provides control over:
/// - The minimum number of fingers required (`minimumNumberOfTouches`)
/// - The maximum number of fingers allowed (`maximumNumberOfTouches`)
/// - Access to UIKit-specific data like `velocity(in:)` and `translation(in:)`
///
/// This makes it possible to implement multi-finger panning (e.g., two-finger scrolling,
/// three-finger swipes) that SwiftUI cannot express natively.
///
/// ## Continuous gesture lifecycle
///
/// `UIPanGestureRecognizer` is a **continuous** gesture recognizer, meaning it
/// transitions through multiple states and calls your action handlers many times:
///
/// 1. **Began** — The user has placed the required number of fingers on the screen
///    and started moving them. This fires once at the start of the pan.
///
/// 2. **Changed** — The user's finger(s) moved. The gesture recognizer fires this
///    state each time the touch location updates. You can use `translation(in:)` and
///    `velocity(in:)` on the recognizer to track the pan's progress and speed.
///
/// 3. **Ended** — The user lifted all fingers from the screen. The pan is complete.
///    You can still read `velocity(in:)` here for momentum-based animations.
///
/// ## Usage
///
/// ```swift
/// Rectangle()
///     .fill(.blue)
///     .gesture(
///         MultiFingerPanGesture(
///             minimumNumberOfTouches: 2,
///             maximumNumberOfTouches: 2
///         )
///         .onBegan { recognizer in
///             print("Pan began")
///         }
///         .onChanged { recognizer in
///             let translation = recognizer.translation(in: recognizer.view)
///             print("Panned by: \(translation)")
///         }
///         .onEnded { recognizer in
///             let velocity = recognizer.velocity(in: recognizer.view)
///             print("Pan ended with velocity: \(velocity)")
///         }
///     )
/// ```
public struct MultiFingerPanGesture: UIGestureRecognizerRepresentable {

    // MARK: - Configuration Properties

    /// The minimum number of fingers that must touch the view for the gesture to begin.
    ///
    /// For example, setting this to `2` means the pan won't start until the user places
    /// at least two fingers on the screen. This maps directly to
    /// `UIPanGestureRecognizer.minimumNumberOfTouches`.
    public let minimumNumberOfTouches: Int

    /// The maximum number of fingers that can touch the view while the gesture is active.
    ///
    /// If the user places more fingers than this value, the gesture recognizer transitions
    /// to the `.failed` state. This maps directly to
    /// `UIPanGestureRecognizer.maximumNumberOfTouches`.
    public let maximumNumberOfTouches: Int

    // MARK: - Lifecycle Closures

    /// Called when the gesture transitions to the `.began` state.
    ///
    /// At this point the user has placed the required number of fingers on the screen
    /// and moved enough to be recognized as a pan. The recognizer is passed so you can
    /// query `translation(in:)`, `velocity(in:)`, or `numberOfTouches`.
    private let onBegan: (@MainActor (UIPanGestureRecognizer) -> Void)?

    /// Called each time the gesture transitions to the `.changed` state.
    ///
    /// This fires whenever the user's finger(s) move while panning. Use
    /// `translation(in:)` on the recognizer to get the cumulative distance panned
    /// since the gesture began, or `velocity(in:)` for the current speed in
    /// points per second.
    private let onChanged: (@MainActor (UIPanGestureRecognizer) -> Void)?

    /// Called when the gesture transitions to the `.ended` state.
    ///
    /// This fires when the user lifts all fingers from the screen. You can still
    /// read `velocity(in:)` at this point — useful for driving momentum-based
    /// animations after the pan ends.
    private let onEnded: (@MainActor (UIPanGestureRecognizer) -> Void)?

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

    /// Creates a new `MultiFingerPanGesture` with the specified finger count range.
    ///
    /// - Parameters:
    ///   - minimumNumberOfTouches: The minimum number of fingers required to begin the pan.
    ///   - maximumNumberOfTouches: The maximum number of fingers allowed during the pan.
    ///   - onBegan: Closure called when the pan is first recognized. Defaults to `nil`.
    ///   - onChanged: Closure called each time the finger position changes during the pan.
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
    public init(minimumNumberOfTouches: Int,
                maximumNumberOfTouches: Int,
                onBegan: (@MainActor (UIPanGestureRecognizer) -> Void)? = nil,
                onChanged: (@MainActor (UIPanGestureRecognizer) -> Void)? = nil,
                onEnded: (@MainActor (UIPanGestureRecognizer) -> Void)? = nil,
                shouldBegin: (@MainActor (UIGestureRecognizer) -> Bool)? = nil,
                shouldRecognizeSimultaneouslyWith: (@MainActor (UIGestureRecognizer) -> Bool)? = nil,
                shouldReceiveTouch: (@MainActor (UIGestureRecognizer, UITouch) -> Bool)? = nil,
                shouldReceivePress: (@MainActor (UIGestureRecognizer, UIPress) -> Bool)? = nil,
                shouldReceiveEvent: (@MainActor (UIGestureRecognizer, UIEvent) -> Bool)? = nil,
                shouldRequireFailureOf: (@MainActor (UIGestureRecognizer) -> Bool)? = nil,
                shouldBeRequiredToFailBy: (@MainActor (UIGestureRecognizer) -> Bool)? = nil) {
        self.minimumNumberOfTouches = minimumNumberOfTouches
        self.maximumNumberOfTouches = maximumNumberOfTouches
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

    /// Creates and configures the underlying `UIPanGestureRecognizer`.
    ///
    /// This method is called once by SwiftUI when the gesture is first attached to a view.
    /// The recognizer is configured with the touch count range provided at initialization,
    /// and its delegate is set to the coordinator for simultaneous recognition support.
    public func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let panGesture = UIPanGestureRecognizer()
        panGesture.minimumNumberOfTouches = minimumNumberOfTouches
        panGesture.maximumNumberOfTouches = maximumNumberOfTouches
        panGesture.delegate = context.coordinator
        return panGesture
    }

    /// Updates the gesture recognizer when SwiftUI re-evaluates the view.
    ///
    /// If the configuration values change (e.g., the touch counts are driven by state),
    /// the existing recognizer is updated in place rather than recreated.
    public func updateUIGestureRecognizer(_ recognizer: UIPanGestureRecognizer,
                                          context: Context) {
        recognizer.minimumNumberOfTouches = minimumNumberOfTouches
        recognizer.maximumNumberOfTouches = maximumNumberOfTouches
    }

    // MARK: - Factory Methods (Builder Pattern)

    /// Returns a new gesture with the provided `onBegan` closure, preserving all
    /// other configuration.
    ///
    /// Use this to chain callbacks in a declarative style:
    /// ```swift
    /// MultiFingerPanGesture(minimumNumberOfTouches: 2, maximumNumberOfTouches: 2)
    ///     .onBegan { recognizer in
    ///         // Handle began
    ///     }
    /// ```
    public func onBegan(_ action: @escaping @MainActor (UIPanGestureRecognizer) -> Void) -> MultiFingerPanGesture {
        MultiFingerPanGesture(minimumNumberOfTouches: self.minimumNumberOfTouches,
                              maximumNumberOfTouches: self.maximumNumberOfTouches,
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
    /// MultiFingerPanGesture(minimumNumberOfTouches: 2, maximumNumberOfTouches: 2)
    ///     .onChanged { recognizer in
    ///         let translation = recognizer.translation(in: recognizer.view)
    ///         // Apply translation to your view
    ///     }
    /// ```
    public func onChanged(_ action: @escaping @MainActor (UIPanGestureRecognizer) -> Void) -> MultiFingerPanGesture {
        MultiFingerPanGesture(minimumNumberOfTouches: self.minimumNumberOfTouches,
                              maximumNumberOfTouches: self.maximumNumberOfTouches,
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
    /// MultiFingerPanGesture(minimumNumberOfTouches: 2, maximumNumberOfTouches: 2)
    ///     .onEnded { recognizer in
    ///         let velocity = recognizer.velocity(in: recognizer.view)
    ///         // Use velocity for momentum animations
    ///     }
    /// ```
    public func onEnded(_ action: @escaping @MainActor (UIPanGestureRecognizer) -> Void) -> MultiFingerPanGesture {
        MultiFingerPanGesture(minimumNumberOfTouches: self.minimumNumberOfTouches,
                              maximumNumberOfTouches: self.maximumNumberOfTouches,
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
    public func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer,
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
