//
//  TransformGestureRecognizer.swift
//  UIKitGesturesForSwiftUI
//
//  Created by Jacob Van Order on 2/19/26.
//

import UIKit
import UIKit.UIGestureRecognizerSubclass

/// A custom **continuous** gesture recognizer that simultaneously tracks
/// pinch (scale), rotation, and two-finger translation in a single gesture.
///
/// ## Why a single combined gesture?
///
/// When a user places two fingers on the screen and moves them, they are typically
/// performing some combination of zooming, rotating, and panning — all at the same
/// time. UIKit provides separate recognizers for each (`UIPinchGestureRecognizer`,
/// `UIRotationGestureRecognizer`, `UIPanGestureRecognizer`), but using three
/// simultaneous recognizers has drawbacks:
///
/// - You must coordinate three delegate callbacks and three state machines
/// - Each recognizer competes for the same touches, requiring careful
///   `shouldRecognizeSimultaneouslyWith` configuration
/// - Applying the three transforms in the correct order is error-prone
///
/// `TransformGestureRecognizer` solves this by computing all three values from
/// the same pair of touches in a single callback, guaranteeing they are always
/// consistent and in sync.
///
/// ## The math: how two touches encode three transforms
///
/// Given two touch points **P1** and **P2**, a 2D affine transform can be fully
/// described. Think of the two fingers as defining a "coordinate frame" — the
/// line segment from P1 to P2 has a midpoint (position), a length (scale),
/// and an angle (rotation).
///
/// ### Midpoint (centroid)
///
/// The midpoint of the two touches represents the center of the gesture. Its
/// movement over time gives us the **translation**:
///
/// ```
///                P1 ●━━━━━━━● P2
///                       ┃
///                  midpoint M
///
///     M = ( (P1.x + P2.x) / 2,  (P1.y + P2.y) / 2 )
///
///     translation = M_current − M_initial
/// ```
///
/// ### Distance (Euclidean norm)
///
/// The distance between the two touches at the start vs. now gives us the
/// **scale factor**:
///
/// ```
///     d = √( (P2.x − P1.x)² + (P2.y − P1.y)² )
///
///     scale = d_current / d_initial
/// ```
///
/// A scale of `1.0` means no change. Values > 1 mean the fingers moved apart
/// (zoom in); values < 1 mean they moved together (zoom out).
///
/// ### Angle (atan2)
///
/// The angle of the line from P1 to P2 gives us the **rotation**. We use
/// `atan2` because it correctly handles all four quadrants:
///
/// ```
///     θ = atan2(P2.y − P1.y, P2.x − P1.x)
///
///     rotation = θ_current − θ_initial   (accumulated, in radians)
/// ```
///
/// #### Handling the `atan2` discontinuity
///
/// `atan2` returns values in the range `[-π, +π]`. If the user rotates their
/// fingers past the ±π boundary, the raw angle jumps by 2π. To avoid a sudden
/// rotation spike, we accumulate rotation **frame by frame** using small deltas:
///
/// ```
///     delta = normalize(θ_current − θ_previous)    // clamp to [-π, +π]
///     rotation += delta
///     θ_previous = θ_current
/// ```
///
/// Because two touches can't rotate more than ~π radians between consecutive
/// frames (at 60+ fps that would require superhuman speed), normalizing the
/// per-frame delta is always safe. This allows `rotation` to exceed ±π when
/// the user makes multiple full turns.
///
/// ## Continuous gesture lifecycle
///
/// Like `UIPinchGestureRecognizer` and `UIRotationGestureRecognizer`, this is
/// a **continuous** gesture recognizer. Its state machine is:
///
/// ```
/// .possible ──▶ .began ──▶ .changed (repeated) ──▶ .ended
///                  │                                    │
///                  ╰─────────▶ .cancelled ◀─────────────╯
/// ```
///
/// - **Possible**: Waiting for two fingers to touch the screen.
/// - **Began**: Two fingers have touched and moved enough to begin tracking.
///   `scale` is `1.0`, `rotation` is `0.0`, and `translation` is `.zero`.
/// - **Changed**: Either finger moved. All output values are updated.
/// - **Ended**: One or both fingers lifted from the screen.
/// - **Cancelled**: A system event (e.g., phone call) interrupted the gesture.
///
/// ## Velocities
///
/// The recognizer computes frame-to-frame velocities for scale and rotation:
/// - `scaleVelocity`: Change in scale factor per second.
/// - `rotationVelocity`: Change in rotation (radians) per second.
///
/// These are useful for driving momentum-based animations after the gesture ends.
///
/// ## Absolute values (not deltas)
///
/// Like Apple's standard recognizers, all output values are **absolute** relative
/// to the gesture's start — not deltas from the last callback:
///
/// - `scale` starts at `1.0` and represents the ratio of current finger distance
///    to initial finger distance
/// - `rotation` starts at `0.0` and represents the total rotation since the
///    gesture began
/// - `translation` starts at `.zero` and represents the total midpoint movement
///
/// To use the **delta pattern** (applying incremental changes each frame),
/// cache the value and subtract:
///
/// ```swift
/// var previousScale: CGFloat = 1.0
///
/// func handleGesture(_ recognizer: TransformGestureRecognizer) {
///     if recognizer.state == .began {
///         previousScale = 1.0
///     }
///     if recognizer.state == .changed {
///         let delta = recognizer.scale / previousScale
///         applyIncrementalScale(delta)
///         previousScale = recognizer.scale
///     }
/// }
/// ```
///
/// ## Usage (UIKit)
///
/// ```swift
/// let gesture = TransformGestureRecognizer(
///     target: self,
///     action: #selector(handleTransform(_:))
/// )
/// myView.addGestureRecognizer(gesture)
///
/// @objc func handleTransform(_ recognizer: TransformGestureRecognizer) {
///     switch recognizer.state {
///     case .began:
///         // Cache the view's original transform
///         originalTransform = myView.transform
///     case .changed:
///         // Build a combined transform from the gesture's outputs
///         let t = recognizer.translation
///         var transform = originalTransform
///         transform = transform.translatedBy(x: t.x, y: t.y)
///         transform = transform.scaledBy(x: recognizer.scale, y: recognizer.scale)
///         transform = transform.rotated(by: recognizer.rotation)
///         myView.transform = transform
///     case .ended, .cancelled:
///         break
///     default:
///         break
///     }
/// }
/// ```
public class TransformGestureRecognizer: UIGestureRecognizer {

