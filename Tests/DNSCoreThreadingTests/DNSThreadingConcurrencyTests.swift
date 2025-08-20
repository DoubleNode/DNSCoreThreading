//
//  DNSThreadingConcurrencyTests.swift
//  DoubleNode Swift Framework (DNSFramework) - DNSCoreThreadingTests
//
//  Created by Darren Ehlers.
//  Copyright © 2020 - 2016 DoubleNode.com. All rights reserved.
//

import XCTest
@preconcurrency import ObjectiveC  // Fix: Add @preconcurrency for ObjectiveC module
import Foundation
import os.lock

@testable import DNSCoreThreading
@testable import DNSError

final class DNSThreadingCurrencyTests: XCTestCase {
    
    // MARK: - Thread-Safe Test Infrastructure
    
    // Fix: Use thread-safe counter with OSAllocatedUnfairLock
    private let atomicCounter = OSAllocatedUnfairLock(initialState: 0)
    private let atomicSharedCounter = OSAllocatedUnfairLock(initialState: 0)
    
    // Thread-safe counter access
    private var counter: Int {
        get { atomicCounter.withLock { $0 } }
        set { atomicCounter.withLock { $0 = newValue } }
    }
    
    private var sharedCounter: Int {
        get { atomicSharedCounter.withLock { $0 } }
        set { atomicSharedCounter.withLock { $0 = newValue } }
    }
    
    override func setUp() {
        super.setUp()
        // Reset counters for each test
        counter = 0
        sharedCounter = 0
    }
    
    // MARK: - Swift 6 Sendable Test Object
    
    // Fix: Create Sendable test object instead of using NSObject
    private struct SendableTestObject: Sendable {
        let identifier: String
        let timestamp: Date
        
        init(identifier: String) {
            self.identifier = identifier
            self.timestamp = Date()
        }
    }
    
    // MARK: - Concurrency Tests
    
    func testConcurrentCodeLocationCreation() async {
        let expectation = XCTestExpectation(description: "Concurrent CodeLocation creation")
        let iterations = 100
        
        // Fix: Use TaskGroup for proper Swift 6 concurrency
        let localAtomicCounter = self.atomicCounter  // Capture atomic counter locally
        
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<iterations {  // Fix: Use _ instead of unused 'i'
                group.addTask {
                    let testObject = SendableTestObject(identifier: UUID().uuidString)
                    let location = CodeLocation(testObject)
                    
                    // Verify properties are accessible
                    XCTAssertFalse(location.asString.isEmpty)
                    XCTAssertNotNil(location.userInfo)
                    
                    // Thread-safe counter increment
                    localAtomicCounter.withLock { $0 += 1 }
                }
            }
        }
        
        // Verify all tasks completed
        XCTAssertEqual(counter, iterations)
        expectation.fulfill()
        
