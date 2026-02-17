# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

UIKitGesturesForSwiftUI is a Swift library that provides advanced gesture recognizers for SwiftUI by leveraging `UIGestureRecognizerRepresentable` for full UIKit feature parity and complex interaction support.

## Build & Test

This is a Swift Package. Once `Package.swift` is created:
- **Build:** `swift build`
- **Test:** `swift test`
- **Single test:** `swift test --filter <TestClassName>/<testMethodName>`
- **Xcode:** Open `Package.swift` directly in Xcode

## Architecture

The library bridges UIKit's gesture recognizer system into SwiftUI using `UIGestureRecognizerRepresentable` (iOS 18+). The goal is SwiftUI view modifiers that expose the full power of UIKit gesture recognizers (e.g., simultaneous recognition, failure requirements, delegate callbacks) with a declarative API.

## Conventions

- **Target platform:** iOS (UIKit interop via UIGestureRecognizerRepresentable)
- **Distribution:** Swift Package Manager
- **License:** MIT
