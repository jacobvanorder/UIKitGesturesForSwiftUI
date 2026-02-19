//
//  MultiFingerPinchGesture.swift
//  UIKitGesturesForSwiftUI
//
//  Created by Jacob Van Order on 2/18/26.
//

import Foundation
import SwiftUI
import UIKit

/// A SwiftUI bridge for UIKit's `UIPinchGestureRecognizer`.
///
/// `MultiFingerPinchGesture` wraps `UIPinchGestureRecognizer` using the
/// `UIGestureRecognizerRepresentable` protocol, exposing UIKit's pinch gesture
/// directly within SwiftUI views.
///
/// ## Why use this instead of SwiftUI's `MagnifyGesture`?
///
/// SwiftUI's `MagnifyGesture` (formerly `MagnificationGesture`) provides a simplified
/// scale value but lacks access to the underlying `UIPinchGestureRecognizer`. Using
/// this bridge gives you:
/// - Direct access to `scale` and `velocity` on the recognizer
/// - The ability to reset `scale` to `1.0` for incremental (delta-based) scaling
/// - Full control over the gesture recognizer delegate for simultaneous recognition
/// - Consistent API patterns with the other gestures in this library
///
/// ## Pinch gesture basics
///
/// A pinch gesture requires exactly **two fingers**. Unlike `MultiFingerPanGesture`,
/// there are no configurable touch count properties — `UIPinchGestureRecognizer`
/// always requires two touches.
///
/// - **Pinch in** (fingers moving toward each other): `scale` decreases below `1.0`
/// - **Pinch out** (fingers moving apart): `scale` increases above `1.0`
///
/// ## Understanding `scale` vs. delta scaling
///
/// The `scale` property on `UIPinchGestureRecognizer` is an **absolute** value
/// relative to the initial finger distance when the gesture began. It is *not*
/// a delta from the last callback. This has an important implication:
///
/// ### Absolute scaling (apply `scale` to the original value)
///
/// Cache your content's original size when the gesture begins, then multiply
/// by `scale` on each change:
///
/// ```swift
/// @State private var currentScale: CGFloat = 1.0
/// @State private var baseScale: CGFloat = 1.0
///
/// Rectangle()
///     .scaleEffect(currentScale)
///     .gesture(
///         MultiFingerPinchGesture()
///             .onBegan { _ in
///                 baseScale = currentScale
///             }
///             .onChanged { recognizer in
///                 currentScale = baseScale * recognizer.scale
///             }
///     )
/// ```
///
/// ### Delta scaling (reset `scale` to `1.0` each time)
///
/// Alternatively, apply the scale as a multiplier and reset it to `1.0` after
/// each callback. This yields incremental changes suitable for `CGAffineTransform`:
///
/// ```swift
/// Rectangle()
///     .gesture(
///         MultiFingerPinchGesture()
///             .onChanged { recognizer in
///                 myView.transform = myView.transform.scaledBy(
///                     x: recognizer.scale,
///                     y: recognizer.scale
///                 )
///                 recognizer.scale = 1.0  // Reset for next delta
///             }
///     )
/// ```
///
/// > Important: If you multiply `scale` directly into an already-scaled value
/// > without caching or resetting, your content will grow or shrink **exponentially**
/// > rather than linearly. Always use one of the two patterns above.
///
/// ## Continuous gesture lifecycle
///
/// `UIPinchGestureRecognizer` is a **continuous** gesture recognizer, meaning it
/// transitions through multiple states and calls your action handlers many times:
///
/// 1. **Began** — The user placed two fingers on the screen and moved them enough
///    to be recognized as a pinch. At this point `scale` is close to `1.0`.
///    This is the ideal place to cache your content's original size.
///
/// 2. **Changed** — The user's fingers moved while both remain touching. The gesture
///    recognizer fires this state each time the distance between the fingers changes.
///    Read `scale` for the current pinch factor and `velocity` (in scale factor per
///    second) for the speed of the pinch.
///
/// 3. **Ended** — The user lifted one or both fingers. The pinch is complete. You can
///    still read `velocity` here for momentum-based zoom animations.
///
/// ## Usage
///
/// ```swift
/// @State private var zoom: CGFloat = 1.0
/// @State private var baseZoom: CGFloat = 1.0
///
/// Image("photo")
///     .scaleEffect(zoom)
///     .gesture(
///         MultiFingerPinchGesture()
///             .onBegan { _ in
///                 baseZoom = zoom
///             }
///             .onChanged { recognizer in
///                 zoom = baseZoom * recognizer.scale
///             }
///             .onEnded { recognizer in
///                 print("Pinch ended with velocity: \(recognizer.velocity)")
///             }
///     )
/// ```
public struct MultiFingerPinchGesture: UIGestureRecognizerRepresentable {

