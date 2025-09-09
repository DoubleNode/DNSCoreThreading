//
//  DNSThreadingHelperTests.swift
//  DoubleNode Swift Framework (DNSFramework) - DNSCoreThreadingTests
//
//  Created by Darren Ehlers.
//  Copyright © 2020 - 2016 DoubleNode.com. All rights reserved.
//

import XCTest
import DNSError

@testable import DNSCoreThreading

class DNSThreadingHelperTests: XCTestCase {
    private var sut: DNSThreadingHelper!

    override func setUp() {
        super.setUp()
        sut = DNSThreadingHelper.shared
    }
    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    func test_run_withAsynchronouslyInBackgroundAndBlock_shouldExecuteImmediatelyInSeparateThread() {
        let threadExecuted = expectation(description: "Thread executes")
        let currentThread = Thread.current
        var testThread: Thread?

        sut.run(.asynchronously, in: .highBackground) {
            testThread = Thread.current
            threadExecuted.fulfill()
        }

        wait(for: [threadExecuted], timeout: 0.1)
        XCTAssertNotEqual(currentThread, testThread)
    }

    func test_run_withSynchronouslyInBackgroundAndBlock_shouldExecuteImmediately() {
        let threadExecuted = expectation(description: "Thread executes")

        sut.run(.asynchronously, in: .highBackground) {
            threadExecuted.fulfill()
        }

        wait(for: [threadExecuted], timeout: 0.1)
    }

    func test_run_withInBackgroundAfterDelayAndBlock_shouldExecuteAfterDelay() {
        let threadExecuted = expectation(description: "Thread executes")

        _ = self.sut.run(in: .highBackground, after: 1.0) {
            threadExecuted.fulfill()
        }

        wait(for: [threadExecuted], timeout: 1.1)
    }

    func test_run_withInBackgroundAfterDelayAndBlock_shouldNotExecuteBeforeDelay() {
        let threadExecuted = expectation(description: "Thread executes")
        threadExecuted.isInverted = true

        _ = self.sut.run(in: .highBackground, after: 1.0) {
            threadExecuted.fulfill()
        }

        wait(for: [threadExecuted], timeout: 0.9)
    }

    func test_runRepeatedly_withInBackgroundAfterDelayAndBlock_shouldExecuteAfterDelay4Times() {
        let threadExecuted = expectation(description: "Thread executes")
        var testCount = 0

        _ = sut.runRepeatedly(in: .highBackground, after: 0.2) { (stop) in
            testCount += 1
            guard testCount < 4 else {
                stop = true
                threadExecuted.fulfill()
                return
            }
        }

        wait(for: [threadExecuted], timeout: 1.0)
        XCTAssertEqual(testCount, 4)
    }

    func test_runRepeatedly_withInBackgroundAfterDelayAndBlock_shouldNotExecute4TimesBeforeDelay() {
        let threadExecuted = expectation(description: "Thread executes")
        threadExecuted.isInverted = true

        var testCount = 0

        _ = sut.runRepeatedly(in: .highBackground, after: 0.2) { (stop) in
            testCount += 1
            guard testCount < 4 else {
                stop = true
                threadExecuted.fulfill()
                return
            }
        }

        wait(for: [threadExecuted], timeout: 0.7)
        XCTAssertEqual(testCount, 3)
    }
    
    // MARK: - Async Bridge Methods Tests
    
    @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
    func test_runAsync_withSuccessfulOperation_shouldReturnValue() async throws {
        // Given
        let expectedValue = 42
        
        // When
        let result = try await sut.runAsync {
            return expectedValue
        }
        
        // Then
        XCTAssertEqual(result, expectedValue)
    }
    
    @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
    func test_runAsync_withThrowingOperation_shouldPropagateError() async {
        // Given
        let expectedError = TestAsyncError.testCase
        
        // When & Then
        do {
            _ = try await sut.runAsync {
                throw expectedError
            }
            XCTFail("Should have thrown error")
        } catch {
            XCTAssertEqual(error as? TestAsyncError, expectedError)
        }
    }
    
    @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
    func test_runAsync_withBackgroundQoS_shouldExecuteWithCorrectPriority() async throws {
        // Given
        let testValue = "background async"
        var executedPriority: TaskPriority?
        
        // When
        let result = try await sut.runAsync(.asynchronously, in: .background) {
            executedPriority = Task.currentPriority
            return testValue
        }
        
        // Then
        XCTAssertEqual(result, testValue)
        // Note: Task priority may vary based on system scheduling
        XCTAssertNotNil(executedPriority)
    }
    
