//
//  DNSSemaphoreTests.swift
//  DoubleNode Swift Framework (DNSFramework) - DNSCoreThreadingTests
//
//  Created by Darren Ehlers.
//  Copyright © 2020 - 2016 DoubleNode.com. All rights reserved.
//

import XCTest
import Foundation
import os.lock

@testable import DNSCoreThreading

final class DNSSemaphoreTests: XCTestCase {
    private var sut: DNSSemaphore!

    override func setUp() {
        super.setUp()
        sut = DNSSemaphore()
    }
    
    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Basic Functionality Tests
    
    func testInitialization() {
        // Test default initialization
        let defaultSemaphore = DNSSemaphore()
        XCTAssertNotNil(defaultSemaphore)
        
        // Test initialization with specific count
        let countSemaphore = DNSSemaphore(count: 5)
        XCTAssertNotNil(countSemaphore)
    }
    
    func testBasicWaitAndSignal() {
        // Initialize with count of 1 so wait() doesn't block
        let semaphore = DNSSemaphore(count: 1)
        
        // Should be able to wait once
        let result = semaphore.wait()
        XCTAssertEqual(result, .success)
        
        // Signal should return a value
        let signalResult = semaphore.done()
        XCTAssertGreaterThanOrEqual(signalResult, 0)
    }
    
    func testWaitWithTimeout() {
        // Initialize with count 0 so wait will timeout
        let semaphore = DNSSemaphore(count: 0)
        
        let timeout = DispatchTime.now() + .milliseconds(100)
        let result = semaphore.wait(until: timeout)
        
        XCTAssertEqual(result, .timedOut)
    }
    
    // MARK: - Concurrency Tests
    
    func testConcurrentAccess() async {
        let semaphore = DNSSemaphore(count: 3) // Allow 3 concurrent accesses
        let completedTasks = OSAllocatedUnfairLock(initialState: 0)
        let expectation = XCTestExpectation(description: "Concurrent access test")
        
        await withTaskGroup(of: Void.self) { group in
            // Launch 10 tasks that will compete for 3 semaphore slots
            for _ in 0..<10 {
                group.addTask {
                    let waitResult = semaphore.wait()
                    XCTAssertEqual(waitResult, .success)
                    
                    // Simulate work
                    try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
                    
                    // Signal completion
                    semaphore.done()
                    
                    completedTasks.withLock { $0 += 1 }
                }
            }
        }
        
        let finalCount = completedTasks.withLock { $0 }
        XCTAssertEqual(finalCount, 10)
        expectation.fulfill()
        
        await fulfillment(of: [expectation], timeout: 5.0)
    }
    
    func testSemaphoreAsResourceGate() async {
        let maxConcurrentOperations = 2
        let semaphore = DNSSemaphore(count: maxConcurrentOperations)
        let activeOperations = OSAllocatedUnfairLock(initialState: 0)
        let maxActiveOperations = OSAllocatedUnfairLock(initialState: 0)
        
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<10 {
                group.addTask {
                    // Acquire semaphore
                    let waitResult = semaphore.wait()
                    XCTAssertEqual(waitResult, .success)
                    
                    // Track active operations
                    let currentActive = activeOperations.withLock { count in
                        count += 1
                        return count
                    }
                    
                    // Update max if necessary
                    maxActiveOperations.withLock { max in
                        if currentActive > max {
                            max = currentActive
                        }
                    }
                    
                    // Simulate resource-intensive work
                    try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
                    
                    // Release resource
                    activeOperations.withLock { $0 -= 1 }
                    semaphore.done()
                }
            }
        }
        
