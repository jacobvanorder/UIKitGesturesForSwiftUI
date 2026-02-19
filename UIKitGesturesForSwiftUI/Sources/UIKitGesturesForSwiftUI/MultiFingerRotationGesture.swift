//
//  MultiFingerRotationGesture.swift
//  UIKitGesturesForSwiftUI
//
//  Created by Jacob Van Order on 2/19/26.
//

import Foundation
import SwiftUI
import UIKit

/// A SwiftUI bridge for UIKit's `UIRotationGestureRecognizer`.
///
/// `MultiFingerRotationGesture` wraps `UIRotationGestureRecognizer` using the
/// `UIGestureRecognizerRepresentable` protocol, exposing UIKit's rotation gesture
/// directly within SwiftUI views.
///
/// ## Why use this instead of SwiftUI's `RotateGesture`?
///
/// SwiftUI's `RotateGesture` (formerly `RotationGesture`) provides a simplified
/// angle value but lacks access to the underlying `UIRotationGestureRecognizer`.
/// Using this bridge gives you:
/// - Direct access to `rotation` (in radians) and `velocity` (radians/sec) on
///   the recognizer
/// - The ability to reset `rotation` to `0.0` for incremental (delta-based) rotation
/// - Full control over the gesture recognizer delegate for simultaneous recognition
/// - Consistent API patterns with the other gestures in this library
///
/// ## Rotation gesture basics
///
/// A rotation gesture requires exactly **two fingers**. Like `MultiFingerPinchGesture`,
/// there are no configurable touch count properties — `UIRotationGestureRecognizer`
/// always requires two touches.
///
/// The recognizer measures the angle between an imaginary line connecting the user's
/// two fingers at the start of the gesture and the line at the current position:
/// - **Positive values**: counter-clockwise rotation
/// - **Negative values**: clockwise rotation
/// - Values are in **radians** (multiply by `180 / .pi` for degrees)
///
/// ## Understanding `rotation` vs. delta rotation
///
/// The `rotation` property on `UIRotationGestureRecognizer` is an **absolute** value
/// relative to the initial finger orientation when the gesture began. It is *not*
/// a delta from the last callback. This has an important implication:
///
/// ### Absolute rotation (apply `rotation` to the original angle)
///
/// Cache your content's original angle when the gesture begins, then add
/// `rotation` on each change:
///
/// ```swift
/// @State private var currentAngle: Angle = .zero
/// @State private var baseAngle: Angle = .zero
///
/// Rectangle()
///     .rotationEffect(currentAngle)
///     .gesture(
///         MultiFingerRotationGesture()
///             .onBegan { _ in
///                 baseAngle = currentAngle
///             }
///             .onChanged { recognizer in
///                 currentAngle = baseAngle + .radians(recognizer.rotation)
///             }
///     )
/// ```
///
/// ### Delta rotation (reset `rotation` to `0.0` each time)
///
/// Alternatively, apply the rotation as an incremental transform and reset it to
/// `0.0` after each callback. This yields incremental changes suitable for
/// `CGAffineTransform`:
///
/// ```swift
/// Rectangle()
///     .gesture(
///         MultiFingerRotationGesture()
///             .onChanged { recognizer in
///                 myView.transform = myView.transform.rotated(
///                     by: recognizer.rotation
///                 )
///                 recognizer.rotation = 0  // Reset for next delta
///             }
///     )
/// ```
///
/// > Important: If you add `rotation` directly to an already-rotated value without
/// > caching or resetting, your content will spin **faster than expected** because
/// > each callback compounds the previous rotation. Always use one of the two
/// > patterns above.
///
/// ## Combining with pinch gestures
///
/// Rotation and pinch gestures are commonly used together to let the user scale
/// and rotate content in a single two-finger motion. Because both use exactly two
/// fingers, they can run simultaneously when the delegate allows it (the default
/// behavior of this library). Simply attach both gestures to the same view:
///
/// ```swift
/// Image("photo")
///     .gesture(
///         MultiFingerPinchGesture()
///             .onChanged { recognizer in
///                 // Handle scaling
///             }
///     )
///     .gesture(
///         MultiFingerRotationGesture()
///             .onChanged { recognizer in
///                 // Handle rotation
///             }
///     )
/// ```
///
/// ## Continuous gesture lifecycle
///
/// `UIRotationGestureRecognizer` is a **continuous** gesture recognizer, meaning it
/// transitions through multiple states and calls your action handlers many times:
///
/// 1. **Began** — The user placed two fingers on the screen and rotated them enough
///    to be recognized. At this point `rotation` is close to `0.0` radians.
///    This is the ideal place to cache your content's original angle.
///
/// 2. **Changed** — The user's fingers rotated while both remain touching. The gesture
///    recognizer fires this state each time the angle between the fingers changes.
///    Read `rotation` for the current angle (in radians) and `velocity` for the
///    rotational speed (in radians per second).
///
/// 3. **Ended** — The user lifted one or both fingers. The rotation is complete. You can
///    still read `velocity` here for momentum-based spin animations.
///
/// ## Usage
///
/// ```swift
/// @State private var angle: Angle = .zero
/// @State private var baseAngle: Angle = .zero
///
/// Image("compass")
///     .rotationEffect(angle)
///     .gesture(
///         MultiFingerRotationGesture()
///             .onBegan { _ in
///                 baseAngle = angle
///             }
///             .onChanged { recognizer in
///                 angle = baseAngle + .radians(recognizer.rotation)
///             }
///             .onEnded { recognizer in
///                 print("Rotation ended with velocity: \(recognizer.velocity) rad/s")
///             }
///     )
/// ```
public struct MultiFingerRotationGesture: UIGestureRecognizerRepresentable {

