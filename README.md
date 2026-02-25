# UIKitGesturesForSwiftUI

Advanced multi-touch gesture recognizers for SwiftUI, bringing the full power of UIKit's `UIGestureRecognizer` to SwiftUI with complete feature parity and Swift 6 concurrency support.

Written by [@jacobvo](https://mastodon.social/@jacobvo). 

*A.I. Disclaimer:*

Initial concept of one gesture hand-coded but then Claude assisted with replication of additional gestures. 

## Why This Library?

SwiftUI's built-in gesture system is powerful but has limitations:

- `DragGesture` only supports **single-finger** dragging
- No native support for **multi-finger** gestures (2+ fingers)
- Limited access to UIKit-specific features like velocity, number of touches, and precise gesture states
- No control over gesture recognizer delegate methods for complex gesture interactions

**UIKitGesturesForSwiftUI** bridges this gap by exposing UIKit's full gesture recognizer capabilities directly in SwiftUI.

## Features

✅ **Multi-finger gesture support** - Pan, tap, swipe, pinch, rotate with 2+ fingers
✅ **Full UIKit feature parity** - Access velocity, translation, rotation, scale, and more
✅ **Gesture delegate control** - Customize simultaneous recognition, failure requirements, and touch handling
✅ **Swift 6 concurrency safe** - All closures are `@MainActor` isolated
✅ **Declarative builder API** - Chain `.onBegan`, `.onChanged`, `.onEnded` naturally
✅ **Comprehensive documentation** - Inline docs for every gesture and method
✅ **Somewhat tested** - 23 unit tests covering core functionality

## Requirements

- **iOS 18.0+**
- **Swift 6.0+**
- **Xcode 16.0+**

## Installation

### Swift Package Manager

Add this package to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/UIKitGesturesForSwiftUI.git", from: "1.0.0")
]
```

Or in Xcode:
1. File → Add Package Dependencies
2. Enter the repository URL
3. Select version and add to your target

## Quick Start

```swift
import SwiftUI
import UIKitGesturesForSwiftUI

struct ContentView: View {
    @State private var offset = CGSize.zero

    var body: some View {
        Rectangle()
            .fill(.blue)
            .frame(width: 200, height: 200)
            .offset(offset)
            .gesture(
                MultiFingerPanGesture(
                    minimumNumberOfTouches: 2,
                    maximumNumberOfTouches: 2
                )
                .onChanged { recognizer in
                    let translation = recognizer.translation(in: recognizer.view)
                    offset = CGSize(width: translation.x, height: translation.y)
                }
            )
    }
}
```

## Available Gestures

### MultiFingerPanGesture

Continuous gesture for tracking multi-finger panning with velocity and translation.

```swift
MultiFingerPanGesture(
    minimumNumberOfTouches: 2,
    maximumNumberOfTouches: 2
)
.onBegan { recognizer in
    print("Pan started")
}
.onChanged { recognizer in
    let translation = recognizer.translation(in: recognizer.view)
    let velocity = recognizer.velocity(in: recognizer.view)
    print("Translation: \(translation), Velocity: \(velocity)")
}
.onEnded { recognizer in
    let finalVelocity = recognizer.velocity(in: recognizer.view)
    print("Pan ended with velocity: \(finalVelocity)")
}
```

**Use Cases:**
- Two-finger scrolling
- Multi-touch drag operations
- Gesture-based navigation

### MultiFingerTapGesture

Discrete gesture for detecting multi-finger taps with configurable tap count.

```swift
MultiFingerTapGesture(
    numberOfTouchesRequired: 3,
    numberOfTapsRequired: 2  // Double-tap with 3 fingers
)
.onEnded { recognizer in
    print("Triple-finger double-tap detected!")
}
```

**Use Cases:**
- Accessibility shortcuts
- Hidden debug menus
- Advanced user interactions

### MultiFingerPinchGesture

Continuous gesture for tracking pinch-to-zoom with scale and velocity.

```swift
@State private var scale: CGFloat = 1.0

MultiFingerPinchGesture()
    .onChanged { recognizer in
        scale *= recognizer.scale
        recognizer.scale = 1.0  // Reset for next update
    }
    .onEnded { recognizer in
        let finalVelocity = recognizer.velocity
        print("Pinch ended with velocity: \(finalVelocity)")
    }
```

**Use Cases:**
- Zoom controls
- Image scaling
- Map interactions

### MultiFingerRotationGesture

Continuous gesture for tracking rotation with angle and velocity.

```swift
@State private var rotation: Angle = .zero

