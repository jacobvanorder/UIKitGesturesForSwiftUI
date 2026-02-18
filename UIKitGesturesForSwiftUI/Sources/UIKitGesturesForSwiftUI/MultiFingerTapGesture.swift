//
//  MultiFingerTapGesture.swift
//  UIKitGesturesForSwiftUI
//
//  Created by Jacob Van Order on 2/18/26.
//

import Foundation
import SwiftUI
import UIKit

/// A SwiftUI bridge for UIKit's `UITapGestureRecognizer`.
///
/// `MultiFingerTapGesture` wraps `UITapGestureRecognizer` using the
/// `UIGestureRecognizerRepresentable` protocol, exposing UIKit's tap gesture
/// configuration directly within SwiftUI views.
///
/// ## Why use this instead of SwiftUI's `TapGesture` or `.onTapGesture`?
///
/// SwiftUI's built-in tap gesture supports a tap count but not a finger count.
/// `UITapGestureRecognizer` provides control over:
/// - The number of taps required (`numberOfTapsRequired`)
/// - The number of fingers required (`numberOfTouchesRequired`)
///
/// This makes it possible to implement multi-finger taps (e.g., two-finger double-tap)
/// that SwiftUI cannot express natively.
///
/// ## Discrete gesture lifecycle
///
/// `UITapGestureRecognizer` is a **discrete** gesture recognizer. Unlike continuous
/// gestures (pan, long press), a discrete recognizer calls your action method exactly
/// once after the gesture is fully recognized. There is no `.began` or `.changed` phase —
/// only `.ended`, which fires when all required taps with the required number of fingers
/// have been completed.
///
/// ## Usage
///
/// ```swift
/// Rectangle()
///     .fill(.blue)
///     .gesture(
///         MultiFingerTapGesture(
///             numberOfTapsRequired: 2,
///             numberOfTouchesRequired: 2
///         )
///         .onEnded { recognizer in
///             let location = recognizer.location(in: recognizer.view)
///             print("Two-finger double tap at: \(location)")
///         }
///     )
/// ```
public struct MultiFingerTapGesture: UIGestureRecognizerRepresentable {

    // MARK: - Configuration Properties

    /// The number of taps required for the gesture to be recognized.
    ///
    /// For example, setting this to `2` requires a double-tap. The default value is `1`.
    /// This maps directly to `UITapGestureRecognizer.numberOfTapsRequired`.
    public let numberOfTapsRequired: Int

    /// The number of fingers that must simultaneously touch the view for the gesture
    /// to be recognized.
    ///
    /// For example, setting this to `2` requires a two-finger tap. The default value
    /// is `1`. This maps directly to `UITapGestureRecognizer.numberOfTouchesRequired`.
    public let numberOfTouchesRequired: Int

    // MARK: - Lifecycle Closures

    /// Called when the gesture transitions to the `.ended` state.
    ///
    /// Because `UITapGestureRecognizer` is a discrete gesture, this is the only
    /// lifecycle callback. It fires once when all required taps with the required
    /// number of fingers have been completed. The recognizer is passed so you can
    /// query `location(in:)` or `location(ofTouch:in:)`.
    private let onEnded: ((UITapGestureRecognizer) -> Void)?

    /// An optional closure that determines whether this gesture recognizer should
    /// recognize simultaneously with another gesture recognizer.
    ///
    /// Return `true` to allow both gestures to proceed at the same time, or `false`
    /// to prevent simultaneous recognition. When `nil`, the default behavior is to
    /// allow simultaneous recognition (`true`).
    private let shouldRecognizeSimultaneouslyWith: ((UIGestureRecognizer) -> Bool)?

    // MARK: - Initializer