    // MARK: - Lifecycle Closures

    /// Called when the gesture transitions to the `.began` state.
    ///
    /// At this point two fingers have touched the screen and rotated enough to be
    /// recognized as a rotation. The `rotation` on the recognizer will be close to
    /// `0.0` radians. This is the ideal place to cache your content's original angle
    /// so you can apply the absolute rotation in subsequent `onChanged` calls.
    private let onBegan: ((UIRotationGestureRecognizer) -> Void)?

    /// Called each time the gesture transitions to the `.changed` state.
    ///
    /// This fires whenever the angle between the two fingers changes. Read
    /// `recognizer.rotation` for the current rotation angle in radians (absolute,
    /// relative to the initial finger orientation) and `recognizer.velocity` for
    /// the rotational speed in radians per second.
    ///
    /// > Tip: If you need delta-based rotation, reset `recognizer.rotation = 0`
    /// > at the end of each `onChanged` call. See the struct-level documentation
    /// > for a full example.
    private let onChanged: ((UIRotationGestureRecognizer) -> Void)?

    /// Called when the gesture transitions to the `.ended` state.
    ///
    /// This fires when the user lifts one or both fingers, completing the rotation.
    /// You can still read `recognizer.velocity` at this point — useful for driving
    /// momentum-based spin animations that continue after the fingers lift.
    private let onEnded: ((UIRotationGestureRecognizer) -> Void)?

    /// An optional closure that determines whether this gesture recognizer should
    /// recognize simultaneously with another gesture recognizer.
    ///
    /// Return `true` to allow both gestures to proceed at the same time, or `false`
    /// to prevent simultaneous recognition. When `nil`, the default behavior is to
    /// allow simultaneous recognition (`true`).
    ///
    /// Rotation gestures are commonly combined with pinch gestures. If you attach
    /// both a `MultiFingerRotationGesture` and a `MultiFingerPinchGesture` to the
    /// same view, allowing simultaneous recognition lets the user rotate and scale
    /// content in a single two-finger motion.
    private let shouldRecognizeSimultaneouslyWith: ((UIGestureRecognizer) -> Bool)?

    // MARK: - Initializer

    /// Creates a new `MultiFingerRotationGesture`.
    ///
    /// `UIRotationGestureRecognizer` has no configurable properties — it always requires
    /// exactly two fingers. The only configuration is the lifecycle closures and the
    /// simultaneous recognition policy.
    ///
    /// - Parameters:
    ///   - onBegan: Closure called when the rotation is first recognized. Defaults to `nil`.
    ///   - onChanged: Closure called each time the finger angle changes during the rotation.
    ///     Defaults to `nil`.
    ///   - onEnded: Closure called when the user lifts their fingers. Defaults to `nil`.
    ///   - shouldRecognizeSimultaneouslyWith: Closure to control simultaneous gesture
    ///     recognition. Defaults to `nil` (allows simultaneous recognition).
    public init(onBegan: ((UIRotationGestureRecognizer) -> Void)? = nil,
                onChanged: ((UIRotationGestureRecognizer) -> Void)? = nil,
                onEnded: ((UIRotationGestureRecognizer) -> Void)? = nil,
                shouldRecognizeSimultaneouslyWith: ((UIGestureRecognizer) -> Bool)? = nil) {
        self.onBegan = onBegan
        self.onChanged = onChanged
        self.onEnded = onEnded
        self.shouldRecognizeSimultaneouslyWith = shouldRecognizeSimultaneouslyWith
    }

    // MARK: - UIGestureRecognizerRepresentable