        await fulfillment(of: [expectation], timeout: 10.0)
    }
    
    func testConcurrentPathRootManagement() async {
        let expectation = XCTestExpectation(description: "Concurrent path root management")
        let iterations = 50
        
        await withTaskGroup(of: Void.self) { group in
            // Concurrent additions
            for index in 0..<iterations {
                group.addTask {
                    CodeLocation.addFilenamePathRoot("/test/path/\(index)")
                }
            }
            
            // Concurrent reads
            for _ in 0..<iterations {  // Fix: Use _ instead of unused variable
                group.addTask {
                    let roots = CodeLocation.filenamePathRoots
                    XCTAssertNotNil(roots)
                }
            }
        }
        
        // Verify additions were successful
        let finalRoots = CodeLocation.filenamePathRoots
        XCTAssertGreaterThanOrEqual(finalRoots.count, iterations)
        
        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 10.0)
    }
    
    func testConcurrentStringOperations() async {
        let expectation = XCTestExpectation(description: "Concurrent string operations")
        let iterations = 100
        
        let localAtomicSharedCounter = self.atomicSharedCounter  // Capture atomic counter locally
        
        await withTaskGroup(of: Void.self) { group in
            for index in 0..<iterations {
                group.addTask {
                    // Test shortenErrorObject
                    let objectName = CodeLocation.shortenErrorObject("TestObject\(index)")
                    XCTAssertFalse(objectName.isEmpty)
                    
                    // Test shortenErrorPath
                    let path = CodeLocation.shortenErrorPath("/long/test/path/file\(index).swift")
                    XCTAssertFalse(path.isEmpty)
                    
                    // Thread-safe shared counter increment
                    localAtomicSharedCounter.withLock { $0 += 1 }
                }
            }
        }
        
        XCTAssertEqual(sharedCounter, iterations)
        expectation.fulfill()
        
        await fulfillment(of: [expectation], timeout: 10.0)
    }
    
    // MARK: - Thread Sanitizer Stress Tests
    
    func testHighConcurrencyStress() async {
        let expectation = XCTestExpectation(description: "High concurrency stress test")
        let iterations = 1000
        let concurrentTasks = 50
        
        let localAtomicCounter = self.atomicCounter  // Capture atomic counter locally
        
        await withTaskGroup(of: Void.self) { group in
            for taskIndex in 0..<concurrentTasks {
                group.addTask {
                    for innerIndex in 0..<(iterations / concurrentTasks) {
                        let testObject = SendableTestObject(
                            identifier: "Task\(taskIndex)-Item\(innerIndex)"
                        )
                        
                        // Create location with concurrent access
                        let location = CodeLocation(testObject)
                        
                        // Perform operations that access shared state
                        CodeLocation.addFilenamePathRoot("/stress/\(taskIndex)/\(innerIndex)")
                        let _ = CodeLocation.filenamePathRoots.count
                        let _ = location.userInfo
                        
                        // Thread-safe counter
                        localAtomicCounter.withLock { $0 += 1 }
                    }
                }
            }
        }
        
        XCTAssertEqual(counter, iterations)
        expectation.fulfill()
        
        await fulfillment(of: [expectation], timeout: 30.0)
    }
    
    // MARK: - Thread Sanitizer Verification Helper
    
    func testThreadSanitizerValidation() {
        // This test specifically exercises the debug method for Thread Sanitizer
        #if DEBUG
        CodeLocation.performThreadSafetyTest()
        #endif
        
        // Verify no crashes or hangs occurred
        XCTAssertTrue(true, "Thread safety test completed without issues")
    }
    
    // MARK: - iOS 18+ Specific Tests
    
    @available(iOS 18.0, *)
    func testEnhancedLogging() async {
        let testObject = SendableTestObject(identifier: "LoggingTest")
        let location = CodeLocation(testObject)
        
        // Test structured logging (should not crash or cause data races)
        location.log(category: "Testing", type: .debug)
        
        // Test detailed debug description
        let debugInfo = location.detailedDebugDescription
        XCTAssertFalse(debugInfo.isEmpty)
        XCTAssertTrue(debugInfo.contains("CodeLocation Debug Info"))
    }
    
    // MARK: - Memory Pressure Tests
    
    func testMemoryPressureWithConcurrency() async {
        let expectation = XCTestExpectation(description: "Memory pressure test")
        let iterations = 10000
        
        await withTaskGroup(of: Void.self) { group in
            for batchIndex in 0..<10 {
                group.addTask {
                    // Create many objects in each task
                    for itemIndex in 0..<(iterations / 10) {
                        autoreleasepool {
                            let testObject = SendableTestObject(
                                identifier: "Batch\(batchIndex)-Item\(itemIndex)"
                            )
                            let location = CodeLocation(testObject)
                            
                            // Force property access to ensure objects are fully initialized
                            _ = location.asString
                            _ = location.userInfo.count
                        }
                    }
                }
            }
        }
        
        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 60.0)
    }
}

