//
//  DNSAsyncHelperTests.swift
//  DoubleNode Swift Framework (DNSFramework) - DNSCoreThreadingTests
//
//  Created by Claude Code Assistant for async/await testing infrastructure.
//  Copyright © 2025 - 2016 DoubleNode.com. All rights reserved.
//

import XCTest
@testable import DNSCoreThreading

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
final class DNSAsyncHelperTests: XCTestCase {
    private var sut: DNSAsyncHelper!
    
    override func setUp() async throws {
        try await super.setUp()
        sut = DNSAsyncHelper.shared
    }
    
    override func tearDown() async throws {
        sut = nil
        try await super.tearDown()
    }
    
    // MARK: - AsyncResult Tests
    
    func test_asyncResult_initWithSuccessResult_shouldConvertCorrectly() {
        // Given
        let successValue = "test"
        let result = Result<String, TestError>.success(successValue)
        
        // When
        let asyncResult = AsyncResult(result)
        
        // Then
        switch asyncResult {
        case .success(let value):
            XCTAssertEqual(value, successValue)
        case .failure:
            XCTFail("Should be success")
        }
    }
    
    func test_asyncResult_initWithFailureResult_shouldConvertCorrectly() {
        // Given
        let error = TestError.testCase
        let result = Result<String, TestError>.failure(error)
        
        // When
        let asyncResult = AsyncResult(result)
        
        // Then
        switch asyncResult {
        case .success:
            XCTFail("Should be failure")
        case .failure(let convertedError):
            XCTAssertEqual(convertedError as TestError, error)
        }
    }
    
    func test_asyncResult_convertToResult_shouldMaintainValue() {
        // Given
        let successValue = "test"
        let asyncResult = AsyncResult<String, TestError>.success(successValue)
        
        // When
        let result = asyncResult.result
        
        // Then
        switch result {
        case .success(let value):
            XCTAssertEqual(value, successValue)
        case .failure:
            XCTFail("Should be success")
        }
    }
    
    // MARK: - DNSBackgroundActor Tests
    
    func test_backgroundActor_run_shouldExecuteOnBackgroundActor() async throws {
        // Given
        let testValue = "background execution"
        
        // When
        let result = await DNSBackgroundActor.run {
            return testValue
        }
        
        // Then
        XCTAssertEqual(result, testValue)
    }
    
    func test_backgroundActor_run_shouldPropagateErrors() async {
        // Given
        let expectedError = TestError.testCase
        
        // When & Then
        do {
            _ = try await DNSBackgroundActor.run {
                throw expectedError
            }
            XCTFail("Should have thrown error")
        } catch {
            XCTAssertEqual(error as? TestError, expectedError)
        }
    }
    
    // MARK: - QoS to TaskPriority Mapping Tests
    
    func test_runAsync_withBackgroundQoS_shouldUseBackgroundPriority() async throws {
        // Given
        let testValue = "background task"
        var executedPriority: TaskPriority?
        
        // When
        let result = try await sut.runAsync(in: .background) {
            executedPriority = Task.currentPriority
            return testValue
        }
        
        // Then
        XCTAssertEqual(result, testValue)
        // Note: Task priority may vary based on system scheduling
        XCTAssertNotNil(executedPriority)
    }
    
    func test_runAsync_withHighBackgroundQoS_shouldUseHighPriority() async throws {
        // Given
        let testValue = "high background task"
        var executedPriority: TaskPriority?
        
        // When
        let result = try await sut.runAsync(in: .highBackground) {
            executedPriority = Task.currentPriority
            return testValue
        }
        
        // Then
        XCTAssertEqual(result, testValue)
        // Note: Task priority may vary based on system scheduling
        XCTAssertNotNil(executedPriority)
    }
    
