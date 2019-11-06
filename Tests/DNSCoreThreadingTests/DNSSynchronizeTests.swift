//
//  DNSSynchronizeTests.m
//  DNSCoreTests
//
//  Created by Darren Ehlers on 10/23/16.
//  Copyright © 2019 - 2016 DoubleNode.com. All rights reserved.
//

import XCTest

@testable import DNSCoreThreading

class DNSSynchronizeTests: XCTestCase {
    private var sut: DNSSynchronize!

    override func setUp() {
        super.setUp()
        sut = DNSSynchronize()
    }
    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    func test_zero() {
        XCTFail("Tests not yet implemented in DNSSynchronizeTests")
    }
}
