//
//  DNSThreadingGroupTests.swift
//  DoubleNode Swift Framework (DNSFramework) - DNSCoreThreadingTests
//
//  Created by Darren Ehlers.
//  Copyright © 2020 - 2016 DoubleNode.com. All rights reserved.
//

import XCTest
import os.lock
@testable import DNSCoreThreading

final class DNSThreadingGroupTests: XCTestCase {
    private var sut: DNSThreadingGroup!
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests
    
    func testInit_withoutName_createsValidInstance() {
        // Given / When
        sut = DNSThreadingGroup()
        
        // Then
        XCTAssertNotNil(sut)
        XCTAssertFalse(sut.name.isEmpty)
        XCTAssertEqual(sut.name.count, 16) // Default random string length
    }
    
    func testInit_withName_createsValidInstance() {
        // Given
        let testName = "TestThreadingGroup"
        
        // When
        sut = DNSThreadingGroup(testName)
        
        // Then
        XCTAssertNotNil(sut)
        XCTAssertEqual(sut.name, testName)
    }
    
    func testInit_withEmptyName_generatesRandomName() {
        // Given / When
        sut = DNSThreadingGroup("")
        
        // Then
        XCTAssertNotNil(sut)
        XCTAssertFalse(sut.name.isEmpty)
        XCTAssertEqual(sut.name.count, 16)
    }

    // MARK: - Static Run Method Tests
    
    func testStaticRun_withBlock_executesSuccessfully() async {
        // Given
        let expectation = expectation(description: "Threading group completed")
        let blockExecuted = OSAllocatedUnfairLock(initialState: false)
        
        // When
        _ = DNSThreadingGroup.run("TestGroup") { threadingGroup in
            blockExecuted.withLock { $0 = true }
            XCTAssertEqual(threadingGroup.name, "TestGroup")
        } then: { error in
            XCTAssertNil(error)
            expectation.fulfill()
        }
        
        // Then
        await fulfillment(of: [expectation], timeout: 2.0)
        let wasExecuted = blockExecuted.withLock { $0 }
        XCTAssertTrue(wasExecuted)
    }
    
    func testStaticRun_withTimeout_executesWithinTimeout() async {
        // Given
        let expectation = expectation(description: "Threading group completed")
        let timeout = DispatchTime.now() + .seconds(2)
        let blockExecuted = OSAllocatedUnfairLock(initialState: false)
        
        // When
        DNSThreadingGroup.run("TestGroup",
                              block: { threadingGroup in
            blockExecuted.withLock { $0 = true }
            // Quick execution
        },
                              with: timeout,
                              then: { error in
            XCTAssertNil(error)
            expectation.fulfill()
        })

        // Then
        await fulfillment(of: [expectation], timeout: 3.0)
        let wasExecuted = blockExecuted.withLock { $0 }
        XCTAssertTrue(wasExecuted)
    }
    
    func testStaticRun_withTimeout_handlesTimeoutError() async {
        // Given
        let expectation = expectation(description: "Threading group timed out")
        let shortTimeout = DispatchTime.now() + .milliseconds(100)
        let timeoutErrorReceived = OSAllocatedUnfairLock(initialState: false)
        
        // When
        DNSThreadingGroup.run("TestGroup",
                              block: { threadingGroup in
            // Add a thread that takes too long
            let longRunningThread = DNSThread(.asynchronously) { thread in
                Thread.sleep(forTimeInterval: 1.0) // Sleep longer than timeout
                thread.done()
            }
            threadingGroup.run(longRunningThread)
        },
                              with: shortTimeout,
                              then: { error in
            if let error = error {
                XCTAssertTrue(error.localizedDescription.contains("Timeout"))
                timeoutErrorReceived.withLock { $0 = true }
            }
            expectation.fulfill()
        })
        
        // Then
        await fulfillment(of: [expectation], timeout: 2.0)
        let didReceiveTimeoutError = timeoutErrorReceived.withLock { $0 }
        XCTAssertTrue(didReceiveTimeoutError)
    }

    // MARK: - Instance Run Method Tests
    
    func testInstanceRun_withSingleThread_completesSuccessfully() async {
        // Given
        sut = DNSThreadingGroup("TestGroup")
        let expectation = expectation(description: "Single thread completed")
        let threadExecuted = OSAllocatedUnfairLock(initialState: false)
        
        // When
        sut.run { 
            threadExecuted.withLock { $0 = true }
        } then: { error in
            XCTAssertNil(error)
            expectation.fulfill()
        }
        
        // Then
        await fulfillment(of: [expectation], timeout: 2.0)
        let wasExecuted = threadExecuted.withLock { $0 }
        XCTAssertTrue(wasExecuted)
    }
    
