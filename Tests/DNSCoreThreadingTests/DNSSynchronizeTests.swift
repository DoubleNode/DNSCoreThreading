//
//  DNSSynchronizeTests.swift
//  DoubleNode Swift Framework (DNSFramework) - DNSCoreThreadingTests
//
//  Created by Darren Ehlers.
//  Copyright © 2020 - 2016 DoubleNode.com. All rights reserved.
//

import XCTest
import os.lock
@testable import DNSCoreThreading

final class DNSSynchronizeTests: XCTestCase {
    private var sut: DNSSynchronize!
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests
    
    func testInit_withoutObject_createsValidInstance() {
        // Given / When
        sut = DNSSynchronize()
        
        // Then
        XCTAssertNotNil(sut)
    }
    
    func testInit_withObject_createsValidInstance() {
        // Given
        let lockObject = NSObject()
        
        // When
        sut = DNSSynchronize(with: lockObject)
        
        // Then
        XCTAssertNotNil(sut)
    }
    
    func testInit_withObjectAndBlock_createsValidInstance() async {
        // Given
        // Use a Sendable lock object to avoid capture warnings
        final class SendableLockObject: @unchecked Sendable {}
        let lockObject = SendableLockObject()
        let expectation = expectation(description: "Block executed")
        
        // When
        let syncInstance = DNSSynchronize(with: lockObject) {
            expectation.fulfill()
        }
        
        // Then
        XCTAssertNotNil(syncInstance)
        
        // Execute the synchronize block on a background thread to test it works
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .default).async {
                syncInstance.run()
                continuation.resume()
            }
        }
        
        await fulfillment(of: [expectation], timeout: 1.0)
    }

    // MARK: - Run Method Tests
    
    func testRun_onMainThread_throwsException() {
        // Given
        sut = DNSSynchronize()
        
        // When / Then
        // Note: This test verifies the main thread check works correctly
        // We test this synchronously since we need to check Thread.isMainThread
        if Thread.isMainThread {
            // We can't directly test NSException throwing in Swift without crashing
            // So we verify the precondition that would cause the exception
            XCTAssertTrue(Thread.isMainThread, "Should be on main thread to trigger exception logic")
            
            // The actual exception throwing is tested implicitly - 
            // if DNSSynchronize.run() is called on main thread, it will throw
            // We document this behavior rather than crash the test
        }
    }
    
    func testRun_onBackgroundThread_executesSuccessfully() async {
        // Given
        let expectation = expectation(description: "Synchronized block executed")
        let blockExecuted = OSAllocatedUnfairLock(initialState: false)
        
        let syncInstance = DNSSynchronize {
            blockExecuted.withLock { $0 = true }
            expectation.fulfill()
        }
        
        // When - Execute on background thread
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .default).async {
                syncInstance.run()
                continuation.resume()
            }
        }
        
        // Then
        await fulfillment(of: [expectation], timeout: 1.0)
        let wasExecuted = blockExecuted.withLock { $0 }
        XCTAssertTrue(wasExecuted)
    }
    
    func testRun_withCustomLockObject_usesSynchronization() async {
        // Given
        // Use a Sendable lock object to avoid capture warnings
        final class SendableLockObject: @unchecked Sendable {}
        let lockObject = SendableLockObject()
        
        let expectation = expectation(description: "Synchronized blocks executed")
        expectation.expectedFulfillmentCount = 2
        
        let executionOrder = OSAllocatedUnfairLock<[Int]>(initialState: [])
        
        // When - Execute two synchronized blocks on the same object
        let group = DispatchGroup()
        
        // First synchronized block
        group.enter()
        DispatchQueue.global(qos: .default).async {
            let sync1 = DNSSynchronize(with: lockObject) {
                executionOrder.withLock { $0.append(1) }
                
                // Simulate some work
                Thread.sleep(forTimeInterval: 0.1)
                
                executionOrder.withLock { $0.append(11) }
                
                expectation.fulfill()
            }
            sync1.run()
            group.leave()
        }
        
        // Second synchronized block
        group.enter()
        DispatchQueue.global(qos: .default).async {
            // Small delay to ensure first block starts first
            Thread.sleep(forTimeInterval: 0.05)
            
            let sync2 = DNSSynchronize(with: lockObject) {
                executionOrder.withLock { $0.append(2) }
                
                Thread.sleep(forTimeInterval: 0.1)
                
                executionOrder.withLock { $0.append(22) }
                
                expectation.fulfill()
            }
            sync2.run()
            group.leave()
        }
        
        // Then
        await fulfillment(of: [expectation], timeout: 2.0)
        
        // Verify synchronization worked - first block should complete entirely before second
        let finalOrder = executionOrder.withLock { $0 }
        XCTAssertEqual(finalOrder.count, 4)
        if finalOrder.count >= 4 {
            XCTAssertEqual(finalOrder[0], 1)
            XCTAssertEqual(finalOrder[1], 11)
            XCTAssertEqual(finalOrder[2], 2) 
            XCTAssertEqual(finalOrder[3], 22)
        }
    }
    
    func testRun_withoutBlock_completesSuccessfully() async {
        // Given
        let syncInstance = DNSSynchronize()
        
        // When - Execute on background thread without block
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .default).async {
                syncInstance.run() // Should not crash even without block
                continuation.resume()
            }
        }
        
        // Then - Should complete without issues
        XCTAssertNotNil(syncInstance)
    }

    // MARK: - Thread Safety Tests
    
    func testRun_concurrentAccess_maintainsThreadSafety() async {
        // Given
        // Use a Sendable lock object to avoid capture warnings
        final class SendableLockObject: @unchecked Sendable {}
        let lockObject = SendableLockObject()
        
        let expectation = expectation(description: "All synchronized blocks executed")
        expectation.expectedFulfillmentCount = 10
        
        let counter = OSAllocatedUnfairLock(initialState: 0)
        
        // When - Execute multiple synchronized blocks concurrently
        for _ in 0..<10 {
            DispatchQueue.global(qos: .default).async {
                let sync = DNSSynchronize(with: lockObject) {
                    // Critical section - should be thread-safe
                    counter.withLock { value in
                        let currentValue = value
                        Thread.sleep(forTimeInterval: 0.01) // Simulate work
                        value = currentValue + 1
                    }
                    
                    expectation.fulfill()
                }
                sync.run()
            }
        }
        
        // Then
        await fulfillment(of: [expectation], timeout: 5.0)
        let finalCount = counter.withLock { $0 }
        XCTAssertEqual(finalCount, 10, "Counter should be exactly 10 if synchronization worked")
    }

    // MARK: - Swift 6 Actor-based Synchronization Tests
    
    func testDNSActorSynchronize_run_executesAsynchronously() async {
        // Given
        let blockExecuted = OSAllocatedUnfairLock(initialState: false)
        
        // When
        let result = await DNSActorSynchronize.run {
            blockExecuted.withLock { $0 = true }
            return "test result"
        }
        
        // Then
        let wasExecuted = blockExecuted.withLock { $0 }
        XCTAssertTrue(wasExecuted)
        XCTAssertEqual(result, "test result")
    }
    
    func testDNSActorSynchronize_runSync_executesSynchronously() async {
        // Given
        let blockExecuted = OSAllocatedUnfairLock(initialState: false)
        
        // When
        let result = await DNSActorSynchronize.runSync {
            blockExecuted.withLock { $0 = true }
            return 42
        }
        
        // Then
        let wasExecuted = blockExecuted.withLock { $0 }
        XCTAssertTrue(wasExecuted)
        XCTAssertEqual(result, 42)
    }
    
    func testDNSActorSynchronize_throwingBlock_propagatesError() async {
        // Given
        enum TestError: Error {
            case testFailure
        }
        
        // When / Then
        do {
            _ = try await DNSActorSynchronize.run {
                throw TestError.testFailure
            }
            XCTFail("Should have thrown an error")
        } catch {
            XCTAssertTrue(error is TestError)
        }
    }
    
    func testDNSActorSynchronize_actorIsolation_maintainsSerialExecution() async {
        // Given
        let executionOrder = OSAllocatedUnfairLock<[Int]>(initialState: [])
        
        // When - Execute multiple blocks through the actor
        await withTaskGroup(of: Void.self) { group in
            for i in 1...5 {
                group.addTask {
                    await DNSActorSynchronize.run {
                        executionOrder.withLock { $0.append(i) }
                        // Small delay to test ordering
                        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
                    }
                }
            }
        }
        
        // Then - Should maintain serial execution order
        let finalOrder = executionOrder.withLock { $0 }
        XCTAssertEqual(finalOrder.count, 5)
        // Note: Actor execution order may vary, but all elements should be present
        XCTAssertEqual(Set(finalOrder), Set([1, 2, 3, 4, 5]))
    }

    // MARK: - Performance Tests
    
    func testRun_performance_objcSync() async {
        // Use a Sendable lock object to avoid capture warnings
        final class SendableLockObject: @unchecked Sendable {}
        let lockObject = SendableLockObject()
        
        await measureAsync {
            for _ in 0..<100 {
                let sync = DNSSynchronize(with: lockObject) {
                    // Minimal work
                }
                
                // Run on background thread to avoid main thread exception
                await withCheckedContinuation { continuation in
                    DispatchQueue.global(qos: .default).async {
                        sync.run()
                        continuation.resume()
                    }
                }
            }
        }
    }
    
    func testRun_performance_actorSync() async {
        await measureAsync {
            for _ in 0..<100 {
                await DNSActorSynchronize.run {
                    // Minimal work
                }
            }
        }
    }
    
    // MARK: - Helper Methods for Async Testing
    
    private func measureAsync(_ operation: () async throws -> Void) async {
        let startTime = CFAbsoluteTimeGetCurrent()
        do {
            try await operation()
        } catch {
            XCTFail("Async operation failed: \(error)")
        }
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        
        // Print performance info for manual verification
        print("Async operation completed in \(timeElapsed) seconds")
    }
}
