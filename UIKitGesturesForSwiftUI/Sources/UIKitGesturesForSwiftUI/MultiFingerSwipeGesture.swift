//
//  MultiFingerSwipeGesture.swift
//  UIKitGesturesForSwiftUI
//
//  Created by Jacob Van Order on 2/18/26.
//

import Foundation
import SwiftUI
import UIKit

/// A SwiftUI bridge for UIKit's `UISwipeGestureRecognizer`.
///
/// `MultiFingerSwipeGesture` wraps `UISwipeGestureRecognizer` using the
/// `UIGestureRecognizerRepresentable` protocol, exposing UIKit's swipe gesture
/// configuration directly within SwiftUI views.
///
/// ## Why use this instead of SwiftUI's gestures?
///
/// SwiftUI does not provide a dedicated swipe gesture recognizer. Developers typically
/// approximate swipes using `DragGesture` with manual threshold checks, which is
/// error-prone and doesn't match the native feel. `UISwipeGestureRecognizer` provides:
/// - Built-in directional recognition with automatic speed and precision tuning
///   (slow swipes require high precision; fast swipes tolerate more deviation)
/// - The number of fingers required (`numberOfTouchesRequired`)
/// - The permitted swipe direction(s) (`direction`)
///
/// ## Swipe directions
///
/// The `direction` property uses `UISwipeGestureRecognizer.Direction`, which is an
/// `OptionSet`. You can specify a single direction or combine multiple directions:
///
/// | Value    | Meaning                                    |
/// |----------|--------------------------------------------|
/// | `.right` | Swipe from leading to trailing (default)   |
/// | `.left`  | Swipe from trailing to leading              |
/// | `.up`    | Swipe upward                               |
/// | `.down`  | Swipe downward                             |
///
/// When you combine directions (e.g., `[.left, .right]`), the recognizer will fire
/// for a swipe in **any** of the specified directions. If you need to distinguish
/// which direction was swiped, create separate `MultiFingerSwipeGesture` instances —
/// one per direction — and attach them all to the same view.
///
/// ## Discrete gesture lifecycle
///
/// `UISwipeGestureRecognizer` is a **discrete** gesture recognizer. Unlike continuous
/// gestures (pan, long press), a discrete recognizer calls your action method exactly
/// once after the gesture is fully recognized. There is no `.began` or `.changed` phase —
/// only `.ended`, which fires when the user completes a swipe matching the configured
/// direction and finger count.
///
/// A swipe is recognized when the user moves the required number of fingers far enough
/// and fast enough in the permitted direction. A slow swipe requires high directional
/// precision but a small distance; a fast swipe requires low directional precision but
/// a large distance. If the motion doesn't qualify, the recognizer transitions to
/// `.failed` silently and `onEnded` is never called.
///
/// ## Usage
///
/// ```swift
/// // Single direction, single finger:
/// Rectangle()
///     .fill(.blue)
///     .gesture(
///         MultiFingerSwipeGesture(direction: .left)
///             .onEnded { recognizer in
///                 print("Swiped left!")
///             }
///     )
///
/// // Two-finger swipe in any horizontal direction:
/// Rectangle()
///     .fill(.green)
///     .gesture(
///         MultiFingerSwipeGesture(
///             direction: [.left, .right],
///             numberOfTouchesRequired: 2
///         )
///         .onEnded { recognizer in
///             let location = recognizer.location(in: recognizer.view)
///             print("Two-finger horizontal swipe at: \(location)")
///         }
///     )
/// ```
///
/// ## Distinguishing swipe directions
///
/// If you need to run different logic per direction, attach one gesture per direction:
///
/// ```swift
/// Rectangle()
///     .fill(.orange)
///     .gesture(
///         MultiFingerSwipeGesture(direction: .left)
///             .onEnded { _ in print("Left") }
///     )
///     .gesture(
///         MultiFingerSwipeGesture(direction: .right)
///             .onEnded { _ in print("Right") }
///     )
/// ```
public struct MultiFingerSwipeGesture: UIGestureRecognizerRepresentable {

    // MARK: - Configuration Properties

    /// The permitted direction(s) of the swipe for recognition.
    ///
    /// This is an `OptionSet` — you can specify a single direction (e.g., `.left`) or
    /// combine multiple directions (e.g., `[.left, .right]`). When multiple directions
    /// are specified, a swipe in **any** of those directions will trigger recognition.
    ///
    /// The default value is `.right`, matching `UISwipeGestureRecognizer`'s default.
    /// This maps directly to `UISwipeGestureRecognizer.direction`.
    public let direction: UISwipeGestureRecognizer.Direction

    /// The number of fingers that must simultaneously touch the view for the gesture
    /// to be recognized.
    ///
    /// For example, setting this to `2` requires a two-finger swipe. The default value
    /// is `1`. This maps directly to `UISwipeGestureRecognizer.numberOfTouchesRequired`.
    public let numberOfTouchesRequired: Int

    // MARK: - Lifecycle Closures