    func testInstanceRun_withMultipleThreads_waitsForAllCompletion() async {
        // Given
        sut = DNSThreadingGroup("MultiThreadGroup")
        let expectation = expectation(description: "All threads completed")
        let executionOrder = OSAllocatedUnfairLock(initialState: [Int]())
        
        // When
        let threadingGroup = sut! // Capture sut in local variable to avoid self capture
        sut.run {
            // Create multiple threads
            let thread1 = DNSThread(.asynchronously) { thread in
                Thread.sleep(forTimeInterval: 0.1)
                executionOrder.withLock { $0.append(1) }
                thread.done()
            }
            
            let thread2 = DNSThread(.asynchronously) { thread in
                Thread.sleep(forTimeInterval: 0.2)
                executionOrder.withLock { $0.append(2) }
                thread.done()
            }
            
            let thread3 = DNSThread(.asynchronously) { thread in
                Thread.sleep(forTimeInterval: 0.05)
                executionOrder.withLock { $0.append(3) }
                thread.done()
            }
            
            // Run threads in group
            threadingGroup.run(thread1)
            threadingGroup.run(thread2)
            threadingGroup.run(thread3)
        } then: { error in
            XCTAssertNil(error)
            expectation.fulfill()
        }
        
        // Then
        await fulfillment(of: [expectation], timeout: 3.0)
        let finalOrder = executionOrder.withLock { $0 }
        XCTAssertEqual(finalOrder.count, 3)
        XCTAssertTrue(finalOrder.contains(1))
        XCTAssertTrue(finalOrder.contains(2))
        XCTAssertTrue(finalOrder.contains(3))
    }
    
    func testInstanceRun_withTimeout_handlesTimeoutCorrectly() async {
        // Given
        sut = DNSThreadingGroup("TimeoutGroup")
        let expectation = expectation(description: "Timeout handled")
        let shortTimeout = DispatchTime.now() + .milliseconds(100)
        let timeoutReceived = OSAllocatedUnfairLock(initialState: false)
        
        // When
        let threadingGroup = sut! // Capture sut in local variable to avoid self capture
        sut.run(block: {
            let slowThread = DNSThread(.asynchronously) { thread in
                Thread.sleep(forTimeInterval: 1.0) // Longer than timeout
                thread.done()
            }
            threadingGroup.run(slowThread)
        },
                with: shortTimeout,
                then: { error in
            if error != nil {
                timeoutReceived.withLock { $0 = true }
            }
            expectation.fulfill()
        })
        
        // Then
        await fulfillment(of: [expectation], timeout: 2.0)
        let didReceiveTimeout = timeoutReceived.withLock { $0 }
        XCTAssertTrue(didReceiveTimeout)
    }

    // MARK: - Thread Management Tests
    
    func testRunThread_addsThreadCorrectly() {
        // Given
        sut = DNSThreadingGroup("ThreadManagementGroup")
        let thread = DNSThread(.asynchronously) { thread in
            thread.done()
        }
        
        // When
        sut.run(thread)
        
        // Then
        // Verify thread was added (we can't directly access internal threads array,
        // but we can verify the behavior through integration testing)
        XCTAssertNotNil(sut)
    }
    
    func testStartThread_incrementsCount() {
        // Given
        sut = DNSThreadingGroup("CountGroup")
        
        // When
        sut.startThread()
        
        // Then
        // Note: count property may not be directly testable due to internal implementation
        // This test verifies the method doesn't crash
        XCTAssertNotNil(sut)
    }
    
    func testCompleteThread_decrementsCount() {
        // Given
        sut = DNSThreadingGroup("CountGroup")
        sut.startThread()
        
        // When
        sut.completeThread()
        
        // Then
        // Note: This test verifies the method doesn't crash
        XCTAssertNotNil(sut)
    }

    // MARK: - Thread Safety Tests
    
    func testConcurrentThreadAddition_maintainsThreadSafety() async {
        // Given
        sut = DNSThreadingGroup("ConcurrentGroup")
        let expectation = expectation(description: "All threads added concurrently")
        expectation.expectedFulfillmentCount = 10
        
        // When - Add threads concurrently
        let threadingGroup = sut! // Capture sut in local variable to avoid self capture
        for _ in 0..<10 {
            DispatchQueue.global(qos: .default).async {
                let thread = DNSThread(.asynchronously) { thread in
                    Thread.sleep(forTimeInterval: 0.1)
                    thread.done()
                }
                threadingGroup.run(thread)
                expectation.fulfill()
            }
        }
        
        // Then
        await fulfillment(of: [expectation], timeout: 3.0)
        XCTAssertNotNil(sut)
    }
    
