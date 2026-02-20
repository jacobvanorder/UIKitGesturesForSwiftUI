//
//  MultiFingerTransformGesture.swift
//  UIKitGesturesForSwiftUI
//
//  Created by Jacob Van Order on 2/19/26.
//

import Foundation
import SwiftUI
import UIKit

/// A SwiftUI bridge for the custom `TransformGestureRecognizer`.
///
/// `MultiFingerTransformGesture` wraps `TransformGestureRecognizer` using the
/// `UIGestureRecognizerRepresentable` protocol, exposing the combined two-finger
/// transform gesture (pinch + rotation + pan) directly within SwiftUI views.
///
/// ## Why use this instead of separate gestures?
///
/// When a user places two fingers on the screen and moves them, they typically
/// perform some combination of zooming, rotating, and panning — all at once.
/// You *could* attach three separate gestures (`MultiFingerPinchGesture`,
/// `MultiFingerRotationGesture`, `MultiFingerPanGesture`) to the same view and
/// configure them for simultaneous recognition, but this has drawbacks:
///
/// - **Three state machines**: Each gesture begins, changes, and ends
///   independently. You must coordinate them so your view doesn't jump when one
///   begins before the others.
/// - **Three delegates**: Each gesture needs `shouldRecognizeSimultaneouslyWith`
///   configuration to avoid conflicts.
/// - **Transform ordering**: Applying translation, scale, and rotation in the
///   wrong order produces incorrect results. With three separate callbacks, it's
///   easy to get wrong.
///
/// `MultiFingerTransformGesture` solves all of this. Because the underlying
/// `TransformGestureRecognizer` computes `scale`, `rotation`, and `translation`
/// from the *same pair of touches* in a *single callback*, the values are
/// always consistent, in sync, and applied together.
///
/// ## Comparison with separate gestures
///
/// | Approach | Gestures | Delegates | Callbacks per frame | Consistency |
/// |----------|----------|-----------|---------------------|-------------|
/// | Separate | 3 | 3 | Up to 3 | Must coordinate |
/// | Combined | 1 | 1 | 1 | Always in sync |
///
/// ## What the recognizer provides
///
/// The `TransformGestureRecognizer` passed to your closures exposes:
///
/// | Property | Type | Start value | Description |
/// |-----------|-----------|-------------|--------------------------------------|
/// | `scale` | `CGFloat` | `1.0` | Ratio of current to initial finger distance |
/// | `rotation` | `CGFloat` | `0.0` | Total rotation in radians since began |
/// | `translation` | `CGPoint` | `.zero` | Midpoint displacement since began |
/// | `scaleVelocity` | `CGFloat` | `0.0` | Scale change per second |
/// | `rotationVelocity` | `CGFloat` | `0.0` | Rotation change (rad/s) |
/// | `anchorPoint` | `CGPoint` | `.zero` | Current midpoint between fingers |
///
/// All values are **absolute** relative to the gesture's start — not deltas
/// from the last callback. See "Absolute vs. delta patterns" below.
///
/// ## Absolute vs. delta patterns
///
/// ### Absolute pattern (recommended for SwiftUI)
///
/// Cache your content's original transform when the gesture begins, then apply
/// the recognizer's absolute values on each change:
///
/// ```swift
/// @State private var currentScale: CGFloat = 1.0
/// @State private var currentAngle: Angle = .zero
/// @State private var currentOffset: CGSize = .zero
///
/// @State private var baseScale: CGFloat = 1.0
/// @State private var baseAngle: Angle = .zero
/// @State private var baseOffset: CGSize = .zero
///
/// Image("photo")
///     .scaleEffect(currentScale)
///     .rotationEffect(currentAngle)
///     .offset(currentOffset)
///     .gesture(
///         MultiFingerTransformGesture()
///             .onBegan { _ in
///                 baseScale = currentScale
///                 baseAngle = currentAngle
///                 baseOffset = currentOffset
///             }
///             .onChanged { recognizer in
///                 currentScale = baseScale * recognizer.scale
///                 currentAngle = baseAngle + .radians(recognizer.rotation)
///                 currentOffset = CGSize(
///                     width: baseOffset.width + recognizer.translation.x,
///                     height: baseOffset.height + recognizer.translation.y
///                 )
///             }
///     )
/// ```
///
/// ### Delta pattern (for CGAffineTransform)
///
/// Track previous values and compute per-frame deltas. This is useful when
/// building incremental `CGAffineTransform` chains:
///
/// ```swift
/// @State private var previousScale: CGFloat = 1.0
/// @State private var previousRotation: CGFloat = 0.0
/// @State private var previousTranslation: CGPoint = .zero
///
/// myView
///     .gesture(
///         MultiFingerTransformGesture()
///             .onBegan { _ in
///                 previousScale = 1.0
///                 previousRotation = 0.0
///                 previousTranslation = .zero
///             }
///             .onChanged { recognizer in
///                 let ds = recognizer.scale / previousScale
///                 let dr = recognizer.rotation - previousRotation
///                 let dt = CGPoint(
///                     x: recognizer.translation.x - previousTranslation.x,
///                     y: recognizer.translation.y - previousTranslation.y
///                 )
///
///                 // Apply incremental transform...
///
///                 previousScale = recognizer.scale
///                 previousRotation = recognizer.rotation
///                 previousTranslation = recognizer.translation
///             }
///     )
/// ```
///
/// > Important: Do not multiply `scale` directly into an already-scaled value,
/// > add `rotation` into an already-rotated value, or add `translation` into an
/// > already-translated value without caching or computing deltas. Doing so
/// > compounds the absolute values, producing exponential growth or runaway
/// > spinning. Always use one of the two patterns above.
///
/// ## Momentum animations
///
/// The recognizer provides `scaleVelocity` and `rotationVelocity` at the moment
/// the gesture ends. Use these to drive momentum-based animations:
///
/// ```swift
/// MultiFingerTransformGesture()
///     .onEnded { recognizer in
///         let spinVelocity = recognizer.rotationVelocity
///         let zoomVelocity = recognizer.scaleVelocity
///
///         // Drive a spring or decay animation using these velocities
///         withAnimation(.interpolatingSpring(stiffness: 100, damping: 15)) {
///             // Apply final momentum-based values
///         }
///     }
/// ```
///
/// ## Using the anchor point
///
/// The `anchorPoint` property returns the current midpoint between the user's
/// two fingers, in the coordinate space of the gesture's view. This is useful
/// for centering scale and rotation transforms around the user's fingers
/// rather than the view's center:
///
/// ```swift
/// MultiFingerTransformGesture()
///     .onChanged { recognizer in
///         let anchor = recognizer.anchorPoint
///         // Use anchor as the origin for your transform
///     }
/// ```
///
/// ## Continuous gesture lifecycle
///
/// `TransformGestureRecognizer` is a **continuous** gesture recognizer that
/// requires exactly **two fingers**. Its state machine is:
///
/// ```
/// .possible ──▶ .began ──▶ .changed (repeated) ──▶ .ended
///                  │                                    │
///                  ╰─────────▶ .cancelled ◀─────────────╯
/// ```
///
/// 1. **Began** — Two fingers have touched the screen and moved enough to
///    begin tracking. At this point `scale` is `1.0`, `rotation` is `0.0`,
///    and `translation` is `.zero`. This is the ideal place to cache your
///    content's original transform.
///
/// 2. **Changed** — Either finger moved. All output properties (`scale`,
///    `rotation`, `translation`, velocities, `anchorPoint`) are updated.
///    This fires many times per second while the fingers are moving.
///
/// 3. **Ended** — One or both fingers lifted from the screen. The gesture is
///    complete. You can still read the velocity properties here for momentum
///    animations.
///
/// ## Usage
///
/// ```swift
/// @State private var scale: CGFloat = 1.0
/// @State private var angle: Angle = .zero
/// @State private var offset: CGSize = .zero
///
/// @State private var baseScale: CGFloat = 1.0
/// @State private var baseAngle: Angle = .zero
/// @State private var baseOffset: CGSize = .zero
///
/// Image("map")
///     .scaleEffect(scale)
///     .rotationEffect(angle)
///     .offset(offset)
///     .gesture(
///         MultiFingerTransformGesture()
///             .onBegan { _ in
///                 baseScale = scale
///                 baseAngle = angle
///                 baseOffset = offset
///             }
///             .onChanged { recognizer in
///                 scale = baseScale * recognizer.scale
///                 angle = baseAngle + .radians(recognizer.rotation)
///                 offset = CGSize(
///                     width: baseOffset.width + recognizer.translation.x,
///                     height: baseOffset.height + recognizer.translation.y
///                 )
///             }
///             .onEnded { recognizer in
///                 print("Final scale velocity: \(recognizer.scaleVelocity)")
///                 print("Final rotation velocity: \(recognizer.rotationVelocity)")
///             }
///     )
/// ```
public struct MultiFingerTransformGesture: UIGestureRecognizerRepresentable {