    /// Creates a new `MultiFingerTapGesture` with the specified configuration.
    ///
    /// - Parameters:
    ///   - numberOfTapsRequired: The number of taps required. Defaults to `1`.
    ///   - numberOfTouchesRequired: The number of fingers required. Defaults to `1`.
    ///   - onEnded: Closure called when the tap is recognized. Defaults to `nil`.
    ///   - shouldRecognizeSimultaneouslyWith: Closure to control simultaneous gesture
    ///     recognition. Defaults to `nil` (allows simultaneous recognition).
    public init(numberOfTapsRequired: Int = 1,
                numberOfTouchesRequired: Int = 1,
                onEnded: ((UITapGestureRecognizer) -> Void)? = nil,
                shouldRecognizeSimultaneouslyWith: ((UIGestureRecognizer) -> Bool)? = nil) {
        self.numberOfTapsRequired = numberOfTapsRequired
        self.numberOfTouchesRequired = numberOfTouchesRequired
        self.onEnded = onEnded
        self.shouldRecognizeSimultaneouslyWith = shouldRecognizeSimultaneouslyWith
    }

    // MARK: - UIGestureRecognizerRepresentable

    /// Creates and configures the underlying `UITapGestureRecognizer`.
    ///
    /// This method is called once by SwiftUI when the gesture is first attached to a view.
    /// The recognizer is configured with the tap and touch counts provided at initialization,
    /// and its delegate is set to the coordinator for simultaneous recognition support.
    public func makeUIGestureRecognizer(context: Context) -> UITapGestureRecognizer {
        let tapGesture = UITapGestureRecognizer()
        tapGesture.numberOfTouchesRequired = numberOfTouchesRequired
        tapGesture.numberOfTapsRequired = numberOfTapsRequired
        tapGesture.delegate = context.coordinator
        return tapGesture
    }

    /// Updates the gesture recognizer when SwiftUI re-evaluates the view.
    ///
    /// If the configuration values change (e.g., the tap count is driven by state),
    /// the existing recognizer is updated in place rather than recreated.
    public func updateUIGestureRecognizer(_ recognizer: UITapGestureRecognizer, context: Context) {
        recognizer.numberOfTapsRequired = self.numberOfTapsRequired
        recognizer.numberOfTouchesRequired = self.numberOfTouchesRequired
    }

    // MARK: - Factory Methods (Builder Pattern)

    /// Returns a new gesture with the provided `onEnded` closure, preserving all
    /// other configuration.
    ///
    /// Use this to chain the callback in a declarative style:
    /// ```swift
    /// MultiFingerTapGesture(numberOfTapsRequired: 2, numberOfTouchesRequired: 2)
    ///     .onEnded { recognizer in
    ///         // Handle the tap
    ///     }
    /// ```
    public func onEnded(_ action: @escaping (UITapGestureRecognizer) -> Void) -> MultiFingerTapGesture {
        MultiFingerTapGesture(numberOfTapsRequired: self.numberOfTapsRequired,
                              numberOfTouchesRequired: self.numberOfTouchesRequired,
                              onEnded: action,
                              shouldRecognizeSimultaneouslyWith: self.shouldRecognizeSimultaneouslyWith)
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
    public func handleUIGestureRecognizerAction(_ recognizer: UITapGestureRecognizer,
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
    /// The coordinator handles the `UIGestureRecognizerDelegate` method for
    /// simultaneous recognition, forwarding the decision to the
    /// `shouldRecognizeSimultaneouslyWith` closure if one was provided.
    public func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator(shouldRecognizeSimultaneouslyWith: shouldRecognizeSimultaneouslyWith)
    }

    /// The delegate object for the underlying `UITapGestureRecognizer`.
    ///
    /// This coordinator implements `UIGestureRecognizerDelegate` to control whether
    /// the tap gesture can be recognized simultaneously with other gestures.
    /// By default (when no `shouldRecognizeSimultaneouslyWith` closure is provided),
    /// simultaneous recognition is allowed.
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
        ///   - gestureRecognizer: The tap gesture recognizer owned by this struct.
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