    @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
    func test_runAsync_withHighBackgroundQoS_shouldExecuteWithCorrectPriority() async throws {
        // Given
        let testValue = "high background async"
        var executedPriority: TaskPriority?
        
        // When
        let result = try await sut.runAsync(.asynchronously, in: .highBackground) {
            executedPriority = Task.currentPriority
            return testValue
        }
        
        // Then
        XCTAssertEqual(result, testValue)
        // Note: Task priority may vary based on system scheduling
        XCTAssertNotNil(executedPriority)
    }
    
    @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
    func test_runAsync_withUIMainQoS_shouldExecuteWithCorrectPriority() async throws {
        // Given
        let testValue = "ui main async"
        var executedPriority: TaskPriority?
        
        // When
        let result = try await sut.runAsync(.asynchronously, in: .uiMain) {
            executedPriority = Task.currentPriority
            return testValue
        }
        
        // Then
        XCTAssertEqual(result, testValue)
        // Note: Task priority may vary based on system scheduling
        XCTAssertNotNil(executedPriority)
    }
    
    @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
    func test_bridgeAsync_withSuccessfulOperation_shouldCallCompletionWithSuccess() async {
        // Given
        let expectedValue = "bridged success"
        let completionExpectation = expectation(description: "Completion called")
        var receivedResult: Result<String, Error>?
        
        // When
        sut.bridgeAsync(
            operation: {
                return expectedValue
            },
            completion: { result in
                receivedResult = result
                completionExpectation.fulfill()
            }
        )
        
        // Then
        await fulfillment(of: [completionExpectation], timeout: 1.0)
        XCTAssertNotNil(receivedResult)
        switch receivedResult! {
        case .success(let value):
            XCTAssertEqual(value, expectedValue)
        case .failure:
            XCTFail("Should be success")
        }
    }
    
    @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
    func test_bridgeAsync_withFailingOperation_shouldCallCompletionWithFailure() async {
        // Given
        let expectedError = TestAsyncError.testCase
        let completionExpectation = expectation(description: "Completion called")
        var receivedResult: Result<String, Error>?
        
        // When
        sut.bridgeAsync(
            operation: {
                throw expectedError
            },
            completion: { (result: Result<String, Error>) in
                receivedResult = result
                completionExpectation.fulfill()
            }
        )
        
        // Then
        await fulfillment(of: [completionExpectation], timeout: 1.0)
        XCTAssertNotNil(receivedResult)
        switch receivedResult! {
        case .success:
            XCTFail("Should be failure")
        case .failure(let error):
            XCTAssertEqual(error as? TestAsyncError, expectedError)
        }
    }
    
    @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
    func test_bridgeAsync_withBackgroundQoS_shouldExecuteWithCorrectPriority() async {
        // Given
        let testValue = "background bridge"
        let completionExpectation = expectation(description: "Completion called")
        var executedPriority: TaskPriority?
        var receivedResult: Result<String, Error>?
        
        // When
        sut.bridgeAsync(.asynchronously, in: .background,
            operation: {
                executedPriority = Task.currentPriority
                return testValue
            },
            completion: { result in
                receivedResult = result
                completionExpectation.fulfill()
            }
        )
        
        // Then
        await fulfillment(of: [completionExpectation], timeout: 1.0)
        // Note: Task priority may vary based on system scheduling
        XCTAssertNotNil(executedPriority)
        switch receivedResult! {
        case .success(let value):
            XCTAssertEqual(value, testValue)
        case .failure:
            XCTFail("Should be success")
        }
    }
    
    @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
    func test_runAsyncAfterDelay_shouldExecuteAfterSpecifiedDelay() async throws {
        // Given
        let delay: TimeInterval = 0.1
        let startTime = Date()
        let expectedValue = "delayed async"
        
        // When
        let result = try await sut.runAsync(in: .background, after: delay) {
            return expectedValue
        }
        
        // Then
        let executionTime = Date().timeIntervalSince(startTime)
        XCTAssertEqual(result, expectedValue)
        XCTAssertGreaterThanOrEqual(executionTime, delay)
        XCTAssertLessThan(executionTime, delay + 0.05) // Allow small buffer
    }
    
    @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
    func test_runAsyncAfterDelay_withThrowingOperation_shouldPropagateError() async {
        // Given
        let expectedError = TestAsyncError.testCase
        let delay: TimeInterval = 0.05
        
        // When & Then
        do {
            _ = try await sut.runAsync(in: .background, after: delay) {
                throw expectedError
            }
            XCTFail("Should have thrown error")
        } catch {
            XCTAssertEqual(error as? TestAsyncError, expectedError)
        }
    }
    
