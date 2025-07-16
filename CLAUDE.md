# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a comprehensive iOS UI testing framework for the Superwall SDK. The project contains both an iOS app and automated UI tests that validate the SDK's functionality across different configurations and scenarios.

## Key Components

### Main App Structure
- **UI Tests.app**: Main iOS application target that integrates SuperwallKit
- **Automated UI Testing.xctest**: XCTest bundle containing automated UI tests
- **RootViewController**: Main controller that orchestrates test execution via the `Testable` protocol
- **Communicator**: HTTP-based communication system between the app and test runner using port-based IPC

### Test Architecture
- **UITests_Swift.swift**: Contains 170+ numbered test functions (test0, test1, etc.) that test various SDK scenarios
- **UITests_ObjC.m**: Objective-C equivalent tests for cross-language compatibility
- **Automated_UI_Testing.swift**: Base test class that handles app lifecycle, StoreKit sessions, and UI interactions
- **Tests.swift**: Auto-generated file containing individual test classes for each test number
- **Testable.swift**: Auto-generated protocol defining test methods and options

### Code Generation System
The project uses a build script that auto-generates test infrastructure:
- Scans UITests_Swift.swift for test functions to determine the highest test number
- Generates Testable.swift protocol with all test methods
- Generates Tests.swift with individual test classes for each test
- Located in Xcode build phase "Autogenerate functions"

### Network Interceptor Library
Custom network interception system in `Libraries/NetworkInterceptor/`:
- Intercepts and redirects HTTP requests for testing
- Supports request sniffing, redirection, and evaluation
- Includes Slack integration for test notifications

### Configuration System
- **Configuration_Swift.swift** & **Configuration_ObjC.m**: Test configuration management
- **Constants.swift**: Global constants and environment setup
- **TestOptions**: Per-test configuration including StoreKit settings and SDK options

## Common Commands

### Running Tests
```bash
# Run all test schemes
./runTests.sh

# Run specific scheme
xcodebuild test -scheme "UI Tests -swift -automatic" -destination 'platform=iOS Simulator,name=iPhone 14 Pro,OS=16.4'
```

### Available Test Schemes
- **UI Tests -swift -automatic**: Swift tests with automatic configuration
- **UI Tests -swift -advanced**: Swift tests with advanced configuration
- **UI Tests -objc -automatic**: Objective-C tests with automatic configuration
- **UI Tests -objc -advanced**: Objective-C tests with advanced configuration
- **UI Tests -demo**: Demo configuration

### Build Commands
```bash
# Build main app
xcodebuild build -scheme "UI Tests" -destination 'platform=iOS Simulator,name=iPhone 14 Pro'

# Build tests
xcodebuild build-for-testing -scheme "Automated UI Testing" -destination 'platform=iOS Simulator,name=iPhone 14 Pro'
```

## Development Workflow

### Adding New Tests
1. Add test method to `UITests_Swift.swift` with sequential numbering (e.g., `test172`)
2. Optionally add corresponding method to `UITests_ObjC.m`
3. Add test options method if needed (e.g., `testOptions172`)
4. Build project to trigger auto-generation of supporting files

### Test Structure
Tests follow this pattern:
```swift
func test{N}() async throws {
    // Setup SDK configuration
    Superwall.shared.identify(userId: "test{N}")
    
    // Perform actions
    Superwall.shared.register(placement: "placement_name")
    
    // Assert results
    await assert(after: Constants.paywallPresentationDelay)
}
```

### Test Communication
- Tests communicate via HTTP between app and test runner
- Uses dynamic port allocation based on simulator clone number
- Supports assertions, screenshots, StoreKit operations, and app lifecycle events

## Dependencies

### Swift Package Manager
- **SuperwallKit**: Main SDK being tested (develop branch)
- **swift-snapshot-testing**: For screenshot comparisons
- **swifter**: HTTP server for test communication

### Built-in Libraries
- **NetworkInterceptor**: Custom network interception
- **GzipSwift**: Gzip compression utilities
- **URLRequest-cURL**: cURL conversion utilities

## Important Notes

- Tests run in isolated simulator environments with fresh app installs
- StoreKit testing uses sandbox configuration with `Products.storekit`
- Snapshot testing creates reference images in `__Snapshots__` directory
- Tests support both StoreKit 1 and StoreKit 2 configurations
- The system handles parallel test execution with unique port allocation
- All test infrastructure is auto-generated based on test method scanning

## Test Debugging

### Common Issues
- Port conflicts: Ensure simulators are properly isolated
- StoreKit failures: Check sandbox configuration and product setup
- Network timeouts: Verify HTTP communication between app and test runner
- Screenshot differences: Update reference images when UI changes

### Test Execution Flow
1. Test runner launches app with environment variables
2. App configures SDK and starts HTTP server
3. Test runner sends `runTest` command with test number
4. App executes test method and communicates results back
5. Test runner handles assertions and captures screenshots
6. App terminates after test completion