    /// Creates the underlying `UIRotationGestureRecognizer`.
    ///
    /// This method is called once by SwiftUI when the gesture is first attached to a view.
    /// Like `UIPinchGestureRecognizer`, `UIRotationGestureRecognizer` has no configurable
    /// properties — it always requires exactly two touches. The delegate is set to the
    /// coordinator for simultaneous recognition support.
    public func makeUIGestureRecognizer(context: Context) -> UIRotationGestureRecognizer {
        let rotationGesture = UIRotationGestureRecognizer()
        rotationGesture.delegate = context.coordinator
        return rotationGesture
    }

    // MARK: - Factory Methods (Builder Pattern)

    /// Returns a new gesture with the provided `onBegan` closure, preserving all
    /// other configuration.
    ///
    /// Use this to chain callbacks in a declarative style:
    /// ```swift
    /// MultiFingerRotationGesture()
    ///     .onBegan { recognizer in
    ///         // Cache the original angle before rotation begins
    ///     }
    /// ```
    public func onBegan(_ action: @escaping (UIRotationGestureRecognizer) -> Void) -> MultiFingerRotationGesture {
        MultiFingerRotationGesture(onBegan: action,
                                   onChanged: self.onChanged,
                                   onEnded: self.onEnded,
                                   shouldRecognizeSimultaneouslyWith: self.shouldRecognizeSimultaneouslyWith)
    }

    /// Returns a new gesture with the provided `onChanged` closure, preserving all
    /// other configuration.
    ///
    /// ```swift
    /// MultiFingerRotationGesture()
    ///     .onChanged { recognizer in
    ///         let radians = recognizer.rotation
    ///         let velocity = recognizer.velocity
    ///         // Apply rotation to your content
    ///     }
    /// ```
    public func onChanged(_ action: @escaping (UIRotationGestureRecognizer) -> Void) -> MultiFingerRotationGesture {
        MultiFingerRotationGesture(onBegan: self.onBegan,
                                   onChanged: action,
                                   onEnded: self.onEnded,
                                   shouldRecognizeSimultaneouslyWith: self.shouldRecognizeSimultaneouslyWith)
    }

    /// Returns a new gesture with the provided `onEnded` closure, preserving all
    /// other configuration.
    ///
    /// ```swift
    /// MultiFingerRotationGesture()
    ///     .onEnded { recognizer in
    ///         let velocity = recognizer.velocity
    ///         // Use velocity for momentum-based spin animation
    ///     }
    /// ```
    public func onEnded(_ action: @escaping (UIRotationGestureRecognizer) -> Void) -> MultiFingerRotationGesture {
        MultiFingerRotationGesture(onBegan: self.onBegan,
                                   onChanged: self.onChanged,
                                   onEnded: action,
                                   shouldRecognizeSimultaneouslyWith: self.shouldRecognizeSimultaneouslyWith)
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
    public func handleUIGestureRecognizerAction(_ recognizer: UIRotationGestureRecognizer,
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
    /// The coordinator handles the `UIGestureRecognizerDelegate` method for
    /// simultaneous recognition, forwarding the decision to the
    /// `shouldRecognizeSimultaneouslyWith` closure if one was provided.
    public func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator(shouldRecognizeSimultaneouslyWith: shouldRecognizeSimultaneouslyWith)
    }

    /// The delegate object for the underlying `UIRotationGestureRecognizer`.
    ///
    /// This coordinator implements `UIGestureRecognizerDelegate` to control whether
    /// the rotation gesture can be recognized simultaneously with other gestures.
    /// By default (when no `shouldRecognizeSimultaneouslyWith` closure is provided),
    /// simultaneous recognition is allowed.
    ///
    /// Allowing simultaneous recognition is especially useful when combining rotation
    /// with pinch — the user can rotate and scale with the same two-finger gesture.
    public class Coordinator: NSObject, UIGestureRecognizerDelegate {

        /// The closure used to decide simultaneous recognition.
        /// When `nil`, simultaneous recognition defaults to `true`.
        let shouldRecognizeSimultaneouslyWith: ((UIGestureRecognizer) -> Bool)?

        internal init(shouldRecognizeSimultaneouslyWith: ((UIGestureRecognizer) -> Bool)? = nil) {
            self.shouldRecognizeSimultaneouslyWith = shouldRecognizeSimultaneouslyWith
        }

        /// Called by UIKit to ask whether this gesture recognizer should recognize
        /// simultaneously with another.
        ///
        /// - Parameters:
        ///   - gestureRecognizer: The rotation gesture recognizer owned by this struct.
        ///   - otherGestureRecognizer: Another gesture recognizer that wants to recognize
        ///     at the same time.
        /// - Returns: `true` if both gestures should proceed simultaneously, `false` otherwise.
        ///   Defaults to `true` when no custom closure is provided.
        public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                                      shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return self.shouldRecognizeSimultaneouslyWith?(otherGestureRecognizer) ?? true
        }
    }
}