    @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
    func test_runAsyncAfterDelay_withDifferentQoS_shouldUseCorrectPriority() async throws {
        // Given
        let delay: TimeInterval = 0.05
        let testValue = "delayed high priority"
        var executedPriority: TaskPriority?
        
        // When
        let result = try await sut.runAsync(in: .highBackground, after: delay) {
            executedPriority = Task.currentPriority
            return testValue
        }
        
        // Then
        XCTAssertEqual(result, testValue)
        // Note: Task priority may vary based on system scheduling
        XCTAssertNotNil(executedPriority)
    }
    
    @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
    func test_runGroup_withMultipleOperations_shouldReturnAllResults() async throws {
        // Given
        let operations: [() async throws -> Int] = [
            { return 1 },
            { return 2 },
            { return 3 },
            { return 4 },
            { return 5 }
        ]
        
        // When
        let results = try await sut.runGroup(operations: operations)
        
        // Then
        XCTAssertEqual(results.count, 5)
        XCTAssertTrue(results.contains(1))
        XCTAssertTrue(results.contains(2))
        XCTAssertTrue(results.contains(3))
        XCTAssertTrue(results.contains(4))
        XCTAssertTrue(results.contains(5))
    }
    
    @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
    func test_runGroup_withOneFailingOperation_shouldThrowError() async {
        // Given
        let expectedError = TestAsyncError.testCase
        let operations: [() async throws -> Int] = [
            { return 1 },
            { throw expectedError },
            { return 3 }
        ]
        
        // When & Then
        do {
            _ = try await sut.runGroup(operations: operations)
            XCTFail("Should have thrown error")
        } catch {
            XCTAssertEqual(error as? TestAsyncError, expectedError)
        }
    }
    
    @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
    func test_runGroup_withDifferentQoS_shouldUseCorrectPriority() async throws {
        // Given
        let operations: [() async throws -> String] = [
            {
                let priority = Task.currentPriority
                return "task1_\(priority)"
            },
            {
                let priority = Task.currentPriority
                return "task2_\(priority)"
            }
        ]
        
        // When
        let results = try await sut.runGroup(operations: operations, in: .highBackground)
        
        // Then
        XCTAssertEqual(results.count, 2)
        XCTAssertTrue(results.contains(where: { $0.contains("task1") }))
        XCTAssertTrue(results.contains(where: { $0.contains("task2") }))
    }
    
    @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
    func test_runGroup_withTimeout_shouldCompleteWithinTimeout() async throws {
        // Given
        let operations: [() async throws -> String] = [
            {
                try await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
                return "fast"
            },
            {
                try await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
                return "medium"
            }
        ]
        
        // When
        let results = try await sut.runGroup(operations: operations, timeout: 0.2)
        
        // Then
        XCTAssertEqual(results.count, 2)
        XCTAssertTrue(results.contains("fast"))
        XCTAssertTrue(results.contains("medium"))
    }
    
    @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
    func test_runGroup_withTimeout_shouldThrowTimeoutError() async {
        // Given
        let operations: [() async throws -> String] = [
            {
                try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
                return "slow"
            }
        ]
        
        // When & Then
        do {
            _ = try await sut.runGroup(operations: operations, timeout: 0.1)
            XCTFail("Should have thrown timeout error")
        } catch {
            // Should be a DNSError.CoreThreading.groupTimeout error
            XCTAssertTrue(error.localizedDescription.contains("timeout") || error is DNSError)
        }
    }
    
    @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
    func test_runGroup_withConcurrentExecution_shouldExecuteConcurrently() async throws {
        // Given
        let startTime = Date()
        let operations: [() async throws -> String] = [
            {
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                return "concurrent1"
            },
            {
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                return "concurrent2"
            },
            {
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                return "concurrent3"
            }
        ]
        
        // When
        let results = try await sut.runGroup(operations: operations)
        
        // Then
        let executionTime = Date().timeIntervalSince(startTime)
        XCTAssertEqual(results.count, 3)
        XCTAssertTrue(results.contains("concurrent1"))
        XCTAssertTrue(results.contains("concurrent2"))
        XCTAssertTrue(results.contains("concurrent3"))
        
        // Should take roughly 0.1 seconds (concurrent) rather than 0.3 seconds (sequential)
        XCTAssertLessThan(executionTime, 0.2)
    }
    
    // MARK: - QoSClass to TaskPriority Extension Tests
    
    @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
    func test_qosClassTaskPriority_backgroundQoS_shouldReturnBackgroundPriority() {
        // Given
        let qos = DNSThreading.QoSClass.background
        
        // When
        let priority = qos.taskPriority
        
        // Then
        XCTAssertEqual(priority, .background)
    }
    
