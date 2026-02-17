# Project: UIKitGesturesForSwiftUI

## Quick Reference
- **Platform**: iOS 18+
- **Language**: Swift 6.0
- **UI Framework**: SwiftUI, UIKit
- **Minimum Deployment**: iOS 18.0
- **Package Manager**: Swift Package Manager

## XcodeBuildMCP Integration
**IMPORTANT**: This project uses XcodeBuildMCP for all Xcode operations.
- Build: `mcp__xcodebuildmcp__build_sim_name_proj`
- Test: `mcp__xcodebuildmcp__test_sim_name_proj`
- Clean: `mcp__xcodebuildmcp__clean`

## Coding Standards

### Swift Style
- Use Swift 6 strict concurrency
- Prefer `@Observable` over `ObservableObject`
- Use `async/await` for all async operations
- Follow Apple's Swift API Design Guidelines
- Use `guard` for early exits
- Prefer value types (structs) over reference types (classes)

### SwiftUI Patterns
- Extract views when they exceed 100 lines
- Use `@State` for local view state only
- Use `@Environment` for dependency injection
- Prefer `NavigationStack` over deprecated `NavigationView`
- Use `@Bindable` for bindings to @Observable objects


### Error Handling
```swift
// Always use typed errors
enum AppError: LocalizedError {
    case networkError(underlying: Error)
    case validationError(message: String)
    
    var errorDescription: String? {
        switch self {
        case .networkError(let error): return error.localizedDescription
        case .validationError(let msg): return msg
        }
    }
}
```

## Testing Requirements
- Unit tests for all ViewModels
- UI tests for critical user flows
- Use Swift Testing framework (`@Test`, `#expect`)
- Minimum 80% code coverage for business logic

## DO NOT
- Write UITests during scaffolding phase
- Use deprecated APIs (UIKit when SwiftUI suffices)
- Create massive monolithic views
- Use force unwrapping (`!`) without justification
- Ignore Swift 6 concurrency warnings

## Planning Workflow
When starting new features:
1. Use `ultrathink` for architectural decisions
2. Use Plan Mode (`Shift+Tab`) for implementation strategy
3. Implement incrementally with tests
