//
//  DNSThreadingHelperTests.swift
//  DoubleNode Swift Framework (DNSFramework) - DNSCoreThreadingTests
//
//  Created by Darren Ehlers.
//  Copyright © 2020 - 2016 DoubleNode.com. All rights reserved.
//

import XCTest
import os.lock

@testable import DNSCoreThreading

final class DNSThreadingHelperTests: XCTestCase {
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
        let currentThreadName = Thread.current.name

        sut.run(.asynchronously, in: .highBackground) {
            let executingThreadName = Thread.current.name
            XCTAssertNotEqual(currentThreadName, executingThreadName)
            threadExecuted.fulfill()
        }

        wait(for: [threadExecuted], timeout: 0.1)
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
        let testCount = OSAllocatedUnfairLock(initialState: 0)

        _ = sut.runRepeatedly(in: .highBackground, after: 0.2) { stop in
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

    func test_runRepeatedly_withInBackgroundAfterDelayAndBlock_shouldNotExecute4TimesBeforeDelay() {
        let threadExecuted = expectation(description: "Thread executes")
        threadExecuted.isInverted = true
        let testCount = OSAllocatedUnfairLock(initialState: 0)

        _ = sut.runRepeatedly(in: .highBackground, after: 0.2) { stop in
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