    // MARK: - Public Output Properties

    /// The scale factor relative to the initial distance between the two fingers.
    ///
    /// Starts at `1.0` when the gesture begins. Values greater than `1.0` mean
    /// the fingers moved apart (zoom in); values less than `1.0` mean the fingers
    /// moved closer together (zoom out).
    ///
    /// This is computed as:
    /// ```
    /// scale = currentDistance / initialDistance
    /// ```
    public private(set) var scale: CGFloat = 1.0

    /// The total rotation (in radians) since the gesture began.
    ///
    /// Starts at `0.0`. Positive values indicate counter-clockwise rotation;
    /// negative values indicate clockwise rotation. This value can exceed ±π
    /// if the user rotates their fingers multiple full turns.
    ///
    /// Accumulated frame-by-frame to avoid the `atan2` discontinuity at ±π:
    /// ```
    /// delta = normalize(currentAngle − previousAngle)
    /// rotation += delta
    /// ```
    public private(set) var rotation: CGFloat = 0.0

    /// The total movement of the midpoint between the two fingers since the
    /// gesture began.
    ///
    /// Starts at `.zero`. This represents how far the center point between
    /// the user's fingers has moved, in the coordinate space of the view
    /// attached to the gesture recognizer.
    ///
    /// Computed as:
    /// ```
    /// translation = currentMidpoint − initialMidpoint
    /// ```
    public private(set) var translation: CGPoint = .zero

    /// The rate of change of `scale` in scale-factor-per-second.
    ///
    /// Computed from frame-to-frame deltas divided by the time interval.
    /// Available during `.changed` and `.ended` states. Useful for driving
    /// momentum-based zoom animations.
    public private(set) var scaleVelocity: CGFloat = 0.0

    /// The rate of change of `rotation` in radians-per-second.
    ///
    /// Computed from frame-to-frame deltas divided by the time interval.
    /// Available during `.changed` and `.ended` states. Useful for driving
    /// momentum-based spin animations.
    public private(set) var rotationVelocity: CGFloat = 0.0

    /// The current midpoint between the two tracked fingers, in the coordinate
    /// space of the gesture recognizer's view.
    ///
    /// This is the point around which scaling and rotation are conceptually
    /// centered. Use it as the anchor point when applying transforms.
    ///
    /// Returns `.zero` if the gesture has not yet begun or both touches are
    /// no longer available.
    public var anchorPoint: CGPoint {
        guard let touch1 = trackedTouch1,
              let touch2 = trackedTouch2,
              let view = self.view else {
            return .zero
        }
        let p1 = touch1.location(in: view)
        let p2 = touch2.location(in: view)
        return Self.midpoint(p1, p2)
    }

    // MARK: - Private Tracking State