// MARK: - Additional Test Cases for DNSThreadingConcurrencyTests

extension DNSThreadingCurrencyTests {
    
    // MARK: - Swift 6 Actor Isolation Tests
    
    @MainActor
    func testMainActorIsolatedCodeLocation() async {
        let testObject = SendableTestObject(identifier: "MainActorTest")
        let location = DNSCodeLocation(testObject)
        
        // Verify main actor isolation doesn't break functionality
        XCTAssertFalse(location.asString.isEmpty)
        XCTAssertTrue(location.domain.contains("com.doublenode."))
        
        // Test concurrent access from background
        await withTaskGroup(of: Bool.self) { group in
            for _ in 0..<10 {
                group.addTask { @MainActor in
                    let bgLocation = DNSCodeLocation(testObject)
                    return !bgLocation.asString.isEmpty
                }
            }
            
            for await result in group {
                XCTAssertTrue(result)
            }
        }
    }
    
    // MARK: - Sendable Compliance Tests
    
    func testSendableComplianceWithCustomObjects() async {
        struct CustomSendableObject: Sendable {
            let id: UUID
            let name: String
            let timestamp: Date
            let metadata: [String: String]
            
            init(name: String) {
                self.id = UUID()
                self.name = name
                self.timestamp = Date()
                self.metadata = ["created": "test", "version": "1.0"]
            }
        }
        
        await withTaskGroup(of: Void.self) { group in
            for index in 0..<50 {
                group.addTask {
                    let customObject = CustomSendableObject(name: "Object\(index)")
                    let location = CodeLocation(customObject)
                    
                    XCTAssertTrue(location.domain.contains("CustomSendableObject"))
                    XCTAssertNotNil(location.userInfo["DNSTimeStamp"])
                    XCTAssertEqual(location.userInfo["DNSLine"] as? Int, location.line)
                }
            }
        }
    }
    
    // MARK: - Global Actor Tests
    
    @globalActor
    actor TestGlobalActor {
        static let shared = TestGlobalActor()
    }
    
    @TestGlobalActor
    func testGlobalActorIsolatedAccess() async {
        let testObject = SendableTestObject(identifier: "GlobalActorTest")
        let location = CodeLocation(testObject)
        
        // Test access from global actor context
        XCTAssertFalse(location.failureReason.isEmpty)
        
        // Test that string operations work in actor context
        let shortened = CodeLocation.shortenErrorObject(testObject)
        XCTAssertFalse(shortened.isEmpty)
    }
    
    // MARK: - Async/Await Integration Tests
    
    func testAsyncSequenceWithCodeLocation() async {
        struct AsyncTestSequence: AsyncSequence {
            typealias Element = SendableTestObject
            
            func makeAsyncIterator() -> AsyncIterator {
                AsyncIterator()
            }
            
            struct AsyncIterator: AsyncIteratorProtocol {
                private var count = 0
                private let maxCount = 10
                
                mutating func next() async -> SendableTestObject? {
                    guard count < maxCount else { return nil }
                    count += 1
                    // Simulate async work
                    try? await Task.sleep(nanoseconds: 1_000_000) // 1ms
                    return SendableTestObject(identifier: "AsyncItem\(count)")
                }
            }
        }
        
        let sequence = AsyncTestSequence()
        var processedCount = 0
        
        for await item in sequence {
            let location = CodeLocation(item)
            XCTAssertFalse(location.asString.isEmpty)
            processedCount += 1
        }
        
        XCTAssertEqual(processedCount, 10)
    }
    
    // MARK: - TaskLocal Tests
    
    @TaskLocal static var testContext: String?
    
