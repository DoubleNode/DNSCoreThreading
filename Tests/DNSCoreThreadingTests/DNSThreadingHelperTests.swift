//
//  DNSThreadingHelperTests.swift
//  DoubleNode Swift Framework (DNSFramework) - DNSCoreThreadingTests
//
//  Created by Darren Ehlers.
//  Copyright © 2020 - 2016 DoubleNode.com. All rights reserved.
//

import XCTest

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
}
