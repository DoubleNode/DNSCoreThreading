//
//  DNSThreadingQueueTests.swift
//  DNSCoreTests
//
//  Created by Darren Ehlers.
//  Copyright © 2020 - 2016 DoubleNode.com. All rights reserved.
//

import XCTest

@testable import DNSCoreThreading

class DNSThreadingQueueTests: XCTestCase {
    private var sut: DNSThreadingQueue!

    override func setUp() {
        super.setUp()
        sut = DNSThreadingQueue()
    }
    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    func test_zero() {
        XCTFail("Tests not yet implemented in DNSThreadingQueueTests")
    }
}