    /// The first of the two tracked touches. `nil` until the first finger touches down.
    private var trackedTouch1: UITouch?

    /// The second of the two tracked touches. `nil` until the second finger touches down.
    private var trackedTouch2: UITouch?

    /// The midpoint between the two fingers at the moment the gesture began.
    /// Used as the reference point for computing `translation`.
    private var initialMidpoint: CGPoint = .zero

    /// The Euclidean distance between the two fingers at the moment the gesture began.
    /// Used as the denominator when computing `scale`.
    /// A value of `0` (fingers on the exact same pixel) is guarded against.
    private var initialDistance: CGFloat = 0

    /// The angle of the line from touch1 to touch2 in the **previous** frame.
    /// Used for frame-by-frame rotation accumulation to avoid the `atan2`
    /// discontinuity at ±π.
    private var previousAngle: CGFloat = 0

    /// The `scale` value from the previous frame, used to compute `scaleVelocity`.
    private var previousScale: CGFloat = 1.0

    /// The `rotation` value from the previous frame, used to compute `rotationVelocity`.
    private var previousRotation: CGFloat = 0.0

    /// The timestamp of the previous touch event, used to compute velocities.
    private var previousTimestamp: TimeInterval = 0

    // MARK: - Touch Event Handling

    /// Called when one or more fingers touch down.
    ///
    /// This method collects up to two touches. If more than two fingers touch
    /// the screen, the extras are explicitly ignored via `ignore(_:for:)` so
    /// they don't interfere with the gesture.
    ///
    /// The gesture transitions to `.began` only when both tracked touches are
    /// present — meaning both fingers have touched down.
    override public func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        // Collect up to two touches.
        for touch in touches {
            if trackedTouch1 == nil {
                trackedTouch1 = touch
            } else if trackedTouch2 == nil {
                trackedTouch2 = touch
            } else {
                // A third (or more) finger touched down. Ignore it so it doesn't
                // affect our two-finger tracking or cause the gesture to fail.
                ignore(touch, for: event)
            }
        }

        // Begin tracking once we have both fingers.
        guard let touch1 = trackedTouch1,
              let touch2 = trackedTouch2 else {
            // Only one finger so far — stay in .possible and wait for the second.
            return
        }

        let p1 = touch1.location(in: self.view)
        let p2 = touch2.location(in: self.view)

        // Snapshot the initial geometry. These values define the "identity"
        // transform — the reference frame against which all future changes
        // are measured.
        initialMidpoint = Self.midpoint(p1, p2)
        initialDistance = Self.distance(p1, p2)
        previousAngle = Self.angle(p1, p2)

        // Initialize velocities tracking.
        previousScale = 1.0
        previousRotation = 0.0
        previousTimestamp = max(touch1.timestamp, touch2.timestamp)