    // MARK: - Lifecycle Closures

    /// Called when the gesture transitions to the `.began` state.
    ///
    /// At this point two fingers have touched the screen and moved enough to
    /// begin tracking. The recognizer's output properties are at their initial
    /// values: `scale` is `1.0`, `rotation` is `0.0`, and `translation` is
    /// `.zero`.
    ///
    /// This is the ideal place to cache your content's original transform so
    /// you can apply the absolute values in subsequent `onChanged` calls:
    ///
    /// ```swift
    /// .onBegan { _ in
    ///     baseScale = currentScale
    ///     baseAngle = currentAngle
    ///     baseOffset = currentOffset
    /// }
    /// ```
    private let onBegan: ((TransformGestureRecognizer) -> Void)?

    /// Called each time the gesture transitions to the `.changed` state.
    ///
    /// This fires whenever either of the two tracked fingers moves. All output
    /// properties on the recognizer are updated before this closure is called:
    ///
    /// - `scale`: Current pinch factor (ratio of current to initial finger distance)
    /// - `rotation`: Total rotation in radians since the gesture began
    /// - `translation`: Midpoint displacement since the gesture began
    /// - `scaleVelocity`: Rate of change of scale (scale-factor per second)
    /// - `rotationVelocity`: Rate of change of rotation (radians per second)
    /// - `anchorPoint`: Current midpoint between the two fingers
    ///
    /// ```swift
    /// .onChanged { recognizer in
    ///     currentScale = baseScale * recognizer.scale
    ///     currentAngle = baseAngle + .radians(recognizer.rotation)
    ///     currentOffset = CGSize(
    ///         width: baseOffset.width + recognizer.translation.x,
    ///         height: baseOffset.height + recognizer.translation.y
    ///     )
    /// }
    /// ```
    private let onChanged: ((TransformGestureRecognizer) -> Void)?

