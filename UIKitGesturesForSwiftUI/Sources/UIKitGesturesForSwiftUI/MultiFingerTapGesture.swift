//
//  MultiFingerTapGesture.swift
//  UIKitGesturesForSwiftUI
//
//  Created by Jacob Van Order on 2/18/26.
//

import Foundation
import SwiftUI
import UIKit

public struct MultiFingerTapGesture: UIGestureRecognizerRepresentable {

    public let numberOfTapsRequired: Int
    public let numberOfTouchesRequired: Int
    
    private let onEnded: ((UITapGestureRecognizer) -> Void)?
    private let shouldRecognizeSimultaneouslyWith: ((UIGestureRecognizer) -> Bool)?

    public init(numberOfTapsRequired: Int = 1,
                numberOfTouchesRequired: Int = 1,
                onEnded: ((UITapGestureRecognizer) -> Void)? = nil,
                shouldRecognizeSimultaneouslyWith: ((UIGestureRecognizer) -> Bool)? = nil) {
        self.numberOfTapsRequired = numberOfTapsRequired
        self.numberOfTouchesRequired = numberOfTouchesRequired
        self.onEnded = onEnded
        self.shouldRecognizeSimultaneouslyWith = shouldRecognizeSimultaneouslyWith
    }

    public func makeUIGestureRecognizer(context: Context) -> UITapGestureRecognizer {
        let tapGesture = UITapGestureRecognizer()
        tapGesture.numberOfTouchesRequired = numberOfTouchesRequired
        tapGesture.numberOfTapsRequired = numberOfTapsRequired
        tapGesture.delegate = context.coordinator
        return tapGesture
    }

    public func updateUIGestureRecognizer(_ recognizer: UITapGestureRecognizer, context: Context) {
        recognizer.numberOfTapsRequired = self.numberOfTapsRequired
        recognizer.numberOfTouchesRequired = self.numberOfTouchesRequired
    }

    public func onEnded(_ action: @escaping (UITapGestureRecognizer) -> Void) -> MultiFingerTapGesture {
        MultiFingerTapGesture(numberOfTapsRequired: self.numberOfTapsRequired,
                              numberOfTouchesRequired: self.numberOfTouchesRequired,
                              onEnded: action,
                              shouldRecognizeSimultaneouslyWith: self.shouldRecognizeSimultaneouslyWith)
    }

    public func handleUIGestureRecognizerAction(_ recognizer: UITapGestureRecognizer,
                                                context: Context) {
        switch recognizer.state {
        case .ended:
            onEnded?(recognizer)
        default:
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