MultiFingerRotationGesture()
    .onChanged { recognizer in
        rotation += Angle(radians: recognizer.rotation)
        recognizer.rotation = 0  // Reset for next update
    }
    .onEnded { recognizer in
        let finalVelocity = recognizer.velocity
        print("Rotation velocity: \(finalVelocity) radians/sec")
    }
```

**Use Cases:**
- Image rotation
- 3D object manipulation
- Creative tools

### MultiFingerSwipeGesture

Discrete gesture for detecting directional swipes with multiple fingers.

```swift
MultiFingerSwipeGesture(
    numberOfTouchesRequired: 3,
    direction: .down
)
.onEnded { recognizer in
    print("Three-finger swipe down detected!")
}
```

**Directions:** `.up`, `.down`, `.left`, `.right`

**Use Cases:**
- Navigation gestures
- App switching
- Custom gesture controls

### MultiFingerLongPressGesture

Continuous gesture for long-press detection with configurable duration and movement tolerance.

```swift
MultiFingerLongPressGesture(
    numberOfTouchesRequired: 2,
    minimumPressDuration: 1.0,
    allowableMovement: 10
)
.onBegan { recognizer in
    print("Long press began")
}
.onEnded { recognizer in
    print("Long press ended")
}
```

**Use Cases:**
- Context menus
- Selection mode
- Secondary actions

### MultiFingerTransformGesture

This is just an example of a custom `UIGestureRecognizer` subclass that is then extended into SwiftUI. Continuous gesture combining pan, pinch, and rotation into a single transform.

```swift
@State private var transform = CGAffineTransform.identity

MultiFingerTransformGesture(
    minimumNumberOfTouches: 2,
    maximumNumberOfTouches: 2
)
.onChanged { recognizer in
    transform = recognizer.transform
    print("Translation: \(recognizer.translation)")
    print("Rotation: \(recognizer.rotation)")
    print("Scale: \(recognizer.scale)")
}
```

**Use Cases:**
- Photo editing
- Object manipulation
- Canvas interactions

## Advanced Usage

### Customizing Gesture Delegate Behavior

All gestures support full `UIGestureRecognizerDelegate` customization via optional closures.

#### Simultaneous Gesture Recognition

Allow multiple gestures to recognize at the same time:

```swift
MultiFingerPanGesture(minimumNumberOfTouches: 2, maximumNumberOfTouches: 2)
    .shouldRecognizeSimultaneouslyWith { otherGesture in
        // Allow simultaneous recognition with pinch gestures
        return otherGesture is UIPinchGestureRecognizer
    }
```

**Default:** `true` (allows simultaneous recognition by default)

#### Controlling Gesture Begin

Conditionally allow or prevent gestures from starting:

```swift
@State private var isGestureEnabled = true

MultiFingerPanGesture(minimumNumberOfTouches: 2, maximumNumberOfTouches: 2)
    .shouldBegin { recognizer in
        return isGestureEnabled
    }
```

#### Touch and Event Filtering

Control which touches or events the gesture responds to:

```swift
MultiFingerPanGesture(minimumNumberOfTouches: 2, maximumNumberOfTouches: 2)
    .shouldReceiveTouch { recognizer, touch in
        // Only respond to touches inside specific views
        guard let view = touch.view else { return false }
        return view.tag == 100
    }
```

#### Gesture Failure Dependencies

Require one gesture to fail before another begins:

```swift
let tapGesture = MultiFingerTapGesture(numberOfTouchesRequired: 1, numberOfTapsRequired: 2)
let panGesture = MultiFingerPanGesture(minimumNumberOfTouches: 1, maximumNumberOfTouches: 1)
    .shouldRequireFailureOf { otherGesture in
        // Pan only starts if double-tap fails
        return otherGesture is UITapGestureRecognizer
    }
```

### Complete Delegate Customization Example

```swift
MultiFingerPanGesture(
    minimumNumberOfTouches: 2,
    maximumNumberOfTouches: 2,
    shouldBegin: { recognizer in
        // Only allow if conditions are met
        return someCondition
    },
    shouldRecognizeSimultaneouslyWith: { otherGesture in
        // Allow with pinch, block others
        return otherGesture is UIPinchGestureRecognizer
    },
    shouldReceiveTouch: { recognizer, touch in
        // Filter touches by location
        let location = touch.location(in: touch.view)
        return location.x > 100
    }
)
.onChanged { recognizer in
    // Handle gesture
}
```

## Gesture State Lifecycle

All continuous gestures follow this state machine:

```
.possible → .began → .changed (repeated) → .ended
               ↘ .cancelled
               ↘ .failed
