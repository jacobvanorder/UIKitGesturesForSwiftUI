//
//  File.swift
//  UIKitGesturesForSwiftUI
//
//  Created by Jacob Van Order on 2/17/26.
//

import Foundation
import SwiftUI
import UIKit

public struct MultiFingerPanGesture: UIGestureRecognizerRepresentable {

    public let minimumNumberOfTouches: Int
    public let maximumNumberOfTouches: Int

    internal let onBegan: ((UIPanGestureRecognizer) -> Void)?
    internal let onChanged: ((UIPanGestureRecognizer) -> Void)?
    internal let onEnded: ((UIPanGestureRecognizer) -> Void)?

    internal let shouldRecognizeSimultaneouslyWith: ((UIGestureRecognizer) -> Bool)?

    public init(minimumNumberOfTouches: Int,
                maximumNumberOfTouches: Int,
                onBegan: ((UIPanGestureRecognizer) -> Void)? = nil,
                onChanged: ((UIPanGestureRecognizer) -> Void)? = nil,
                onEnded: ((UIPanGestureRecognizer) -> Void)? = nil,
                shouldRecognizeSimultaneouslyWith: ((UIGestureRecognizer) -> Bool)? = nil) {
        self.minimumNumberOfTouches = minimumNumberOfTouches
        self.maximumNumberOfTouches = maximumNumberOfTouches
        self.onBegan = onBegan
        self.onChanged = onChanged
        self.onEnded = onEnded
        self.shouldRecognizeSimultaneouslyWith = shouldRecognizeSimultaneouslyWith
    }

    public func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let panGesture = UIPanGestureRecognizer()
        panGesture.minimumNumberOfTouches = minimumNumberOfTouches
        panGesture.maximumNumberOfTouches = maximumNumberOfTouches
        panGesture.delegate = context.coordinator
        return panGesture
    }

    public func onBegan(_ action: @escaping (UIPanGestureRecognizer) -> Void) -> MultiFingerPanGesture {
        MultiFingerPanGesture(minimumNumberOfTouches: self.minimumNumberOfTouches,
                              maximumNumberOfTouches: self.maximumNumberOfTouches,
                              onBegan: action,
                              onChanged: self.onChanged,
                              onEnded: self.onEnded,
                              shouldRecognizeSimultaneouslyWith: self.shouldRecognizeSimultaneouslyWith)
    }

    public func onChanged(_ action: @escaping (UIPanGestureRecognizer) -> Void) -> MultiFingerPanGesture {
        MultiFingerPanGesture(minimumNumberOfTouches: self.minimumNumberOfTouches,
                              maximumNumberOfTouches: self.maximumNumberOfTouches,
                              onBegan: self.onBegan,
                              onChanged: action,
                              onEnded: self.onEnded,
                              shouldRecognizeSimultaneouslyWith: self.shouldRecognizeSimultaneouslyWith)
    }

    public func onEnded(_ action: @escaping (UIPanGestureRecognizer) -> Void) -> MultiFingerPanGesture {
        MultiFingerPanGesture(minimumNumberOfTouches: self.minimumNumberOfTouches,
                              maximumNumberOfTouches: self.maximumNumberOfTouches,
                              onBegan: self.onBegan,
                              onChanged: self.onChanged,
                              onEnded: action,
                              shouldRecognizeSimultaneouslyWith: self.shouldRecognizeSimultaneouslyWith)
    }

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

    public func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator(shouldRecognizeSimultaneouslyWith: shouldRecognizeSimultaneouslyWith)
    }

    public class Coordinator: NSObject, UIGestureRecognizerDelegate {

        let shouldRecognizeSimultaneouslyWith: ((UIGestureRecognizer) -> Bool)?

        internal init(shouldRecognizeSimultaneouslyWith: ((UIGestureRecognizer) -> Bool)? = nil) {
            self.shouldRecognizeSimultaneouslyWith = shouldRecognizeSimultaneouslyWith
        }

        public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                                      shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return self.shouldRecognizeSimultaneouslyWith?(otherGestureRecognizer) ?? true
        }
    }
}