        state = .began
    }

    /// Called when one or more fingers move.
    ///
    /// This is where the core math happens. On every frame, we:
    /// 1. Compute the current midpoint, distance, and angle from the two touches
    /// 2. Derive translation, scale, and rotation from the initial values
    /// 3. Compute velocities from the frame-to-frame delta
    override public func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let touch1 = trackedTouch1,
              let touch2 = trackedTouch2 else { return }

        let p1 = touch1.location(in: self.view)
        let p2 = touch2.location(in: self.view)
        let currentTimestamp = max(touch1.timestamp, touch2.timestamp)

        // ── Translation ─────────────────────────────────────────────────
        // The midpoint's displacement from its initial position.
        let currentMidpoint = Self.midpoint(p1, p2)
        translation = CGPoint(
            x: currentMidpoint.x - initialMidpoint.x,
            y: currentMidpoint.y - initialMidpoint.y
        )

        // ── Scale ───────────────────────────────────────────────────────
        // Ratio of current finger distance to initial finger distance.
        // Guard against division by zero (fingers started on the same pixel).
        let currentDistance = Self.distance(p1, p2)
        if initialDistance > 0 {
            scale = currentDistance / initialDistance
        }

        // ── Rotation ────────────────────────────────────────────────────
        // Accumulate rotation frame-by-frame to handle the atan2 discontinuity.
        //
        // atan2 returns values in [-π, +π]. If the user's fingers cross the
        // ±π boundary (e.g., rotating from 170° to -170°), the raw difference
        // would be -340° instead of the correct +20°. By normalizing the
        // per-frame delta to [-π, +π], we get the true small rotation, and
        // accumulating these deltas allows rotation to grow past ±π for
        // multi-turn rotations.
        let currentAngle = Self.angle(p1, p2)
        let angleDelta = Self.normalizeAngle(currentAngle - previousAngle)
        rotation += angleDelta
        previousAngle = currentAngle

        // ── Velocities ──────────────────────────────────────────────────
        // Compute from frame-to-frame deltas divided by elapsed time.
        let dt = currentTimestamp - previousTimestamp
        if dt > 0 {
            scaleVelocity = (scale - previousScale) / dt
            rotationVelocity = (rotation - previousRotation) / dt
        }

        // Save current values for next frame's velocity computation.
        previousScale = scale
        previousRotation = rotation
        previousTimestamp = currentTimestamp

        state = .changed
    }

    /// Called when one or more fingers lift from the screen.
    ///
    /// The gesture ends when either of the two tracked fingers lifts. This
    /// matches the behavior of `UIPinchGestureRecognizer` and
    /// `UIRotationGestureRecognizer`.
    override public func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        for touch in touches {
            if touch === trackedTouch1 || touch === trackedTouch2 {
                // One of our tracked fingers lifted — the gesture is complete.
                state = .ended
                return
            }
        }
    }

    /// Called when a system event (e.g., incoming phone call) cancels touches.
    ///
    /// The gesture transitions to `.cancelled`, which tells UIKit the gesture
    /// was interrupted and did not complete normally.
    override public func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        state = .cancelled
    }

    /// Called by UIKit after the gesture ends, is cancelled, or fails.
    ///
    /// This resets all internal state back to initial values so the recognizer
    /// is ready to track a new gesture. UIKit calls this automatically — you
    /// should never call it directly.
    override public func reset() {
        super.reset()

        trackedTouch1 = nil
        trackedTouch2 = nil

        initialMidpoint = .zero
        initialDistance = 0
        previousAngle = 0

        scale = 1.0
        rotation = 0.0
        translation = .zero

        scaleVelocity = 0.0
        rotationVelocity = 0.0

        previousScale = 1.0
        previousRotation = 0.0
        previousTimestamp = 0
    }

    // MARK: - Geometry Helpers

    /// Computes the midpoint (centroid) of two points.
    ///
    /// ```
    ///     M = ( (P1.x + P2.x) / 2,  (P1.y + P2.y) / 2 )
    /// ```
    ///
    /// The midpoint is the center of mass of the two-finger system. Its
    /// movement represents the "pan" component of the gesture.
    private static func midpoint(_ p1: CGPoint, _ p2: CGPoint) -> CGPoint {
        CGPoint(x: (p1.x + p2.x) / 2.0, y: (p1.y + p2.y) / 2.0)
    }

    /// Computes the Euclidean distance between two points.
    ///
    /// ```
    ///     d = √( (P2.x − P1.x)² + (P2.y − P1.y)² )
    /// ```
    ///
    /// This is the standard Euclidean norm (L2 distance). The ratio of
    /// the current distance to the initial distance gives us the scale factor.
    /// Uses `hypot()` for numerical stability (avoids overflow/underflow
    /// that can occur with manual `sqrt(dx*dx + dy*dy)` on extreme values).
    private static func distance(_ p1: CGPoint, _ p2: CGPoint) -> CGFloat {
        hypot(p2.x - p1.x, p2.y - p1.y)
    }

    /// Computes the angle (in radians) of the line from `p1` to `p2`.
    ///
    /// ```
    ///     θ = atan2(P2.y − P1.y, P2.x − P1.x)
    /// ```
    ///
    /// `atan2(y, x)` returns the angle in radians between the positive x-axis
    /// and the vector `(x, y)`, in the range `[-π, +π]`. Unlike `atan(y/x)`,
    /// it correctly handles all four quadrants and avoids division-by-zero
    /// when `dx == 0`.
    ///
    /// The change in this angle over time represents the rotation component
    /// of the gesture.
    private static func angle(_ p1: CGPoint, _ p2: CGPoint) -> CGFloat {
        atan2(p2.y - p1.y, p2.x - p1.x)
    }

    /// Normalizes an angle to the range `[-π, +π]`.
    ///
    /// ```
    ///     while θ >  π:  θ -= 2π
    ///     while θ < -π:  θ += 2π
    /// ```
    ///
    /// This is essential for the frame-by-frame rotation accumulation.
    /// Without normalization, a rotation that crosses the `atan2` boundary
    /// (e.g., from +179° to -179°) would produce a delta of -358° instead
    /// of the correct +2°.
    ///
    /// The `remainder` function from the standard library computes the
    /// IEEE 754 remainder, which maps any value into `[-π, +π]` in a single
    /// operation — no loops needed.
    private static func normalizeAngle(_ angle: CGFloat) -> CGFloat {
        remainder(angle, 2.0 * .pi)
    }
}