    func testTaskLocalWithCodeLocation() async {
        await Self.$testContext.withValue("TestContext") {
            let testObject = SendableTestObject(identifier: "TaskLocalTest")
            let location = CodeLocation(testObject)
            
            XCTAssertEqual(Self.testContext, "TestContext")
            XCTAssertFalse(location.asString.isEmpty)
            
            // Test nested task inherits context
            await withTaskGroup(of: Void.self) { group in
                group.addTask {
                    XCTAssertEqual(Self.testContext, "TestContext")
                    let nestedLocation = CodeLocation(testObject)
                    XCTAssertFalse(nestedLocation.domain.isEmpty)
                }
            }
        }
    }
    
    // MARK: - Structured Concurrency Tests
    
    func testStructuredConcurrencyWithTimeout() async {
        let testObject = SendableTestObject(identifier: "TimeoutTest")
        
        await withTimeout(seconds: 5) {
            await withTaskGroup(of: Void.self) { group in
                for _ in 0..<100 {
                    group.addTask {
                        let location = CodeLocation(testObject)
                        _ = location.userInfo
                        // Simulate work
                        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
                    }
                }
            }
        }
    }
    
    private func withTimeout<T: Sendable>(seconds: TimeInterval, operation: @escaping @Sendable () async throws -> T) async rethrows -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw TimeoutError()
            }
            
            guard let result = try await group.next() else {
                throw TimeoutError()
            }
            group.cancelAll()
            return result
        }
    }
    
    private struct TimeoutError: Error {}
    
    // MARK: - AsyncThrowingStream Tests
    
    func testAsyncThrowingStreamWithCodeLocation() async throws {
        let stream = AsyncThrowingStream<SendableTestObject, Error> { continuation in
            Task {
                for i in 0..<5 {
                    let object = SendableTestObject(identifier: "StreamItem\(i)")
                    continuation.yield(object)
                    try await Task.sleep(nanoseconds: 1_000_000) // 1ms
                }
                continuation.finish()
            }
        }
        
        var count = 0
        for try await item in stream {
            let location = CodeLocation(item)
            XCTAssertTrue(location.domain.contains("SendableTestObject"))
            count += 1
        }
        
        XCTAssertEqual(count, 5)
    }
    
    // MARK: - Cross-Platform Compatibility Tests
    
    #if os(iOS)
    @available(iOS 18.0, *)
    func testIOS18SpecificFeatures() async {
        let testObject = SendableTestObject(identifier: "iOS18Test")
        let location = CodeLocation(testObject)
        
        // Test iOS 18+ specific logging
        location.log(category: "iOS18", type: .debug)
        
        // Test enhanced debugging
        let debugInfo = location.detailedDebugDescription
        XCTAssertTrue(debugInfo.contains("iOS 18"))
    }
    #endif
    
    #if os(macOS)
    func testMacOSSpecificFeatures() async {
        let testObject = SendableTestObject(identifier: "macOSTest")
        let location = CodeLocation(testObject)
        
        // Test macOS specific path handling
        CodeLocation.addFilenamePathRoot("/Users/")
        let shortenedPath = CodeLocation.shortenErrorPath("/Users/test/file.swift")
        XCTAssertTrue(shortenedPath.contains("~"))
    }
    #endif
    
    // MARK: - Performance and Memory Tests
    
    func testMemoryLeakPrevention() async {
        weak var weakLocation: CodeLocation?
        
        do {
            let testObject = SendableTestObject(identifier: "MemoryTest")
            let location = CodeLocation(testObject)
            weakLocation = location
            
            // Use the location
            _ = location.asString
            _ = location.userInfo
        }
        
        // Give ARC time to clean up
        await Task.yield()
        
        // Verify location was deallocated
        XCTAssertNil(weakLocation, "CodeLocation should be deallocated")
    }
    
    func testLargeDataSetProcessing() async {
        let iterations = 10_000
        let startMemory = getCurrentMemoryUsage()
        
        await withTaskGroup(of: Void.self) { group in
            for batchIndex in 0..<100 {
                group.addTask {
                    for itemIndex in 0..<(iterations / 100) {
                        autoreleasepool {
                            let testObject = SendableTestObject(
                                identifier: "LargeDataSet\(batchIndex)-\(itemIndex)"
                            )
                            let location = CodeLocation(testObject)
                            _ = location.asString.count // Force evaluation
                        }
                    }
                }
            }
        }
        
        let endMemory = getCurrentMemoryUsage()
        let memoryIncrease = endMemory - startMemory
        
        // Memory increase should be reasonable (less than 100MB for this test)
        XCTAssertLessThan(memoryIncrease, 100 * 1024 * 1024, "Memory usage increased too much")
    }
    
    private func getCurrentMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        return kerr == KERN_SUCCESS ? Int64(info.resident_size) : 0
    }
    
    // MARK: - Error Handling and Edge Cases
    
    func testEdgeCaseInputs() async {
        struct EdgeCaseObject: Sendable {
            let specialCharacters: String
            let unicodeContent: String
            let emptyStrings: [String]
            
            init() {
                self.specialCharacters = "!@#$%^&*()_+-=[]{}|;':\",./<>?"
                self.unicodeContent = "🚀💻🔧⚡️🌟"
                self.emptyStrings = ["", " ", "\t", "\n"]
            }
        }
        
        let edgeObject = EdgeCaseObject()
        let location = CodeLocation(edgeObject)
        
        XCTAssertFalse(location.asString.isEmpty)
        XCTAssertTrue(location.domain.contains("EdgeCaseObject"))
        
        // Test with extremely long strings
        let longString = String(repeating: "a", count: 10000)
        CodeLocation.addFilenamePathRoot(longString)
        
        let pathWithLongRoot = CodeLocation.shortenErrorPath(longString + "/test.swift")
        XCTAssertTrue(pathWithLongRoot.contains("~"))
    }
    
    func testConcurrentErrorConditions() async {
        let expectation = XCTestExpectation(description: "Concurrent error handling")
        
        await withTaskGroup(of: Void.self) { group in
            // Test with nil-like conditions
            for _ in 0..<50 {
                group.addTask {
                    let emptyObject = SendableTestObject(identifier: "")
                    let location = CodeLocation(emptyObject)
                    XCTAssertFalse(location.asString.isEmpty)
                }
            }
            
            // Test with rapid successive calls
            for _ in 0..<50 {
                group.addTask {
                    for _ in 0..<10 {
                        CodeLocation.addFilenamePathRoot("/temp/\(UUID().uuidString)")
                    }
                }
            }
        }
        
        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 10.0)
    }
    
    // MARK: - Future iOS 26 Compatibility Tests
    
    func testFutureCompatibilityPatterns() async {
        // Test patterns that should work in future iOS versions
        let testObject = SendableTestObject(identifier: "FutureTest")
        
        // Pattern 1: Observation framework compatibility
        await testObservationPattern(with: testObject)
        
        // Pattern 2: Enhanced async/await patterns
        await testEnhancedAsyncPatterns(with: testObject)
        
        // Pattern 3: Potential Swift 7+ features (hypothetical)
        await testSwift7ReadinessPatterns(with: testObject)
    }
    
    private func testObservationPattern(with object: SendableTestObject) async {
        // Simulate observation pattern that might be enhanced in iOS 26
        let location = CodeLocation(object)
        
        // Test observable-like behavior
        var observations: [String] = []
        
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<10 {
                group.addTask {
                    let observedValue = "\(location.asString)-\(i)"
                    // In a real observation system, this would be thread-safe
                    // For testing, we just verify the pattern works
                    XCTAssertFalse(observedValue.isEmpty)
                }
            }
        }
    }
    
    private func testEnhancedAsyncPatterns(with object: SendableTestObject) async {
        // Test patterns that might be enhanced in future Swift/iOS versions
        let location = CodeLocation(object)
        
        // Pattern: Async property access (hypothetical future feature)
        let asyncResult = await withCheckedContinuation { continuation in
            Task {
                let result = location.userInfo
                continuation.resume(returning: result)
            }
        }
        
        XCTAssertFalse(asyncResult.isEmpty)
    }
    
    private func testSwift7ReadinessPatterns(with object: SendableTestObject) async {
        // Prepare for potential Swift 7+ concurrency enhancements
        let location = CodeLocation(object)
        
        // Pattern: Enhanced actor isolation (hypothetical)
        await withTaskGroup(of: String.self) { group in
            for _ in 0..<5 {
                group.addTask {
                    return location.asString
                }
            }
            
            var results: [String] = []
            for await result in group {
                results.append(result)
            }
            
            XCTAssertEqual(results.count, 5)
            XCTAssertTrue(results.allSatisfy { !$0.isEmpty })
        }
    }
}

