//
//  DNSThreadingQueue.swift
//  DoubleNode Swift Framework (DNSFramework) - DNSCoreThreading
//
//  Created by Darren Ehlers.
//  Copyright © 2020 - 2016 DoubleNode.com. All rights reserved.
//

import Foundation

//
// threadingQueue
//
// Example Code:
//
//  let threadingQueue = DNSThreadingQueue.queue(for: "com.queue.test", with: .serial)
//
//  threadingQueue.run { queue in
//      // Do work here
//  }
//

public typealias DNSThreadingQueueBlock = @Sendable (DNSThreadingQueue) -> Void

public class DNSThreadingQueue: @unchecked Sendable, Equatable {
    // Thread-safe static property access for Swift 6
    public static var currentQueue: DNSThreadingQueue {
        guard let queue = OperationQueue.current?.underlyingQueue else {
            return defaultQueue
        }
        return DNSThreadingQueue(with: queue)
    }
    
    public static var defaultQueue: DNSThreadingQueue {
        return DNSThreadingQueue(with: DispatchQueue.global(qos: .default))
    }
    
    public static var backgroundQueue: DNSThreadingQueue {
        return DNSThreadingQueue(with: DispatchQueue.global(qos: .utility))
    }
    
    public static var highBackgroundQueue: DNSThreadingQueue {
        return DNSThreadingQueue(with: DispatchQueue.global(qos: .userInitiated))
    }
    
    public static var lowBackgroundQueue: DNSThreadingQueue {
        return DNSThreadingQueue(with: DispatchQueue.global(qos: .background))
    }
    
    public static var uiMainQueue: DNSThreadingQueue {
        return DNSThreadingQueue(with: DispatchQueue.main)
    }

    public let label: String
    public let queue: DispatchQueue
    public let attributes: DispatchQueue.Attributes?

    @discardableResult
    public static func queue(for label: String,
                            with attributes: DispatchQueue.Attributes = .concurrent,
                            run block: DNSThreadingQueueBlock? = nil) -> DNSThreadingQueue {
        let queue = DNSThreadingQueue(with: label, and: attributes)
        if let block = block {
            queue.run(block: block)
        }
        return queue
    }

    public init(with label: String = "DNSThreadingQueue",
                and attributes: DispatchQueue.Attributes? = .concurrent) {
        self.label = label
        self.attributes = attributes
        self.queue = DNSThreadingHelper.shared.queue(for: self.label, with: self.attributes)
    }
    
    public init(with queue: DispatchQueue) {
        self.label = queue.label
        self.queue = queue
        self.attributes = nil
    }

    public func run(block: @escaping DNSThreadingQueueBlock) {
        DNSThreadingHelper.shared.onQueue(for: self.label, run: {
            block(self)
        })
    }

    public func runSynchronously(block: @escaping DNSThreadingQueueBlock) {
        DNSThreadingHelper.shared.onQueue(for: self.label, runSynchronous: {
            block(self)
        })
    }
    
    public func sync(execute block: @Sendable () -> Void) {
        self.queue.sync(execute: block)
    }
    
    public func async(group: DispatchGroup? = nil,
                     qos: DispatchQoS = .unspecified,
                     flags: DispatchWorkItemFlags = [],
                     execute work: @escaping @Sendable () -> Void) {
        self.queue.async(group: group, qos: qos, flags: flags, execute: work)
    }

    // MARK: - Equatable protocol methods -

    public static func == (lhs: DNSThreadingQueue, rhs: DNSThreadingQueue) -> Bool {
        return lhs.queue == rhs.queue
    }
}

public final class DNSSynchronousThreadingQueue: DNSThreadingQueue, @unchecked Sendable {
    @discardableResult
    public static func queue(for label: String,
                            run block: DNSThreadingQueueBlock? = nil) -> DNSSynchronousThreadingQueue {
        let queue = DNSSynchronousThreadingQueue(with: label, and: .initiallyInactive)
        if let block = block {
            queue.run(block: block)
        }
        return queue
    }

    public override func run(block: @escaping DNSThreadingQueueBlock) {
        super.runSynchronously(block: block)
    }
}
