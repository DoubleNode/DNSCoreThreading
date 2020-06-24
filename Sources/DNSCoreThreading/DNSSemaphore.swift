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

    required public init(count: Int = 0) {
        semaphore = DispatchSemaphore(value: count)
    }

    public func done() -> Int {
        return semaphore.signal()
    }

    public func wait() -> DispatchTimeoutResult {
        return self.wait(until:DispatchTime.distantFuture)
    }

    public func wait(until timeout:DispatchTime) -> DispatchTimeoutResult {
        return semaphore.wait(timeout: timeout)
    }
}

public class DNSSemaphoreGate: DNSSemaphore {
    required public init() {
        super.init(count: 0)
    }

    required public init(count: Int) {
        super.init(count: count)
    }
}