```

**Discrete gestures** (tap, swipe) transition directly to `.onEnded`

**Callbacks provided:**
- `.onBegan` - Gesture started (continuous only)
- `.onChanged` - Gesture updated (continuous only)
- `.onEnded` - Gesture completed (continuous and discrete)

**Note:** `.cancelled` and `.failed` states are not exposed as they indicate the gesture did not complete successfully.

## Concurrency and Thread Safety

All gesture closures are marked `@MainActor` because:

✅ UIKit gesture recognizers always call delegates on the main thread
✅ SwiftUI view updates must happen on the main thread
✅ You can safely capture `@MainActor` isolated state (view models, etc.)

```swift
@MainActor
@Observable
class ViewModel {
    var count = 0
}

let viewModel = ViewModel()

MultiFingerPanGesture(minimumNumberOfTouches: 2, maximumNumberOfTouches: 2)
    .onChanged { recognizer in
        viewModel.count += 1  // ✅ Safe - both are @MainActor
    }
```

## Examples

### Two-Finger Scrolling Canvas

```swift
struct ScrollableCanvas: View {
    @State private var offset = CGSize.zero
    @State private var scale: CGFloat = 1.0

    var body: some View {
        Canvas { context, size in
            // Draw content here
        }
        .scaleEffect(scale)
        .offset(offset)
        .gesture(
            MultiFingerPanGesture(
                minimumNumberOfTouches: 2,
                maximumNumberOfTouches: 2
            )
            .onChanged { recognizer in
                let translation = recognizer.translation(in: recognizer.view)
                offset = CGSize(width: translation.x, height: translation.y)
            }
        )
        .gesture(
            MultiFingerPinchGesture()
                .onChanged { recognizer in
                    scale *= recognizer.scale
                    recognizer.scale = 1.0
                }
        )
    }
}
```

### Photo Editor Transform

```swift
struct PhotoEditor: View {
    @State private var imageTransform = CGAffineTransform.identity

    var body: some View {
        Image("photo")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .transformEffect(imageTransform)
            .gesture(
                MultiFingerTransformGesture(
                    minimumNumberOfTouches: 2,
                    maximumNumberOfTouches: 2
                )
                .onChanged { recognizer in
                    imageTransform = recognizer.transform
                }
                .onEnded { recognizer in
                    // Optionally apply momentum or snap to grid
                }
            )
    }
}
```

### Gesture Conflict Resolution

```swift
struct GestureDemo: View {
    @State private var singleTapCount = 0
    @State private var doubleTapCount = 0

    var body: some View {
        Rectangle()
            .fill(.blue)
            .gesture(
                MultiFingerTapGesture(
                    numberOfTouchesRequired: 1,
                    numberOfTapsRequired: 1,
                    shouldRequireFailureOf: { other in
                        // Wait for double-tap to fail
                        other is UITapGestureRecognizer && other.numberOfTapsRequired == 2
                    }
                )
                .onEnded { _ in
                    singleTapCount += 1
                }
            )
            .gesture(
                MultiFingerTapGesture(
                    numberOfTouchesRequired: 1,
                    numberOfTapsRequired: 2
                )
                .onEnded { _ in
                    doubleTapCount += 1
                }
            )
    }
}
```

## API Reference

### Common Parameters

All gestures support these delegate customization parameters:

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `shouldBegin` | `@MainActor (UIGestureRecognizer) -> Bool` | `true` | Control if gesture should begin |
| `shouldRecognizeSimultaneouslyWith` | `@MainActor (UIGestureRecognizer) -> Bool` | `true` | Allow simultaneous recognition |
| `shouldReceiveTouch` | `@MainActor (UIGestureRecognizer, UITouch) -> Bool` | `true` | Filter touches |
| `shouldReceivePress` | `@MainActor (UIGestureRecognizer, UIPress) -> Bool` | `true` | Filter button presses |
| `shouldReceiveEvent` | `@MainActor (UIGestureRecognizer, UIEvent) -> Bool` | `true` | Filter events |
| `shouldRequireFailureOf` | `@MainActor (UIGestureRecognizer) -> Bool` | `false` | Require other gesture to fail |
| `shouldBeRequiredToFailBy` | `@MainActor (UIGestureRecognizer) -> Bool` | `false` | Be required to fail by other |

**Note:** Unlike UIKit's default of `false`, this library defaults `shouldRecognizeSimultaneouslyWith` to `true` for better multi-gesture composition.

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Write tests for new functionality
4. Ensure all tests pass and there are no warnings
5. Follow Swift API Design Guidelines
6. Commit your changes (`git commit -m 'Add amazing feature'`)
7. Push to the branch (`git push origin feature/amazing-feature`)
8. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.