    /// Called when the gesture transitions to the `.ended` state.
    ///
    /// This fires when the user lifts one or both fingers, completing the
    /// transform gesture. You can still read `scaleVelocity` and
    /// `rotationVelocity` at this point — useful for driving momentum-based
    /// animations that continue after the fingers lift.
    ///
    /// ```swift
    /// .onEnded { recognizer in
    ///     let spinSpeed = recognizer.rotationVelocity  // rad/s
    ///     let zoomSpeed = recognizer.scaleVelocity     // scale/s
    ///     // Start momentum animation
    /// }
    /// ```
    private let onEnded: ((TransformGestureRecognizer) -> Void)?

    // MARK: - Delegate Closures

    /// An optional closure that determines whether the gesture recognizer should begin
    /// interpreting touches. When `nil`, defaults to `true`.
    private let shouldBegin: ((UIGestureRecognizer) -> Bool)?

    /// An optional closure that determines whether this gesture recognizer should
    /// recognize simultaneously with another gesture recognizer.
    ///
    /// Return `true` to allow both gestures to proceed at the same time, or `false`
    /// to prevent simultaneous recognition. When `nil`, the default behavior is to
    /// allow simultaneous recognition (`true`).
    ///
    /// Because `TransformGestureRecognizer` already combines pinch, rotation, and
    /// pan into a single gesture, you typically don't need to combine it with
    /// other two-finger gestures. However, you might want to combine it with
    /// single-finger gestures (taps, long presses) or discrete gestures (swipes).
    private let shouldRecognizeSimultaneouslyWith: ((UIGestureRecognizer) -> Bool)?

    /// An optional closure that determines whether the gesture recognizer should
    /// receive a given touch. When `nil`, defaults to `true`.
    private let shouldReceiveTouch: ((UIGestureRecognizer, UITouch) -> Bool)?

    /// An optional closure that determines whether the gesture recognizer should
    /// receive a given press. When `nil`, defaults to `true`.
    private let shouldReceivePress: ((UIGestureRecognizer, UIPress) -> Bool)?

    /// An optional closure that determines whether the gesture recognizer should
    /// receive a given event. When `nil`, defaults to `true`.
    private let shouldReceiveEvent: ((UIGestureRecognizer, UIEvent) -> Bool)?