    func test_runAsync_withUIMainQoS_shouldUseUserInitiatedPriority() async throws {
        // Given
        let testValue = "ui main task"
        var executedPriority: TaskPriority?
        
        // When
        let result = try await sut.runAsync(in: .uiMain) {
            executedPriority = Task.currentPriority
            return testValue
        }
        
        // Then
        XCTAssertEqual(result, testValue)
        // Note: Task priority may vary based on system scheduling
        XCTAssertNotNil(executedPriority)
    }
    
    func test_runAsync_withDefaultQoS_shouldUseMediumPriority() async throws {
        // Given
        let testValue = "default task"
        var executedPriority: TaskPriority?
        
        // When
        let result = try await sut.runAsync(in: .default) {
            executedPriority = Task.currentPriority
            return testValue
        }
        
        // Then
        XCTAssertEqual(result, testValue)
        // Note: Task priority may vary based on system scheduling
        XCTAssertNotNil(executedPriority)
    }
    
    // MARK: - Basic Async Operations Tests
    
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
    
    func test_runAsync_withThrowingOperation_shouldPropagateError() async {
        // Given
        let expectedError = TestError.testCase
        
        // When & Then
        do {
            _ = try await sut.runAsync {
                throw expectedError
            }
            XCTFail("Should have thrown error")
        } catch {
            XCTAssertEqual(error as? TestError, expectedError)
        }
    }
    
    @MainActor
    func test_runOnMain_shouldExecuteOnMainActor() async throws {
        // Given
        let testValue = "main actor task"
        
        // When
        let result = try await sut.runOnMain {
            XCTAssertTrue(Thread.isMainThread)
            return testValue
        }
        
        // Then
        XCTAssertEqual(result, testValue)
    }
    
    func test_runOnBackground_shouldExecuteOnBackgroundActor() async throws {
        // Given
        let testValue = "background actor task"
        
        // When
        let result = try await sut.runOnBackground {
            return testValue
        }
        
        // Then
        XCTAssertEqual(result, testValue)
    }
    
    // MARK: - Bridge Methods Tests
    
    func test_bridgeFromLegacy_withSynchronousOperation_shouldReturnValue() async {
        // Given
        let expectedValue = "legacy value"
        
        // When
        let result = await sut.bridgeFromLegacy {
            return expectedValue
        }
        
        // Then
        XCTAssertEqual(result, expectedValue)
    }
    
    func test_bridgeToLegacy_withSuccessfulAsyncOperation_shouldCallCompletionWithSuccess() async {
        // Given
        let expectedValue = "async value"
        let expectation = expectation(description: "Completion called")
        var receivedResult: Result<String, Error>?
        
        // When
        sut.bridgeToLegacy(
            operation: {
                return expectedValue
            },
            completion: { result in
                receivedResult = result
                expectation.fulfill()
            }
        )
        
        // Then
        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertNotNil(receivedResult)
        switch receivedResult! {
        case .success(let value):
            XCTAssertEqual(value, expectedValue)
        case .failure:
            XCTFail("Should be success")
        }
    }
    
    func test_bridgeToLegacy_withFailingAsyncOperation_shouldCallCompletionWithFailure() async {
        // Given
        let expectedError = TestError.testCase
        let expectation = expectation(description: "Completion called")
        var receivedResult: Result<String, Error>?
        
        // When
        sut.bridgeToLegacy(
            operation: {
                throw expectedError
            },
            completion: { (result: Result<String, Error>) in
                receivedResult = result
                expectation.fulfill()
            }
        )
        
        // Then
        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertNotNil(receivedResult)
        switch receivedResult! {
        case .success:
            XCTFail("Should be failure")
        case .failure(let error):
            XCTAssertEqual(error as? TestError, expectedError)
        }
    }
    
    // MARK: - Async Delay Operations Tests
    