    /// Called when the gesture transitions to the `.ended` state.
    ///
    /// Because `UISwipeGestureRecognizer` is a discrete gesture, this is the only
    /// lifecycle callback. It fires once when a swipe matching the configured direction
    /// and finger count is completed. The recognizer is passed so you can query
    /// `location(in:)` to determine where the swipe started, or `location(ofTouch:in:)`
    /// to get individual finger positions.
    private let onEnded: (@MainActor (UISwipeGestureRecognizer) -> Void)?

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
    ///
    /// This is particularly useful when combining swipe gestures with pan gestures.
    /// By default, a swipe and a pan on the same view would conflict. You can use
    /// this closure to allow or deny simultaneous recognition based on the type of
    /// the other gesture recognizer.
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

    /// Creates a new `MultiFingerSwipeGesture` with the specified configuration.
    ///
    /// - Parameters:
    ///   - direction: The permitted swipe direction(s). Defaults to `.right`.
    ///     Pass a single value like `.left` or combine multiple like `[.up, .down]`.
    ///   - numberOfTouchesRequired: The number of fingers required. Defaults to `1`.
    ///   - onEnded: Closure called when the swipe is recognized. Defaults to `nil`.
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
    public init(direction: UISwipeGestureRecognizer.Direction = .right,
                numberOfTouchesRequired: Int = 1,
                onEnded: (@MainActor (UISwipeGestureRecognizer) -> Void)? = nil,
                shouldBegin: (@MainActor (UIGestureRecognizer) -> Bool)? = nil,
                shouldRecognizeSimultaneouslyWith: (@MainActor (UIGestureRecognizer) -> Bool)? = nil,
                shouldReceiveTouch: (@MainActor (UIGestureRecognizer, UITouch) -> Bool)? = nil,
                shouldReceivePress: (@MainActor (UIGestureRecognizer, UIPress) -> Bool)? = nil,
                shouldReceiveEvent: (@MainActor (UIGestureRecognizer, UIEvent) -> Bool)? = nil,
                shouldRequireFailureOf: (@MainActor (UIGestureRecognizer) -> Bool)? = nil,
                shouldBeRequiredToFailBy: (@MainActor (UIGestureRecognizer) -> Bool)? = nil) {
        self.direction = direction
        self.numberOfTouchesRequired = numberOfTouchesRequired
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

    /// Creates and configures the underlying `UISwipeGestureRecognizer`.
    ///
    /// This method is called once by SwiftUI when the gesture is first attached to a view.
    /// The recognizer is configured with the direction and touch count provided at
    /// initialization, and its delegate is set to the coordinator for simultaneous
    /// recognition support.
    public func makeUIGestureRecognizer(context: Context) -> UISwipeGestureRecognizer {
        let swipeGesture = UISwipeGestureRecognizer()
        swipeGesture.direction = direction
        swipeGesture.numberOfTouchesRequired = numberOfTouchesRequired
        swipeGesture.delegate = context.coordinator
        return swipeGesture
    }

    /// Updates the gesture recognizer when SwiftUI re-evaluates the view.
    ///
    /// If the configuration values change (e.g., the direction or touch count is driven
    /// by state), the existing recognizer is updated in place rather than recreated.
    public func updateUIGestureRecognizer(_ recognizer: UISwipeGestureRecognizer,
                                          context: Context) {
        recognizer.direction = direction
        recognizer.numberOfTouchesRequired = numberOfTouchesRequired
    }

    // MARK: - Factory Methods (Builder Pattern)

    /// Returns a new gesture with the provided `onEnded` closure, preserving all
    /// other configuration.
    ///
    /// Use this to chain the callback in a declarative style:
    /// ```swift
    /// MultiFingerSwipeGesture(direction: .up, numberOfTouchesRequired: 2)
    ///     .onEnded { recognizer in
    ///         // Handle the swipe
    ///     }
    /// ```
    public func onEnded(_ action: @escaping @MainActor (UISwipeGestureRecognizer) -> Void) -> MultiFingerSwipeGesture {
        MultiFingerSwipeGesture(direction: self.direction,
                                numberOfTouchesRequired: self.numberOfTouchesRequired,
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

    /// Routes gesture recognizer state changes to the `onEnded` closure.
    ///
    /// This method is called by the `UIGestureRecognizerRepresentable` infrastructure
    /// when the gesture recognizer's state changes. For a discrete gesture recognizer,
    /// the state machine is simpler than a continuous gesture:
    ///
    /// ```
    /// .possible → .ended (aka .recognized)
    ///         ↘ .failed
    /// ```
    ///
    /// Only the `.ended` state is forwarded to the closure. Note that for discrete
    /// gesture recognizers, `.ended` and `.recognized` are the same raw value — the
    /// switch uses `.ended` for clarity.
    ///
    /// If the user's motion doesn't qualify as a swipe (wrong direction, not enough
    /// distance, too slow), the recognizer transitions to `.failed` and `onEnded`
    /// is never called.
    public func handleUIGestureRecognizerAction(_ recognizer: UISwipeGestureRecognizer,
                                                context: Context) {
        switch recognizer.state {
        case .ended:
            onEnded?(recognizer)
        default:
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