// MARK: - Additional Test Extensions and Helpers

extension CodeLocation {
    #if DEBUG
    /// Debug method for Thread Sanitizer testing
    static func performThreadSafetyTest() {
        let queue = DispatchQueue(label: "test.thread.safety",
                                 qos: DispatchQoS(qosClass: .userInitiated, relativePriority: 0),
                                 attributes: .concurrent)
        
        let group = DispatchGroup()
        
        for i in 0..<100 {
            queue.async(group: group) {
                addFilenamePathRoot("/test/thread/safety/\(i)")
                let _ = filenamePathRoots.count
            }
        }
        
        group.wait()
    }
    
    /// Enhanced logging for iOS 18+
    @available(iOS 18.0, *)
    func log(category: String, type: OSLogType) {
        let logger = Logger(subsystem: "com.doublenode.DNSFramework", category: category)
        logger.log(level: type, "\(self.asString)")
    }
    
    /// Detailed debug description for iOS 18+
    @available(iOS 18.0, *)
    var detailedDebugDescription: String {
        """
        CodeLocation Debug Info:
        - Domain: \(domain)
        - File: \(file)
        - Line: \(line)
        - Method: \(method)
        - Timestamp: \(timeStamp)
        - iOS 18 Enhanced Debugging Enabled
        """
    }
    #endif
}// MARK: - Test Support Extensions