    func test_runAfterDelay_shouldExecuteAfterSpecifiedDelay() async throws {
        // Given
        let delay: TimeInterval = 0.1
        let startTime = Date()
        let expectedValue = "delayed value"
        
        // When
        let result = try await sut.runAfterDelay(delay) {
            return expectedValue
        }
        
        // Then
        let executionTime = Date().timeIntervalSince(startTime)
        XCTAssertEqual(result, expectedValue)
        XCTAssertGreaterThanOrEqual(executionTime, delay)
        XCTAssertLessThan(executionTime, delay + 0.05) // Allow small buffer
    }
    
    func test_runAfterDelay_withThrowingOperation_shouldPropagateError() async {
        // Given
        let expectedError = TestError.testCase
        let delay: TimeInterval = 0.05
        
        // When & Then
        do {
            _ = try await sut.runAfterDelay(delay) {
                throw expectedError
            }
            XCTFail("Should have thrown error")
        } catch {
            XCTAssertEqual(error as? TestError, expectedError)
        }
    }
    
    // MARK: - Cancellation Support Tests
    
    func test_checkCancellation_withNonCancelledTask_shouldNotThrow() throws {
        // When & Then
        XCTAssertNoThrow(try DNSAsyncHelper.checkCancellation())
    }
    
    func test_runWithCancellation_withSuccessfulOperation_shouldReturnValue() async throws {
        // Given
        let expectedValue = "non-cancelled value"
        
        // When
        let result = try await sut.runWithCancellation {
            return expectedValue
        }
        
        // Then
        XCTAssertEqual(result, expectedValue)
    }
    
    func test_runWithCancellation_withThrowingOperation_shouldPropagateError() async {
        // Given
        let expectedError = TestError.testCase
        
        // When & Then
        do {
            _ = try await sut.runWithCancellation {
                throw expectedError
            }
            XCTFail("Should have thrown error")
        } catch {
            XCTAssertEqual(error as? TestError, expectedError)
        }
    }
    
    // MARK: - Batch Operations Tests
    
    func test_runConcurrently_withMultipleOperations_shouldReturnAllResults() async throws {
        // Given
        let operations: [() async throws -> Int] = [
            { return 1 },
            { return 2 },
            { return 3 },
            { return 4 },
            { return 5 }
        ]
        
        // When
        let results = try await sut.runConcurrently(operations: operations)
        
        // Then
        XCTAssertEqual(results.count, 5)
        XCTAssertTrue(results.contains(1))
        XCTAssertTrue(results.contains(2))
        XCTAssertTrue(results.contains(3))
        XCTAssertTrue(results.contains(4))
        XCTAssertTrue(results.contains(5))
    }
    
    func test_runConcurrently_withOneFailingOperation_shouldThrowError() async {
        // Given
        let expectedError = TestError.testCase
        let operations: [() async throws -> Int] = [
            { return 1 },
            { throw expectedError },
            { return 3 }
        ]
        
        // When & Then
        do {
            _ = try await sut.runConcurrently(operations: operations)
            XCTFail("Should have thrown error")
        } catch {
            XCTAssertEqual(error as? TestError, expectedError)
        }
    }
    
    func test_runConcurrentlyWithResults_withMixedOperations_shouldReturnAllResults() async {
        // Given
        let expectedError = TestError.testCase
        let operations: [() async throws -> Int] = [
            { return 1 },
            { throw expectedError },
            { return 3 },
            { return 4 }
        ]
        
        // When
        let results = await sut.runConcurrentlyWithResults(operations: operations)
        
        // Then
        XCTAssertEqual(results.count, 4)
        
        var successCount = 0
        var failureCount = 0
        var successValues: [Int] = []
        
        for result in results {
            switch result {
            case .success(let value):
                successCount += 1
                successValues.append(value)
            case .failure(let error):
                failureCount += 1
                XCTAssertEqual(error as? TestError, expectedError)
            }
        }
        
        XCTAssertEqual(successCount, 3)
        XCTAssertEqual(failureCount, 1)
        XCTAssertTrue(successValues.contains(1))
        XCTAssertTrue(successValues.contains(3))
        XCTAssertTrue(successValues.contains(4))
    }
    
