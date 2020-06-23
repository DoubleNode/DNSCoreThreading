//
//  DNSThreadTests.m
//  DNSCoreTests
//
//  Created by Darren Ehlers on 10/23/16.
//  Copyright © 2019 - 2016 DoubleNode.com. All rights reserved.
//

import XCTest

@testable import DNSCoreThreading

class DNSThreadTests: XCTestCase {
    override func setUp() {
        super.setUp()
    }
    override func tearDown() {
        super.tearDown()
    }

    func test_classRun_withBlock_shouldExecuteImmediatelyInSeparateThread() {
        let threadExecuted = expectation(description: "Thread executes")
        let currentThread = Thread.current
        var testThread: Thread?

        DNSThread.run(.asynchronously, in: .highBackground) {
            testThread = Thread.current
            threadExecuted.fulfill()
        }

        wait(for: [threadExecuted], timeout: 0.1)
        XCTAssertNotEqual(currentThread, testThread)
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
        var testCount = 0

        _ = DNSThread.runRepeatedly(in: .highBackground, after: 0.2) { (stop) in
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

    func test_classRunRepeatedly_withAfterDelayAndBlock_shouldNotExecute4TimesBeforeDelay() {
        let threadExecuted = expectation(description: "Thread executes")
        threadExecuted.isInverted = true
        var testCount = 0

        _ = DNSThread.runRepeatedly(in: .highBackground, after: 0.2) { (stop) in
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
}