        let maxReached = maxActiveOperations.withLock { $0 }
        XCTAssertLessThanOrEqual(maxReached, maxConcurrentOperations)
    }
    
    // MARK: - Stress Tests
    
    func testHighFrequencyWaitSignal() async {
        let semaphore = DNSSemaphore(count: 1)
        let iterations = 1000
        let completedOperations = OSAllocatedUnfairLock(initialState: 0)
        
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<iterations {
                group.addTask {
                    let waitResult = semaphore.wait()
                    XCTAssertEqual(waitResult, .success)
                    
                    // Minimal work to test rapid cycling
                    let _ = Date().timeIntervalSince1970
                    
                    semaphore.done()
                    completedOperations.withLock { $0 += 1 }
                }
            }
        }
        
        let finalCount = completedOperations.withLock { $0 }
        XCTAssertEqual(finalCount, iterations)
    }
    
    func testSemaphoreUnderMemoryPressure() async {
        let iterations = 10000
        let semaphore = DNSSemaphore(count: 10)
        
        await withTaskGroup(of: Void.self) { group in
            for batchIndex in 0..<100 {
                group.addTask {
                    for itemIndex in 0..<(iterations / 100) {
                        autoreleasepool {
                            let waitResult = semaphore.wait()
                            XCTAssertEqual(waitResult, .success)
                            
                            // Create some memory pressure
                            let tempData = Array(0..<1000).map { "Item\(batchIndex)-\($0)-\(itemIndex)" }
                            XCTAssertEqual(tempData.count, 1000)
                            
                            semaphore.done()
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Edge Cases
    
    func testZeroCountSemaphore() {
        let semaphore = DNSSemaphore(count: 0)
        
        // Should timeout immediately
        let timeout = DispatchTime.now() + .milliseconds(1)
        let result = semaphore.wait(until: timeout)
        XCTAssertEqual(result, .timedOut)
        
        // After signal, should be able to wait
        semaphore.done()
        let waitResult = semaphore.wait(until: DispatchTime.now() + .milliseconds(100))
        XCTAssertEqual(waitResult, .success)
        // Balance the semaphore by calling done() for the successful wait
        semaphore.done()
    }
    
    func testLargeCountSemaphore() async {
        let largeCount = 1000
        let semaphore = DNSSemaphore(count: largeCount)
        
        await withTaskGroup(of: Void.self) { group in
            // Should be able to acquire all 1000 slots quickly
            for _ in 0..<largeCount {
                group.addTask {
                    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                        DispatchQueue.global().async {
                            let result = semaphore.wait()
                            XCTAssertEqual(result, .success)
                            // Immediately release to maintain balance
                            semaphore.done()
                            continuation.resume()
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Sendable Compliance Tests
    
    func testSendableComplianceAcrossActors() async {
        actor SemaphoreTestActor {
            private let semaphore: DNSSemaphore
            
            init(semaphore: DNSSemaphore) {
                self.semaphore = semaphore
            }
            
            func performWork() async -> DispatchTimeoutResult {
                // Use async-compatible approach
                return await withCheckedContinuation { continuation in
                    DispatchQueue.global().async {
                        let result = self.semaphore.wait()
                        // Simulate work
                        Thread.sleep(forTimeInterval: 0.01) // 10ms
                        self.semaphore.done()
                        continuation.resume(returning: result)
                    }
                }
            }
        }
        
        let semaphore = DNSSemaphore(count: 2)
        let actor1 = SemaphoreTestActor(semaphore: semaphore)
        let actor2 = SemaphoreTestActor(semaphore: semaphore)
        
        async let result1 = actor1.performWork()
        async let result2 = actor2.performWork()
        
        let (r1, r2) = await (result1, result2)
        XCTAssertEqual(r1, .success)
        XCTAssertEqual(r2, .success)
    }
}

// MARK: - DNSSemaphoreGate Tests

extension DNSSemaphoreTests {
    
    func testSemaphoreGateInitialization() async {
        // Test default initialization (should have count 0)
        let defaultGate = DNSSemaphoreGate()
        XCTAssertNotNil(defaultGate)
        
        // Should timeout immediately since default count is 0
        let timeout = DispatchTime.now() + .milliseconds(1)
        let result = await withCheckedContinuation { (continuation: CheckedContinuation<DispatchTimeoutResult, Never>) in
            DispatchQueue.global().async {
                let timeoutResult = defaultGate.wait(until: timeout)
                continuation.resume(returning: timeoutResult)
            }
        }
        XCTAssertEqual(result, .timedOut)
        
        // Test initialization with specific count
        let countGate = DNSSemaphoreGate(count: 3)
        XCTAssertNotNil(countGate)
        
        // Should be able to wait since count > 0
        let waitResult = await withCheckedContinuation { (continuation: CheckedContinuation<DispatchTimeoutResult, Never>) in
            DispatchQueue.global().async {
                let timeout = DispatchTime.now() + .milliseconds(100)
                let result = countGate.wait(until: timeout)
                // Only call done() if wait was successful to maintain semaphore balance
                if result == .success {
                    countGate.done()
                }
                continuation.resume(returning: result)
            }
        }
        XCTAssertEqual(waitResult, .success)
    }
    
    func testSemaphoreGateAsCoordinationMechanism() async {
        let gate = DNSSemaphoreGate()
        let coordinatedTasks = OSAllocatedUnfairLock(initialState: 0)
        let expectation = XCTestExpectation(description: "Gate coordination test")
        
        await withTaskGroup(of: Void.self) { group in
            // Launch tasks that wait for the gate to open
            for _ in 0..<5 {
                group.addTask {
                    let waitResult = gate.wait()
                    XCTAssertEqual(waitResult, .success)
                    
                    coordinatedTasks.withLock { $0 += 1 }
                }
            }
            
            // Open the gate after a delay
            group.addTask {
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
                
                // Open gate for all waiting tasks
                for _ in 0..<5 {
                    gate.done()
                }
            }
        }
        
        let finalCount = coordinatedTasks.withLock { $0 }
        XCTAssertEqual(finalCount, 5)
        expectation.fulfill()
        
        await fulfillment(of: [expectation], timeout: 5.0)
    }
    
    func testSemaphoreGateSequentialAccess() async {
        let gate = DNSSemaphoreGate(count: 1) // Allow only one at a time
        let accessOrder = OSAllocatedUnfairLock(initialState: [Int]())
        let currentlyAccessing = OSAllocatedUnfairLock(initialState: false)
        
        await withTaskGroup(of: Void.self) { group in
            for taskIndex in 0..<10 {
                group.addTask {
                    let waitResult = gate.wait()
                    XCTAssertEqual(waitResult, .success)
                    
                    // Verify exclusive access
                    let wasAlreadyAccessing = currentlyAccessing.withLock { accessing in
                        if accessing {
                            return true // Someone else is accessing - this is bad!
                        }
                        accessing = true
                        return false
                    }
                    
                    XCTAssertFalse(wasAlreadyAccessing, "Multiple tasks accessing critical section")
                    
                    // Record access order
                    accessOrder.withLock { $0.append(taskIndex) }
                    
                    // Simulate critical section work
                    try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
                    
                    // Release exclusive access
                    currentlyAccessing.withLock { $0 = false }
                    gate.done()
                }
            }
        }
        
        let finalOrder = accessOrder.withLock { $0 }
        XCTAssertEqual(finalOrder.count, 10)
        XCTAssertTrue(finalOrder.allSatisfy { $0 >= 0 && $0 < 10 })
    }
}

// MARK: - Performance and Benchmarking Tests

extension DNSSemaphoreTests {
    
    func testSemaphorePerformance() async {
        let semaphore = DNSSemaphore(count: 100)
        let iterations = 10000
        let startTime = DispatchTime.now()
        
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<iterations {
                group.addTask {
                    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                        DispatchQueue.global().async {
                            let waitResult = semaphore.wait()
                            XCTAssertEqual(waitResult, .success)
                            semaphore.done()
                            continuation.resume()
                        }
                    }
                }
            }
        }
        
        let endTime = DispatchTime.now()
        let elapsedNanoseconds = endTime.uptimeNanoseconds - startTime.uptimeNanoseconds
        let elapsedMilliseconds = Double(elapsedNanoseconds) / 1_000_000.0
        
        // Performance should be reasonable (less than 5 seconds for 10k operations)
        XCTAssertLessThan(elapsedMilliseconds, 5000.0, "Semaphore operations took too long: \(elapsedMilliseconds)ms")
        
        print("DNSSemaphore performance: \(iterations) operations completed in \(elapsedMilliseconds)ms")
    }
    
    func testSemaphoreVsDispatchSemaphorePerformance() async {
        let iterations = 1000
        
        // Test DNSSemaphore
        let dnsSemaphore = DNSSemaphore(count: 10)
        let dnsStartTime = DispatchTime.now()
        
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<iterations {
                group.addTask {
                    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                        DispatchQueue.global().async {
                            let _ = dnsSemaphore.wait()
                            dnsSemaphore.done()
                            continuation.resume()
                        }
                    }
                }
            }
        }
        
        let dnsEndTime = DispatchTime.now()
        let dnsElapsed = Double(dnsEndTime.uptimeNanoseconds - dnsStartTime.uptimeNanoseconds) / 1_000_000.0
        
        // Test raw DispatchSemaphore
        let dispatchSemaphore = DispatchSemaphore(value: 10)
        let dispatchStartTime = DispatchTime.now()
        
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<iterations {
                group.addTask {
                    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                        DispatchQueue.global().async {
                            let _ = dispatchSemaphore.wait()
                            dispatchSemaphore.signal()
                            continuation.resume()
                        }
                    }
                }
            }
        }
        
        let dispatchEndTime = DispatchTime.now()
        let dispatchElapsed = Double(dispatchEndTime.uptimeNanoseconds - dispatchStartTime.uptimeNanoseconds) / 1_000_000.0
        
        // DNSSemaphore should be within reasonable overhead of raw DispatchSemaphore
        let overhead = (dnsElapsed / dispatchElapsed) - 1.0
        XCTAssertLessThan(overhead, 2.0, "DNSSemaphore has too much overhead: \(overhead * 100)%")
        
        print("DNSSemaphore: \(dnsElapsed)ms, DispatchSemaphore: \(dispatchElapsed)ms, Overhead: \(overhead * 100)%")
    }
}

// MARK: - Thread Sanitizer Validation

extension DNSSemaphoreTests {
    
    func testThreadSanitizerCompliance() async {
        // This test is specifically designed to catch data races with Thread Sanitizer
        let semaphore = DNSSemaphore(count: 5)
        let sharedCounter = OSAllocatedUnfairLock(initialState: 0)
        let iterations = 1000
        
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<iterations {
                group.addTask {
                    // Use async-compatible semaphore operations
                    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                        DispatchQueue.global().async {
                            // Acquire semaphore
                            let waitResult = semaphore.wait()
                            XCTAssertEqual(waitResult, .success)
                            
                            // Critical section - modify shared state
                            sharedCounter.withLock { counter in
                                let temp = counter
                                // Simulate race condition opportunity
                                Thread.sleep(forTimeInterval: 0.0001) // 0.1ms
                                counter = temp + 1
                            }
                            
                            // Release semaphore
                            semaphore.done()
                            continuation.resume()
                        }
                    }
                }
            }
        }
        
        let finalCount = sharedCounter.withLock { $0 }
        XCTAssertEqual(finalCount, iterations, "Race condition detected - expected \(iterations), got \(finalCount)")
    }
}

/*
 MARK: - Thread Sanitizer Testing Commands
 
 To run these tests with Thread Sanitizer:
 
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
            -only-testing:DNSCoreThreadingTests/DNSSemaphoreTests
 
 3. Monitor for Thread Sanitizer output:
 - "ThreadSanitizer: no issues found" = Success
 - Watch for data race warnings
 - Check for deadlock detection
 */
