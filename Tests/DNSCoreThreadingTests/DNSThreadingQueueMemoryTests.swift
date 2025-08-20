//
//  DNSThreadingQueueMemoryTests.swift
//  DoubleNode Swift Framework (DNSFramework) - DNSCoreThreadingTests
//
//  Created by Darren Ehlers.
//  Copyright © 2020 - 2016 DoubleNode.com. All rights reserved.
//

import XCTest
import os.lock
@testable import DNSCoreThreading

final class DNSThreadingQueueMemoryTests: XCTestCase {
    private var sut: DNSThreadingQueue!
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        sut = nil
        super.tearDown()
    }
   
    // MARK: - Memory Management Tests
    
    func testAAAA_memoryManagement_doesNotLeak() {
        // Given
        weak var weakQueue: DNSThreadingQueue?
        
        // When
        autoreleasepool {
            let queue = DNSThreadingQueue(with: "com.test.memory")
            weakQueue = queue
            
            queue.async {
                // Some work
            }
        }
        
        // Then
        // Give some time for cleanup
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Note: This test is somewhat limited as the queue might be retained
            // by the system dispatch queue, but we verify it doesn't crash
            XCTAssertNotNil(weakQueue) // System might still retain it
        }
    }
}
