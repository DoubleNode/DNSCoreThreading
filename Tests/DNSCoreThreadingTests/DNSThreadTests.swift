//
//  DNSThreadTests.swift
//  DoubleNode Swift Framework (DNSFramework) - DNSCoreThreadingTests
//
//  Created by Darren Ehlers.
//  Copyright © 2020 - 2016 DoubleNode.com. All rights reserved.
//

import XCTest
import os.lock

@testable import DNSCoreThreading

final class DNSThreadTests: XCTestCase {
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }

    func test_classRun_withBlock_shouldExecuteImmediatelyInSeparateThread() {
        let threadExecuted = expectation(description: "Thread executes")
        let currentThreadName = Thread.current.name

        DNSThread.run(.asynchronously, in: .highBackground) {
            let executingThreadName = Thread.current.name
            XCTAssertNotEqual(currentThreadName, executingThreadName)
            threadExecuted.fulfill()
        }

        wait(for: [threadExecuted], timeout: 0.1)
    }

    func test_classRun_withAfterDelayAndBlock_shouldExecuteAfterDelay() {
        let threadExecuted = expectation(description: "Thread executes")

        _ = DNSThread.run(in: .highBackground, after: 1.0) {
            threadExecuted.fulfill()
        }

        wait(for: [threadExecuted], timeout: 1.4)
    }

    func test_classRun_withAfterDelayAndBlock_shouldNotExecuteBeforeDelay() {
        let threadExecuted = expectation(description: "Thread executes")
        threadExecuted.isInverted = true

        _ = DNSThread.run(in: .highBackground, after: 1.0) {
            threadExecuted.fulfill()
        }

        wait(for: [threadExecuted], timeout: 0.9)
    }

    func test_classRunRepeatedly_withAfterDelayAndBlock_shouldExecuteAfterDelay4Times() {
        let threadExecuted = expectation(description: "Thread executes")
        let testCount = OSAllocatedUnfairLock(initialState: 0)

        _ = DNSThread.runRepeatedly(in: .highBackground, after: 0.2) { stop in
            let currentCount = testCount.withLock { count in
                count += 1
                return count
            }
            
            guard currentCount < 4 else {
                stop = true
                threadExecuted.fulfill()
                return
            }
        }

        wait(for: [threadExecuted], timeout: 1.0)
        let finalCount = testCount.withLock { $0 }
        XCTAssertEqual(finalCount, 4)
    }

    func test_classRunRepeatedly_withAfterDelayAndBlock_shouldNotExecute4TimesBeforeDelay() {
        let threadExecuted = expectation(description: "Thread executes")
        threadExecuted.isInverted = true
        let testCount = OSAllocatedUnfairLock(initialState: 0)

        _ = DNSThread.runRepeatedly(in: .highBackground, after: 0.2) { stop in
            let currentCount = testCount.withLock { count in
                count += 1
                return count
            }
            
            guard currentCount < 4 else {
                stop = true
                threadExecuted.fulfill()
                return
            }
        }

        wait(for: [threadExecuted], timeout: 0.7)
        let finalCount = testCount.withLock { $0 }
        XCTAssertEqual(finalCount, 3)
    }
}