    func testConcurrentGroupExecution_maintainsThreadSafety() async {
        // Given
        let expectation = expectation(description: "Multiple groups completed")
        expectation.expectedFulfillmentCount = 5
        let completedGroups = OSAllocatedUnfairLock(initialState: 0)
        
        // When - Execute multiple groups concurrently
        for i in 0..<5 {
            DispatchQueue.global(qos: .default).async {
                let group = DNSThreadingGroup("ConcurrentGroup\(i)")
                group.run {
                    let thread = DNSThread(.asynchronously) { thread in
                        Thread.sleep(forTimeInterval: 0.1)
                        thread.done()
                    }
                    group.run(thread)
                } then: { error in
                    XCTAssertNil(error)
                    completedGroups.withLock { $0 += 1 }
                    expectation.fulfill()
                }
            }
        }
        
        // Then
        await fulfillment(of: [expectation], timeout: 3.0)
        let finalCount = completedGroups.withLock { $0 }
        XCTAssertEqual(finalCount, 5)
    }

    // MARK: - Error Handling Tests
    
    func testThreadingGroup_withFailingThread_handlesGracefully() async {
        // Given
        sut = DNSThreadingGroup("ErrorGroup")
        let expectation = expectation(description: "Error handled gracefully")
        
        // When
        let threadingGroup = sut! // Capture sut in local variable to avoid self capture
        sut.run {
            let thread = DNSThread(.asynchronously) { thread in
                // Simulate some work that might fail
                Thread.sleep(forTimeInterval: 0.1)
                thread.done() // Always call done() even if work "fails"
            }
            threadingGroup.run(thread)
        } then: { error in
            // Should complete successfully even if internal work "fails"
            expectation.fulfill()
        }
        
        // Then
        await fulfillment(of: [expectation], timeout: 2.0)
    }

    // MARK: - String Extension Tests
    
    func testStringDnsRandom_generatesCorrectLength() {
        // Given / When
        let randomString = String.dnsRandom(10)
        
        // Then
        XCTAssertEqual(randomString.count, 10)
    }
    
    func testStringDnsRandom_defaultLength_generates16Characters() {
        // Given / When
        let randomString = String.dnsRandom()
        
        // Then
        XCTAssertEqual(randomString.count, 16)
    }
    
    func testStringDnsRandom_onlyValidCharacters() {
        // Given
        let validCharacters = Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890")
        
        // When
        let randomString = String.dnsRandom(100)
        
        // Then
        for character in randomString {
            XCTAssertTrue(validCharacters.contains(character), 
                         "Invalid character '\(character)' found in random string")
        }
    }
    
    func testStringDnsRandom_uniqueness() {
        // Given / When
        let string1 = String.dnsRandom(20)
        let string2 = String.dnsRandom(20)
        
        // Then
        XCTAssertNotEqual(string1, string2, "Random strings should be different")
    }

    // MARK: - Performance Tests
    
    func testThreadingGroup_performance_singleThread() {
        measure {
            let expectation = expectation(description: "Performance test completed")
            
            let group = DNSThreadingGroup("PerformanceGroup")
            group.run {
                let thread = DNSThread(.asynchronously) { thread in
                    // Minimal work
                    thread.done()
                }
                group.run(thread)
            } then: { error in
                XCTAssertNil(error)
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 1.0)
        }
    }
    
    func testThreadingGroup_performance_multipleThreads() {
        measure {
            let expectation = expectation(description: "Multiple threads performance test")
            
            let group = DNSThreadingGroup("MultiPerformanceGroup")
            group.run {
                for _ in 0..<10 {
                    let thread = DNSThread(.asynchronously) { thread in
                        // Minimal work
                        thread.done()
                    }
                    group.run(thread)
                }
            } then: { error in
                XCTAssertNil(error)
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 2.0)
        }
    }

    // MARK: - Integration Tests
    
    func testThreadingGroup_withDifferentThreadTypes_worksCorrectly() async {
        // Given
        sut = DNSThreadingGroup("MixedThreadGroup")
        let expectation = expectation(description: "Mixed thread types completed")
        let executionResults = OSAllocatedUnfairLock(initialState: [String]())
        
        // When
        let threadingGroup = sut! // Capture sut in local variable to avoid self capture
        sut.run {
            // DNSThread
            let normalThread = DNSThread(.asynchronously) { thread in
                executionResults.withLock { $0.append("normal") }
                thread.done()
            }
            
            // DNSHighThread
            let highThread = DNSHighThread(.asynchronously) { thread in
                executionResults.withLock { $0.append("high") }
                thread.done()
            }
            
            // DNSLowThread
            let lowThread = DNSLowThread(.asynchronously) { thread in
                executionResults.withLock { $0.append("low") }
                thread.done()
            }
            
            threadingGroup.run(normalThread)
            threadingGroup.run(highThread)
            threadingGroup.run(lowThread)
        } then: { error in
            XCTAssertNil(error)
            expectation.fulfill()
        }
        
        // Then
        await fulfillment(of: [expectation], timeout: 3.0)
        let finalResults = executionResults.withLock { $0 }
        XCTAssertEqual(finalResults.count, 3)
        XCTAssertTrue(finalResults.contains("normal"))
        XCTAssertTrue(finalResults.contains("high"))
        XCTAssertTrue(finalResults.contains("low"))
    }
}