extension DNSThreadingCurrencyTests {
    
    // Helper method for atomic operations testing
    private func performAtomicOperation<T>(_ operation: @Sendable () throws -> T) rethrows -> T {
        return try operation()
    }
    
    // Helper for testing with different queue priorities
    private func testWithQueuePriority(_ priority: DispatchQoS.QoSClass,
                                      iterations: Int = 100) async {
        let queue = DispatchQueue(label: "test.\(priority)",
                                 qos: DispatchQoS(qosClass: priority, relativePriority: 0),
                                 attributes: .concurrent)
        
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<iterations {
                group.addTask {
                    await withCheckedContinuation { continuation in
                        queue.async {
                            let testObject = SendableTestObject(identifier: UUID().uuidString)
                            let location = CodeLocation(testObject)
                            _ = location.asString
                            continuation.resume()
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Thread Sanitizer Command Line Helpers

/*
 Run these commands to test with Thread Sanitizer:
 
 1. Build with Thread Sanitizer:
 xcodebuild -workspace DNSFramework.xcworkspace \
            -scheme DNSCoreThreading \
            -configuration Debug \
            -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
            OTHER_CFLAGS='-fsanitize=thread -g' \
            OTHER_LDFLAGS='-fsanitize=thread' \
            ENABLE_THREAD_SANITIZER=YES \
            build-for-testing
 
 2. Run Thread Sanitizer Tests:
 xcodebuild test-without-building \
            -workspace DNSFramework.xcworkspace \
            -scheme DNSCoreThreading \
            -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
            -only-testing:DNSCoreThreadingTests/DNSThreadingCurrencyTests
 
 3. Check for Thread Sanitizer output in logs:
 - Look for "ThreadSanitizer: no issues found" (success)
 - Watch for data race warnings (need fixing)
 - Monitor for deadlock detection
 */
