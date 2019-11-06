//
//  DNSSemaphore.swift
//  DNSCore
//
//  Created by Darren Ehlers on 8/14/19.
//  Copyright © 2019 DoubleNode.com. All rights reserved.
//

import AtomicSwift
import Foundation

class DNSSemaphore {
    @Atomic var semaphore: DispatchSemaphore

    required init(count: Int = 0) {
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

class DNSSemaphoreGate: DNSSemaphore {
    required init() {
        super.init(count: 0)
    }

    required init(count: Int) {
        super.init(count: count)
    }
}