    // MARK: - Lifecycle Closures

    /// Called when the gesture transitions to the `.began` state.
    ///
    /// At this point two fingers have touched the screen and moved enough to be
    /// recognized as a pinch. The `scale` on the recognizer will be close to `1.0`.
    /// This is the ideal place to cache your content's original size or transform
    /// so you can apply the absolute scale factor in subsequent `onChanged` calls.
    private let onBegan: ((UIPinchGestureRecognizer) -> Void)?

    /// Called each time the gesture transitions to the `.changed` state.
    ///
    /// This fires whenever the distance between the two fingers changes. Read
    /// `recognizer.scale` for the current pinch factor (absolute, relative to the
    /// initial finger distance) and `recognizer.velocity` for the speed of the
    /// pinch in scale factor per second.
    ///
    /// > Tip: If you need delta-based scaling, reset `recognizer.scale = 1.0`
    /// > at the end of each `onChanged` call. See the class-level documentation
    /// > for a full example.
    private let onChanged: ((UIPinchGestureRecognizer) -> Void)?

    /// Called when the gesture transitions to the `.ended` state.
    ///
    /// This fires when the user lifts one or both fingers, completing the pinch.
    /// You can still read `recognizer.velocity` at this point — useful for driving
    /// momentum-based zoom animations that continue after the fingers lift.
    private let onEnded: ((UIPinchGestureRecognizer) -> Void)?

    /// An optional closure that determines whether this gesture recognizer should
    /// recognize simultaneously with another gesture recognizer.
    ///
    /// Return `true` to allow both gestures to proceed at the same time, or `false`
    /// to prevent simultaneous recognition. When `nil`, the default behavior is to
    /// allow simultaneous recognition (`true`).
    ///
    /// Pinch gestures are commonly combined with rotation gestures. If you attach
    /// both a `MultiFingerPinchGesture` and a `UIRotationGestureRecognizer` to
    /// the same view, allowing simultaneous recognition lets the user scale and
    /// rotate content in a single two-finger motion.
    private let shouldRecognizeSimultaneouslyWith: ((UIGestureRecognizer) -> Bool)?

    // MARK: - Initializer

    /// Creates a new `MultiFingerPinchGesture`.
    ///
    /// `UIPinchGestureRecognizer` has no configurable properties — it always requires
    /// exactly two fingers. The only configuration is the lifecycle closures and the
    /// simultaneous recognition policy.
    ///
    /// - Parameters:
    ///   - onBegan: Closure called when the pinch is first recognized. Defaults to `nil`.
    ///   - onChanged: Closure called each time the finger distance changes during the pinch.
    ///     Defaults to `nil`.
    ///   - onEnded: Closure called when the user lifts their fingers. Defaults to `nil`.
    ///   - shouldRecognizeSimultaneouslyWith: Closure to control simultaneous gesture
    ///     recognition. Defaults to `nil` (allows simultaneous recognition).
    public init(onBegan: ((UIPinchGestureRecognizer) -> Void)? = nil,
                onChanged: ((UIPinchGestureRecognizer) -> Void)? = nil,
                onEnded: ((UIPinchGestureRecognizer) -> Void)? = nil,
                shouldRecognizeSimultaneouslyWith: ((UIGestureRecognizer) -> Bool)? = nil) {
        self.onBegan = onBegan
        self.onChanged = onChanged
        self.onEnded = onEnded
        self.shouldRecognizeSimultaneouslyWith = shouldRecognizeSimultaneouslyWith
    }