    /// An optional closure that determines whether this gesture recognizer should
    /// require the other gesture recognizer to fail before it can begin.
    /// When `nil`, defaults to `false`.
    private let shouldRequireFailureOf: ((UIGestureRecognizer) -> Bool)?

    /// An optional closure that determines whether this gesture recognizer should
    /// be required to fail by the other gesture recognizer.
    /// When `nil`, defaults to `false`.
    private let shouldBeRequiredToFailBy: ((UIGestureRecognizer) -> Bool)?

    // MARK: - Initializer

    /// Creates a new `MultiFingerTransformGesture`.
    ///
    /// `TransformGestureRecognizer` has no configurable properties — it always
    /// requires exactly two fingers and tracks all three transform components
    /// (scale, rotation, translation) simultaneously. The only configuration is
    /// the lifecycle closures and the delegate closures.
    ///
    /// - Parameters:
    ///   - onBegan: Closure called when the transform is first recognized. Defaults to `nil`.
    ///   - onChanged: Closure called each time either finger moves during the transform.
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
    public init(onBegan: ((TransformGestureRecognizer) -> Void)? = nil,
                onChanged: ((TransformGestureRecognizer) -> Void)? = nil,
                onEnded: ((TransformGestureRecognizer) -> Void)? = nil,
                shouldBegin: ((UIGestureRecognizer) -> Bool)? = nil,
                shouldRecognizeSimultaneouslyWith: ((UIGestureRecognizer) -> Bool)? = nil,
                shouldReceiveTouch: ((UIGestureRecognizer, UITouch) -> Bool)? = nil,
                shouldReceivePress: ((UIGestureRecognizer, UIPress) -> Bool)? = nil,
                shouldReceiveEvent: ((UIGestureRecognizer, UIEvent) -> Bool)? = nil,
                shouldRequireFailureOf: ((UIGestureRecognizer) -> Bool)? = nil,
                shouldBeRequiredToFailBy: ((UIGestureRecognizer) -> Bool)? = nil) {
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

    /// Creates the underlying `TransformGestureRecognizer`.
    ///
    /// This method is called once by SwiftUI when the gesture is first attached to a view.
    /// `TransformGestureRecognizer` has no configurable properties — it always requires
    /// exactly two touches and tracks scale, rotation, and translation simultaneously.
    /// The delegate is set to the coordinator for simultaneous recognition support.
    public func makeUIGestureRecognizer(context: Context) -> TransformGestureRecognizer {
        let transformGesture = TransformGestureRecognizer()
        transformGesture.delegate = context.coordinator
        return transformGesture
    }

    // MARK: - Factory Methods (Builder Pattern)

    /// Returns a new gesture with the provided `onBegan` closure, preserving all
    /// other configuration.
    ///
    /// Use this to chain callbacks in a declarative style:
    /// ```swift
    /// MultiFingerTransformGesture()
    ///     .onBegan { recognizer in
    ///         // Cache original transform values before the gesture begins
    ///     }
    /// ```
    public func onBegan(_ action: @escaping (TransformGestureRecognizer) -> Void) -> MultiFingerTransformGesture {
        MultiFingerTransformGesture(onBegan: action,
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
    /// MultiFingerTransformGesture()
    ///     .onChanged { recognizer in
    ///         let scale = recognizer.scale
    ///         let rotation = recognizer.rotation
    ///         let translation = recognizer.translation
    ///         // Apply combined transform to your content
    ///     }
    /// ```
    public func onChanged(_ action: @escaping (TransformGestureRecognizer) -> Void) -> MultiFingerTransformGesture {
        MultiFingerTransformGesture(onBegan: self.onBegan,
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
    /// MultiFingerTransformGesture()
    ///     .onEnded { recognizer in
    ///         let scaleVelocity = recognizer.scaleVelocity
    ///         let rotationVelocity = recognizer.rotationVelocity
    ///         // Use velocities for momentum-based animation
    ///     }
    /// ```
    public func onEnded(_ action: @escaping (TransformGestureRecognizer) -> Void) -> MultiFingerTransformGesture {
        MultiFingerTransformGesture(onBegan: self.onBegan,
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
    /// ```
    ///
    /// Only `.began`, `.changed`, and `.ended` are forwarded to the closures.
    /// The `.cancelled` and `.failed` states are intentionally not exposed because
    /// they indicate the gesture was interrupted or never fully recognized.
    public func handleUIGestureRecognizerAction(_ recognizer: TransformGestureRecognizer,
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