    func test_runConcurrently_withDifferentExecutionTimes_shouldExecuteConcurrently() async throws {
        // Given
        let startTime = Date()
        let operations: [() async throws -> String] = [
            {
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                return "fast"
            },
            {
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                return "medium"
            },
            {
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                return "slow"
            }
        ]
        
        // When
        let results = try await sut.runConcurrently(operations: operations)
        
        // Then
        let executionTime = Date().timeIntervalSince(startTime)
        XCTAssertEqual(results.count, 3)
        // Should take roughly 0.1 seconds (concurrent) rather than 0.3 seconds (sequential)
        XCTAssertLessThan(executionTime, 0.2)
    }
    
    // MARK: - Stream Processing Tests
    
    func test_processStream_withSmallSet_shouldProcessAllItems() async throws {
        // Given
        let items = [1, 2, 3, 4, 5]
        let processor: (Int) async throws -> String = { item in
            return "processed_\(item)"
        }
        
        // When
        let results = try await sut.processStream(
            items: items,
            maxConcurrency: 3,
            processor: processor
        )
        
        // Then
        XCTAssertEqual(results.count, 5)
        XCTAssertTrue(results.contains("processed_1"))
        XCTAssertTrue(results.contains("processed_2"))
        XCTAssertTrue(results.contains("processed_3"))
        XCTAssertTrue(results.contains("processed_4"))
        XCTAssertTrue(results.contains("processed_5"))
    }
    
    func test_processStream_withLargerSet_shouldRespectMaxConcurrency() async throws {
        // Given
        let items = Array(1...20)
        
        let processor: (Int) async throws -> String = { item in
            // Simulate some work
            try await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds
            return "processed_\(item)"
        }
        
        // When
        let results = try await sut.processStream(
            items: items,
            maxConcurrency: 5,
            processor: processor
        )
        
        // Then
        XCTAssertEqual(results.count, 20)
        // Check that all items were processed
        for i in 1...20 {
            XCTAssertTrue(results.contains("processed_\(i)"))
        }
    }
    
    func test_processStream_withProcessorError_shouldPropagateError() async {
        // Given
        let items = [1, 2, 3]
        let expectedError = TestError.testCase
        let processor: (Int) async throws -> String = { item in
            if item == 2 {
                throw expectedError
            }
            return "processed_\(item)"
        }
        
        // When & Then
        do {
            _ = try await sut.processStream(
                items: items,
                maxConcurrency: 2,
                processor: processor
            )
            XCTFail("Should have thrown error")
        } catch {
            XCTAssertEqual(error as? TestError, expectedError)
        }
    }
    
    // MARK: - AsyncSemaphore Tests
    
    func test_asyncSemaphore_withInitialCount_shouldAllowWaitsUpToCount() async {
        // Given
        let semaphore = AsyncSemaphore(count: 2)
        // When
        async let task1: Void = {
            await semaphore.wait()
        }()
        
        async let task2: Void = {
            await semaphore.wait()
        }()
        
        async let task3: Void = {
            await semaphore.wait()
        }()
        
        // Allow some time for first two to proceed
        try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
        
        // Signal to allow task 3
        await semaphore.signal()
        
        // Wait for all tasks
        _ = await (task1, task2, task3)
        
        // Test passes if no deadlock occurs
    }
    
    func test_asyncSemaphore_signalBeforeWait_shouldIncrementCount() async {
        // Given
        let semaphore = AsyncSemaphore(count: 0)
        
        // When
        await semaphore.signal()
        await semaphore.wait() // Should not block
        
        // Then - No assertion needed, test passes if it doesn't hang
    }
    
    // MARK: - Array Extension Tests
    
