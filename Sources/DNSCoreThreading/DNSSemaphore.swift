//
//  DNSSemaphore.swift
//  DoubleNode Swift Framework (DNSFramework) - DNSCoreThreading
//
//  Created by Darren Ehlers.
//  Copyright © 2020 - 2016 DoubleNode.com. All rights reserved.
//

import AtomicSwift
import Foundation

public class DNSSemaphore: @unchecked Sendable {
    @Atomic private var semaphore: DispatchSemaphore

    public init(count: Int = 0) {
        semaphore = DispatchSemaphore(value: count)
    }

    @discardableResult
    public func done() -> Int {
        return semaphore.signal()
    }

    @discardableResult
    public func wait() -> DispatchTimeoutResult {
        return self.wait(until: DispatchTime.distantFuture)
    }

    @discardableResult
    public func wait(until timeout: DispatchTime) -> DispatchTimeoutResult {
        return semaphore.wait(timeout: timeout)
    }
}

public final class DNSSemaphoreGate: DNSSemaphore, @unchecked Sendable {
    public init() {
        super.init(count: 0)
    }
    
    public override init(count: Int = 1) {
        super.init(count: count)
    }
}
