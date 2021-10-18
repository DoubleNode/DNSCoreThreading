//
//  DNSSemaphore.swift
//  DoubleNode Swift Framework (DNSFramework) - DNSCoreThreading
//
//  Created by Darren Ehlers.
//  Copyright © 2020 - 2016 DoubleNode.com. All rights reserved.
//

import AtomicSwift
import Foundation

public class DNSSemaphore {
    @Atomic var semaphore: DispatchSemaphore

    required public init(count: Int = 1) {
        semaphore = DispatchSemaphore(value: count)
    }

    @discardableResult
    public func done() -> Int {
        return semaphore.signal()
    }

    @discardableResult
    public func wait() -> DispatchTimeoutResult {
        return self.wait(until:DispatchTime.distantFuture)
    }

    @discardableResult
    public func wait(until timeout:DispatchTime) -> DispatchTimeoutResult {
        return semaphore.wait(timeout: timeout)
    }
}
public class DNSSemaphoreGate: DNSSemaphore {
    required public init(count: Int = 1) {
        super.init(count: count)
    }
}
