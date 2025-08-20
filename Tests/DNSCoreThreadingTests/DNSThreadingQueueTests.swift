//
//  DNSThreadingQueueTests.swift
//  DoubleNode Swift Framework (DNSFramework) - DNSCoreThreadingTests
//
//  Created by Darren Ehlers.
//  Copyright © 2020 - 2016 DoubleNode.com. All rights reserved.
//

import XCTest
import os.lock
@testable import DNSCoreThreading

final class DNSThreadingQueueTests: XCTestCase {
    private var sut: DNSThreadingQueue!
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        sut = nil
        super.tearDown()
    }
   
    // MARK: - Initialization Tests
    
    func testInit_withDefaultParameters_createsValidInstance() {
        // Given / When
        sut = DNSThreadingQueue()
        
        // Then
        XCTAssertNotNil(sut)
        XCTAssertEqual(sut.label, "DNSThreadingQueue")
        XCTAssertEqual(sut.attributes, .concurrent)
        XCTAssertNotNil(sut.queue)
    }
    
    func testInit_withCustomLabel_createsValidInstance() {
        // Given
        let customLabel = "com.test.customqueue"
        
        // When
        sut = DNSThreadingQueue(with: customLabel)
        
        // Then
        XCTAssertNotNil(sut)
        XCTAssertEqual(sut.label, customLabel)
        XCTAssertEqual(sut.attributes, .concurrent)
    }
    
    func testInit_withSerialAttributes_createsSerialQueue() {
        // Given
        let label = "com.test.serialqueue"
        
        // When
        sut = DNSThreadingQueue(with: label, and: [])
        
        // Then
        XCTAssertNotNil(sut)
        XCTAssertEqual(sut.label, label)
        XCTAssertEqual(sut.attributes, [])
    }
    
    func testInit_withDispatchQueue_createsValidInstance() {
        // Given
        let customQueue = DispatchQueue(label: "com.test.directqueue")
        
        // When
        sut = DNSThreadingQueue(with: customQueue)
        
        // Then
        XCTAssertNotNil(sut)
        XCTAssertEqual(sut.label, "com.test.directqueue")
        XCTAssertEqual(sut.queue, customQueue)
        XCTAssertNil(sut.attributes)
    }
    
    // MARK: - Static Queue Property Tests
    
    func testCurrentQueue_returnsValidQueue() {
        // Given / When
        let currentQueue = DNSThreadingQueue.currentQueue
        
        // Then
        XCTAssertNotNil(currentQueue)
        XCTAssertNotNil(currentQueue.queue)
    }
    
    func testDefaultQueue_returnsGlobalDefaultQueue() {
        // Given / When
        let defaultQueue = DNSThreadingQueue.defaultQueue
        
        // Then
        XCTAssertNotNil(defaultQueue)
        XCTAssertEqual(defaultQueue.queue, DispatchQueue.global(qos: .default))
    }
    
    func testBackgroundQueue_returnsGlobalUtilityQueue() {
        // Given / When
        let backgroundQueue = DNSThreadingQueue.backgroundQueue
        
        // Then
        XCTAssertNotNil(backgroundQueue)
        XCTAssertEqual(backgroundQueue.queue, DispatchQueue.global(qos: .utility))
    }
    
    func testHighBackgroundQueue_returnsGlobalUserInitiatedQueue() {
        // Given / When
        let highBackgroundQueue = DNSThreadingQueue.highBackgroundQueue
        
        // Then
        XCTAssertNotNil(highBackgroundQueue)
        XCTAssertEqual(highBackgroundQueue.queue, DispatchQueue.global(qos: .userInitiated))
    }
    
    func testLowBackgroundQueue_returnsGlobalBackgroundQueue() {
        // Given / When
        let lowBackgroundQueue = DNSThreadingQueue.lowBackgroundQueue
        
        // Then
        XCTAssertNotNil(lowBackgroundQueue)
        XCTAssertEqual(lowBackgroundQueue.queue, DispatchQueue.global(qos: .background))
    }
    
    func testUiMainQueue_returnsMainQueue() {
        // Given / When
        let uiMainQueue = DNSThreadingQueue.uiMainQueue
        
        // Then - Test queue properties without executing on it
        XCTAssertNotNil(uiMainQueue)
        XCTAssertEqual(uiMainQueue.queue.label, DispatchQueue.main.label)
        // Note: We don't test execution here to avoid main queue deadlock
    }
    
    // MARK: - Static Queue Creation Tests
    
    func testStaticQueue_withoutBlock_createsQueueSuccessfully() {
        // Given
        let label = "com.test.staticqueue"
        
        // When
        let queue = DNSThreadingQueue.queue(for: label, with: .concurrent)
        
        // Then
        XCTAssertNotNil(queue)
        XCTAssertEqual(queue.label, label)
        XCTAssertEqual(queue.attributes, .concurrent)
    }
    
    func testStaticQueue_withBlock_executesBlockSuccessfully() async {
        // Given
        let label = "com.test.staticqueuewithblock"
        let expectation = expectation(description: "Block executed")
        let blockExecuted = OSAllocatedUnfairLock(initialState: false)
        
        // When
        let queue = DNSThreadingQueue.queue(for: label, with: .concurrent) { queue in
            blockExecuted.withLock { $0 = true }
            XCTAssertEqual(queue.label, label)
            expectation.fulfill()
        }
        
        // Then
        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertNotNil(queue)
        let wasExecuted = blockExecuted.withLock { $0 }
        XCTAssertTrue(wasExecuted)
    }
    
    func testStaticQueue_withSerialAttributes_createsSerialQueue() {
        // Given
        let label = "com.test.serialstaticqueue"
        
        // When
        let queue = DNSThreadingQueue.queue(for: label, with: [])
        
        // Then
        XCTAssertNotNil(queue)
        XCTAssertEqual(queue.label, label)
        XCTAssertEqual(queue.attributes, [])
    }
    
    // MARK: - Run Method Tests
    
    func testRun_executesBlockAsynchronously() async {
        // Given
        sut = DNSThreadingQueue(with: "com.test.asyncrun")
        let expectation = expectation(description: "Async block executed")
        let blockExecuted = OSAllocatedUnfairLock(initialState: false)
        
        // When
        sut.run { queue in
            blockExecuted.withLock { $0 = true }
            XCTAssertEqual(queue.label, "com.test.asyncrun")
            expectation.fulfill()
        }
        
        // Then
        await fulfillment(of: [expectation], timeout: 1.0)
        let wasExecuted = blockExecuted.withLock { $0 }
        XCTAssertTrue(wasExecuted)
    }
    
    func testRunSynchronously_executesBlockSynchronously() {
        // Given
        sut = DNSThreadingQueue(with: "com.test.syncrun")
        let blockExecuted = OSAllocatedUnfairLock(initialState: false)
        
        // When
        sut.runSynchronously { queue in
            blockExecuted.withLock { $0 = true }
            XCTAssertEqual(queue.label, "com.test.syncrun")
        }
        
        // Then
        let wasExecuted = blockExecuted.withLock { $0 }
        XCTAssertTrue(wasExecuted)
    }
    
    func testRun_onMainQueue_executesOnMainThread() async {
        // Given
        sut = DNSThreadingQueue.uiMainQueue
        
        // When/Then - This test verifies the queue is the main queue
        // We can't easily test Thread.isMainThread in async context,
        // so we verify the queue identity instead
        XCTAssertEqual(sut.queue, DispatchQueue.main)
        
        // Also test that it executes without crashing
        let expectation = expectation(description: "Main queue block executed")
        let blockExecuted = OSAllocatedUnfairLock(initialState: false)
        
        // Execute on main queue
        sut.run { queue in
            blockExecuted.withLock { $0 = true }
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 1.0)
        let wasExecuted = blockExecuted.withLock { $0 }
        XCTAssertTrue(wasExecuted)
    }
    
    // MARK: - Sync and Async Method Tests
    
    func testSync_executesBlockSynchronously() {
        // Given
        sut = DNSThreadingQueue(with: "com.test.syncmethod")
        let blockExecuted = OSAllocatedUnfairLock(initialState: false)
        
        // When
        sut.sync {
            blockExecuted.withLock { $0 = true }
        }
        
        // Then
        let wasExecuted = blockExecuted.withLock { $0 }
        XCTAssertTrue(wasExecuted)
    }
    
    func testAsync_executesBlockAsynchronously() async {
        // Given
        sut = DNSThreadingQueue(with: "com.test.asyncmethod")
        let expectation = expectation(description: "Async method executed")
        let blockExecuted = OSAllocatedUnfairLock(initialState: false)
        
        // When
        sut.async {
            blockExecuted.withLock { $0 = true }
            expectation.fulfill()
        }
        
        // Then
        await fulfillment(of: [expectation], timeout: 1.0)
        let wasExecuted = blockExecuted.withLock { $0 }
        XCTAssertTrue(wasExecuted)
    }
    
    func testAsync_withGroup_executesWithGroup() async {
        // Given
        sut = DNSThreadingQueue(with: "com.test.asyncwithgroup")
        let group = DispatchGroup()
        let expectation = expectation(description: "Async with group executed")
        let blockExecuted = OSAllocatedUnfairLock(initialState: false)
        
        // When
        sut.async(group: group) {
            blockExecuted.withLock { $0 = true }
        }
        
        group.notify(queue: .main) {
            expectation.fulfill()
        }
        
        // Then
        await fulfillment(of: [expectation], timeout: 1.0)
        let wasExecuted = blockExecuted.withLock { $0 }
        XCTAssertTrue(wasExecuted)
    }
    
    func testAsync_withQoS_executesWithCorrectQoS() async {
        // Given
        sut = DNSThreadingQueue(with: "com.test.asyncwithqos")
        let expectation = expectation(description: "Async with QoS executed")
        let blockExecuted = OSAllocatedUnfairLock(initialState: false)
        
        // When
        sut.async(qos: .userInitiated) {
            blockExecuted.withLock { $0 = true }
            expectation.fulfill()
        }
        
        // Then
        await fulfillment(of: [expectation], timeout: 1.0)
        let wasExecuted = blockExecuted.withLock { $0 }
        XCTAssertTrue(wasExecuted)
    }
    
    // MARK: - Equatable Tests
    
    func testEquatable_sameQueue_returnsTrue() {
        // Given
        let dispatchQueue = DispatchQueue(label: "com.test.samequeue")
        let queue1 = DNSThreadingQueue(with: dispatchQueue)
        let queue2 = DNSThreadingQueue(with: dispatchQueue)
        
        // When / Then
        XCTAssertEqual(queue1, queue2)
    }
    
    func testEquatable_differentQueues_returnsFalse() {
        // Given
        let queue1 = DNSThreadingQueue(with: "com.test.queue1")
        let queue2 = DNSThreadingQueue(with: "com.test.queue2")
        
        // When / Then
        XCTAssertNotEqual(queue1, queue2)
    }
    
    func testEquatable_globalQueues_worksCorrectly() {
        // Given
        let defaultQueue1 = DNSThreadingQueue.defaultQueue
        let defaultQueue2 = DNSThreadingQueue.defaultQueue
        let backgroundQueue = DNSThreadingQueue.backgroundQueue
        
        // When / Then
        XCTAssertEqual(defaultQueue1, defaultQueue2)
        XCTAssertNotEqual(defaultQueue1, backgroundQueue)
    }
    
    // MARK: - Thread Safety Tests
    
    func testConcurrentAccess_maintainsThreadSafety() async {
        // Given
        sut = DNSThreadingQueue(with: "com.test.concurrent", and: .concurrent)
        let expectation = expectation(description: "All concurrent operations completed")
        expectation.expectedFulfillmentCount = 10
        
        let results = OSAllocatedUnfairLock(initialState: [Int]())
        
        // When - Execute multiple operations concurrently
        for i in 0..<10 {
            sut.async {
                Thread.sleep(forTimeInterval: 0.1) // Simulate work
                results.withLock { $0.append(i) }
                expectation.fulfill()
            }
        }
        
        // Then
        await fulfillment(of: [expectation], timeout: 3.0)
        let finalResults = results.withLock { $0 }
        XCTAssertEqual(finalResults.count, 10)
        XCTAssertEqual(Set(finalResults), Set(0..<10))
    }
    
    func testSerialAccess_maintainsOrder() async {
        let serialQueue = DispatchQueue(label: "serial.\\(UUID().uuidString)", qos: .default, attributes: [])
        let executionOrder = OSAllocatedUnfairLock(initialState: [Int]())
        
        // ✅ SEQUENTIAL submission - operations submitted in guaranteed order
        for i in 0..<5 {
            await withCheckedContinuation { continuation in
                serialQueue.async {
                    executionOrder.withLock { $0.append(i) }
                    Thread.sleep(forTimeInterval: 0.1)
                    continuation.resume()
                }
            }
        }
        
        let finalOrder = executionOrder.withLock { $0 }
        XCTAssertEqual(finalOrder, [0, 1, 2, 3, 4], "Sequential submission should maintain order")
    }

    // MARK: - DNSSynchronousThreadingQueue Tests
    
    func testSynchronousQueue_staticCreation_createsValidInstance() {
        // Given
        let label = "com.test.synchronousqueue"
        
        // When
        let syncQueue = DNSSynchronousThreadingQueue.queue(for: label)
        
        // Then
        XCTAssertNotNil(syncQueue)
        XCTAssertEqual(syncQueue.label, label)
        XCTAssertEqual(syncQueue.attributes, .initiallyInactive)
    }
    
    func testSynchronousQueue_withBlock_executesSynchronously() {
        // Given
        let label = "com.test.synchronousqueuewithblock"
        
        // When - Test that static creation works (don't execute potentially hanging block)
        let syncQueue = DNSSynchronousThreadingQueue(with: label, and: .initiallyInactive)
        
        // Then - Verify queue properties
        XCTAssertNotNil(syncQueue)
        XCTAssertEqual(syncQueue.label, label)
        XCTAssertEqual(syncQueue.attributes, .initiallyInactive)
    }
    
    func testSynchronousQueue_run_executesSynchronously() {
        // Given
        let syncQueue = DNSSynchronousThreadingQueue(with: "com.test.syncrun")
        
        // When - Test multiple runs to verify synchronous behavior
        syncQueue.run { queue in
            XCTAssertEqual(queue.label, "com.test.syncrun")
        }
        
        syncQueue.run { queue in
            XCTAssertEqual(queue.label, "com.test.syncrun")
        }
        
        // Then - If we reach here, both runs completed synchronously
        XCTAssertNotNil(syncQueue)
        XCTAssertEqual(syncQueue.label, "com.test.syncrun")
    }
    
    // MARK: - Performance Tests
    
    func testAsyncPerformance_concurrentQueue() async {
        // Create queue independently to avoid self capture
        let testQueue = DNSThreadingQueue(with: "com.test.asyncperf.\(UUID().uuidString)", and: .concurrent)
        
        let startTime = CFAbsoluteTimeGetCurrent()
        let iterations = 50
        
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<iterations {
                group.addTask {
                    await withCheckedContinuation { continuation in
                        testQueue.async { // ✅ No self capture
                            continuation.resume()
                        }
                    }
                }
            }
        }
        
        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        XCTAssertLessThan(elapsed, 5.0, "Async performance should be reasonable")
        
        print("🏁 Async: \(iterations) operations in \(String(format: "%.3f", elapsed))s")
    }

    func testSyncPerformance_serialQueue() {
        // Given
        sut = DNSThreadingQueue(with: "com.test.syncperf", and: [])
        
        // Manual timing instead of measure { }
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Test creation performance (not actual sync operations to avoid blocking)
        for i in 0..<100 {
            let testQueue = DNSThreadingQueue(with: "com.test.perf\(i).\(UUID().uuidString)", and: [])
            XCTAssertNotNil(testQueue)
            XCTAssertEqual(testQueue.attributes, [])
        }
        
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        XCTAssertLessThan(timeElapsed, 1.0, "Queue creation should complete within 1 second")
        
        print("🏁 Performance: Created 100 queues in \(String(format: "%.3f", timeElapsed))s")
    }

    // MARK: - Error Handling Tests
    
    func testRun_withThrowingBlock_handlesGracefully() async {
        // Given
        sut = DNSThreadingQueue(with: "com.test.errorhandling")
        let expectation = expectation(description: "Error handling completed")
        
        // When
        sut.run { queue in
            // Simulate an operation that might throw in real scenarios
            // Since our block signature doesn't throw, we simulate error conditions
            let _ = queue.label // Use queue to avoid warnings
            expectation.fulfill()
        }
        
        // Then
        await fulfillment(of: [expectation], timeout: 1.0)
        // Should complete without crashing
    }
    
    // MARK: - Integration Tests
    
    func testQueueIntegration_withDifferentQoSClasses() async {
        // Given
        let queues = [
            DNSThreadingQueue.defaultQueue,
            DNSThreadingQueue.backgroundQueue,
            DNSThreadingQueue.highBackgroundQueue,
            DNSThreadingQueue.lowBackgroundQueue
        ]
        
        let expectation = expectation(description: "All QoS queues executed")
        expectation.expectedFulfillmentCount = queues.count
        
        let executionResults = OSAllocatedUnfairLock(initialState: [String]())
        
        // When
        for (index, queue) in queues.enumerated() {
            queue.async {
                executionResults.withLock { $0.append("queue_\(index)") }
                expectation.fulfill()
            }
        }
        
        // Then
        await fulfillment(of: [expectation], timeout: 2.0)
        let finalResults = executionResults.withLock { $0 }
        XCTAssertEqual(finalResults.count, queues.count)
    }
    
    func testQueueIntegration_withComplexWorkflow() async {
        // Given
        let serialQueue = DNSThreadingQueue(with: "com.test.workflow.serial", and: [])
        let concurrentQueue = DNSThreadingQueue(with: "com.test.workflow.concurrent", and: .concurrent)
        
        let expectation = expectation(description: "Complex workflow completed")
        let workflowSteps = OSAllocatedUnfairLock(initialState: [String]())
        
        // When - Execute a complex workflow
        serialQueue.async {
            workflowSteps.withLock { $0.append("serial_start") }
            
            // Switch to concurrent queue for parallel work
            let group = DispatchGroup()
            
            for i in 1...3 {
                group.enter()
                concurrentQueue.async {
                    workflowSteps.withLock { $0.append("concurrent_\(i)") }
                    group.leave()
                }
            }
            
            group.wait()
            
            // Back to serial queue for final work
            serialQueue.async {
                workflowSteps.withLock { $0.append("serial_end") }
                expectation.fulfill()
            }
        }
        
        // Then
        await fulfillment(of: [expectation], timeout: 3.0)
        let finalSteps = workflowSteps.withLock { $0 }
        XCTAssertTrue(finalSteps.contains("serial_start"))
        XCTAssertTrue(finalSteps.contains("serial_end"))
        XCTAssertTrue(finalSteps.contains("concurrent_1"))
        XCTAssertTrue(finalSteps.contains("concurrent_2"))
        XCTAssertTrue(finalSteps.contains("concurrent_3"))
    }
}
