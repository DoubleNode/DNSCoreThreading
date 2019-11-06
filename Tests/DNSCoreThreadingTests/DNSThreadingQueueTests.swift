//
//  DNSThreadingQueueTests.m
//  DNSCoreTests
//
//  Created by Darren Ehlers on 10/23/16.
//  Copyright © 2019 - 2016 DoubleNode.com. All rights reserved.
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