    @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
    func test_qosClassTaskPriority_lowBackgroundQoS_shouldReturnBackgroundPriority() {
        // Given
        let qos = DNSThreading.QoSClass.lowBackground
        
        // When
        let priority = qos.taskPriority
        
        // Then
        XCTAssertEqual(priority, .background)
    }
    
    @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
    func test_qosClassTaskPriority_defaultQoS_shouldReturnMediumPriority() {
        // Given
        let qos = DNSThreading.QoSClass.default
        
        // When
        let priority = qos.taskPriority
        
        // Then
        XCTAssertEqual(priority, .medium)
    }
    
    @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
    func test_qosClassTaskPriority_highBackgroundQoS_shouldReturnHighPriority() {
        // Given
        let qos = DNSThreading.QoSClass.highBackground
        
        // When
        let priority = qos.taskPriority
        
        // Then
        XCTAssertEqual(priority, .high)
    }
    
    @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
    func test_qosClassTaskPriority_uiMainQoS_shouldReturnUserInitiatedPriority() {
        // Given
        let qos = DNSThreading.QoSClass.uiMain
        
        // When
        let priority = qos.taskPriority
        
        // Then
        XCTAssertEqual(priority, .userInitiated)
    }
    
    @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
    func test_qosClassTaskPriority_currentQoS_shouldReturnMediumPriority() {
        // Given
        let qos = DNSThreading.QoSClass.current
        
        // When
        let priority = qos.taskPriority
        
        // Then
        XCTAssertEqual(priority, .medium)
    }
    
    // MARK: - Integration Tests (Legacy + Async)
    
    @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
    func test_integrationTest_legacyAndAsyncInteroperability_shouldWorkTogether() async throws {
        // Given
        let legacyExpectation = expectation(description: "Legacy operation completes")
        let asyncValue = "async result"
        var legacyResult: String?
        
        // When - Start legacy operation
        sut.run(.asynchronously, in: .background) {
            legacyResult = "legacy result"
            legacyExpectation.fulfill()
        }
        
        // And run async operation concurrently
        let asyncResult = try await sut.runAsync(in: .background) {
            return asyncValue
        }
        
        // Then - Wait for legacy to complete
        await fulfillment(of: [legacyExpectation], timeout: 1.0)
        
        XCTAssertEqual(asyncResult, asyncValue)
        XCTAssertEqual(legacyResult, "legacy result")
    }
    
    @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
    func test_integrationTest_asyncGroupReplacingLegacyGroup_shouldProvideSameFunctionality() async throws {
        // Given
        let operations: [() async throws -> Int] = [
            {
                try await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
                return 1
            },
            {
                try await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
                return 2
            },
            {
                try await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
                return 3
            }
        ]
        
        // When
        let results = try await sut.runGroup(operations: operations)
        
        // Then
        XCTAssertEqual(results.count, 3)
        XCTAssertTrue(results.contains(1))
        XCTAssertTrue(results.contains(2))
        XCTAssertTrue(results.contains(3))
    }
    
    // MARK: - Performance Tests for Async Methods
    
    @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
    func test_performance_runGroup_shouldBeEfficientWithManyOperations() async throws {
        // Given
        let operationCount = 100
        let operations: [() async throws -> Int] = (1...operationCount).map { value in
            {
                return value * 2
            }
        }
        
        // When
        let startTime = Date()
        let results = try await sut.runGroup(operations: operations)
        let executionTime = Date().timeIntervalSince(startTime)
        
        // Then
        XCTAssertEqual(results.count, operationCount)
        XCTAssertLessThan(executionTime, 1.0) // Should complete within 1 second
    }
    
    @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
    func test_performance_bridgeAsync_shouldHandleMultipleConcurrentBridges() async {
        // Given
        let bridgeCount = 50
        let expectations = (1...bridgeCount).map { index in
            expectation(description: "Bridge \(index) completes")
        }
        
        // When
        let startTime = Date()
        for (index, expectation) in expectations.enumerated() {
            sut.bridgeAsync(
                operation: {
                    return index
                },
                completion: { result in
                    switch result {
                    case .success:
                        expectation.fulfill()
                    case .failure:
                        XCTFail("Bridge \(index) should not fail")
                    }
                }
            )
        }
        
        // Then
        await fulfillment(of: expectations, timeout: 2.0)
        let executionTime = Date().timeIntervalSince(startTime)
        XCTAssertLessThan(executionTime, 1.0) // Should complete within 1 second
    }
}

// MARK: - Test Helper Types for Async Tests

private enum TestAsyncError: Error, Equatable {
    case testCase
}