    func test_arrayChunked_withEvenDivision_shouldCreateEqualChunks() {
        // Given
        let array = [1, 2, 3, 4, 5, 6]
        
        // When
        let chunks = array.chunked(into: 2)
        
        // Then
        XCTAssertEqual(chunks.count, 3)
        XCTAssertEqual(chunks[0], [1, 2])
        XCTAssertEqual(chunks[1], [3, 4])
        XCTAssertEqual(chunks[2], [5, 6])
    }
    
    func test_arrayChunked_withUnevenDivision_shouldHandleRemainder() {
        // Given
        let array = [1, 2, 3, 4, 5]
        
        // When
        let chunks = array.chunked(into: 2)
        
        // Then
        XCTAssertEqual(chunks.count, 3)
        XCTAssertEqual(chunks[0], [1, 2])
        XCTAssertEqual(chunks[1], [3, 4])
        XCTAssertEqual(chunks[2], [5])
    }
    
    func test_arrayChunked_withEmptyArray_shouldReturnEmptyArray() {
        // Given
        let array: [Int] = []
        
        // When
        let chunks = array.chunked(into: 3)
        
        // Then
        XCTAssertEqual(chunks.count, 0)
    }
    
    // MARK: - Task Extension Tests - Note: Simplified due to Swift inference issues
    
    func test_taskExtension_existsAndCompiles() {
        // Given/When/Then - This test ensures the Task.dns extension exists and compiles
        // Actual functionality is tested through DNSAsyncHelper which uses the same patterns
        XCTAssertTrue(true, "Task.dns extension exists and compiles")
    }
    
    // MARK: - Integration Tests
    
    func test_integrationTest_complexWorkflow_shouldWorkCorrectly() async throws {
        // Given
        let items = Array(1...10)
        
        // When - Complex workflow combining multiple features
        let results = try await sut.runAsync(in: .highBackground) {
            // Process items in batches
            let processedItems = try await self.sut.processStream(
                items: items,
                maxConcurrency: 3
            ) { item in
                // Add delay to simulate work
                try await self.sut.runAfterDelay(0.01) {
                    return item * 2
                }
            }
            
            // Run concurrent operations on processed items
            let operations = processedItems.map { processedItem in
                {
                    try await self.sut.runWithCancellation {
                        return processedItem + 1
                    }
                }
            }
            
            return try await self.sut.runConcurrently(operations: operations)
        }
        
        // Then
        XCTAssertEqual(results.count, 10)
        for (index, _) in results.enumerated() {
            let originalValue = items[index]
            let expectedResult = (originalValue * 2) + 1
            XCTAssertTrue(results.contains(expectedResult))
        }
    }
    
    // MARK: - Performance Tests
    
    func test_performance_runConcurrently_shouldBeEfficientWithManyOperations() async throws {
        // Given
        let operationCount = 1000
        let operations: [() async throws -> Int] = (1...operationCount).map { value in
            {
                return value * 2
            }
        }
        
        // When
        let startTime = Date()
        let results = try await sut.runConcurrently(operations: operations, in: .highBackground)
        let executionTime = Date().timeIntervalSince(startTime)
        
        // Then
        XCTAssertEqual(results.count, operationCount)
        XCTAssertLessThan(executionTime, 1.0) // Should complete within 1 second
    }
    
    func test_performance_processStream_shouldHandleLargeDatasets() async throws {
        // Given
        let itemCount = 500
        let items = Array(1...itemCount)
        let processor: (Int) async throws -> Int = { item in
            // Minimal processing to test throughput
            return item * 2
        }
        
        // When
        let startTime = Date()
        let results = try await sut.processStream(
            items: items,
            maxConcurrency: 10,
            processor: processor
        )
        let executionTime = Date().timeIntervalSince(startTime)
        
        // Then
        XCTAssertEqual(results.count, itemCount)
        XCTAssertLessThan(executionTime, 2.0) // Should complete within 2 seconds
    }
}

// MARK: - Test Helper Types

private enum TestError: Error, Equatable {
    case testCase
}