    // MARK: - UIGestureRecognizerRepresentable

    /// Creates the underlying `UIPinchGestureRecognizer`.
    ///
    /// This method is called once by SwiftUI when the gesture is first attached to a view.
    /// Unlike other gesture recognizers in this library, `UIPinchGestureRecognizer` has
    /// no configurable properties — it always requires exactly two touches. The delegate
    /// is set to the coordinator for simultaneous recognition support.
    public func makeUIGestureRecognizer(context: Context) -> UIPinchGestureRecognizer {
        let pinchGesture = UIPinchGestureRecognizer()
        pinchGesture.delegate = context.coordinator
        return pinchGesture
    }

    // MARK: - Factory Methods (Builder Pattern)

    /// Returns a new gesture with the provided `onBegan` closure, preserving all
    /// other configuration.
    ///
    /// Use this to chain callbacks in a declarative style:
    /// ```swift
    /// MultiFingerPinchGesture()
    ///     .onBegan { recognizer in
    ///         // Cache the original size before scaling begins
    ///     }
    /// ```
    public func onBegan(_ action: @escaping (UIPinchGestureRecognizer) -> Void) -> MultiFingerPinchGesture {
        MultiFingerPinchGesture(onBegan: action,
                                onChanged: self.onChanged,
                                onEnded: self.onEnded,
                                shouldRecognizeSimultaneouslyWith: self.shouldRecognizeSimultaneouslyWith)
    }

    /// Returns a new gesture with the provided `onChanged` closure, preserving all
    /// other configuration.
    ///
    /// ```swift
    /// MultiFingerPinchGesture()
    ///     .onChanged { recognizer in
    ///         let scale = recognizer.scale
    ///         let velocity = recognizer.velocity
    ///         // Apply scale to your content
    ///     }
    /// ```
    public func onChanged(_ action: @escaping (UIPinchGestureRecognizer) -> Void) -> MultiFingerPinchGesture {
        MultiFingerPinchGesture(onBegan: self.onBegan,
                                onChanged: action,
                                onEnded: self.onEnded,
                                shouldRecognizeSimultaneouslyWith: self.shouldRecognizeSimultaneouslyWith)
    }

    /// Returns a new gesture with the provided `onEnded` closure, preserving all
    /// other configuration.
    ///
    /// ```swift
    /// MultiFingerPinchGesture()
    ///     .onEnded { recognizer in
    ///         let velocity = recognizer.velocity
    ///         // Use velocity for momentum-based zoom animation
    ///     }
    /// ```
    public func onEnded(_ action: @escaping (UIPinchGestureRecognizer) -> Void) -> MultiFingerPinchGesture {
        MultiFingerPinchGesture(onBegan: self.onBegan,
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
    public func handleUIGestureRecognizerAction(_ recognizer: UIPinchGestureRecognizer,
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

    /// The delegate object for the underlying `UIPinchGestureRecognizer`.
    ///
    /// This coordinator implements `UIGestureRecognizerDelegate` to control whether
    /// the pinch gesture can be recognized simultaneously with other gestures.
    /// By default (when no `shouldRecognizeSimultaneouslyWith` closure is provided),
    /// simultaneous recognition is allowed.
    ///
    /// Allowing simultaneous recognition is especially useful when combining pinch
    /// with rotation — the user can scale and rotate with the same two-finger gesture.
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
        ///   - gestureRecognizer: The pinch gesture recognizer owned by this struct.
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
