//
//  DNSThreadingGroup.swift
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
//  DNCThreadingQueue*  threadingQueue = [DNCThreadingQueue queueForLabel:@"com.queue.test"
//                                                          withAttribute:DISPATCH_QUEUE_SERIAL];
//
//  [threadingQueue run:
//   ^()
//   {
//   }];
//

public typealias DNSThreadingQueueBlock = (DNSThreadingQueue) -> Void

public class DNSThreadingQueue: Equatable {
    var label:      String = ""
    var queue:      DispatchQueue?
    var attributes: DispatchQueue.Attributes?

    public class func queue(for label: String,
                            with attributes: DispatchQueue.Attributes = .concurrent,
                            run block: DNSThreadingQueueBlock? = nil) -> DNSThreadingQueue {
        let queue = DNSThreadingQueue.init(with: label, and: attributes)
        if block != nil {
            queue.run(block: block!)
        }
        return queue
    }

    required public init(with label: String = "DNSThreadingQueue",
                         and attributes: DispatchQueue.Attributes? = .concurrent) {
        self.label      = label
        self.attributes = attributes
        self.queue      = DNSThreadingHelper.shared.queue(for: self.label, with: self.attributes)
    }
    required public init(with queue: DispatchQueue) {
        self.label  = queue.label
        self.queue  = queue
    }

    open func run(block: @escaping DNSThreadingQueueBlock) {
        DNSThreadingHelper.shared.onQueue(for: self.label, run: {
            block(self)
        })
    }

    public func runSynchronously(block: @escaping DNSThreadingQueueBlock) {
        DNSThreadingHelper.shared.onQueue(for: self.label, runSynchronous: {
            block(self)
        })
    }
    
    public func sync(execute block: () -> Void) {
        self.queue?.sync(execute: block)
    }
    public func async(group: DispatchGroup? = nil, qos: DispatchQoS = .unspecified, flags: DispatchWorkItemFlags = [], execute work: @escaping @convention(block) () -> Void) {
        self.queue?.async(execute: work)
    }

    // MARK: - Equatable protocol methods -

    static public func == (lhs: DNSThreadingQueue, rhs: DNSThreadingQueue) -> Bool {
        return lhs.queue == rhs.queue
    }
}

public class DNSSynchronousThreadingQueue: DNSThreadingQueue {
    public class func queue(for label: String,
                            run block: DNSThreadingQueueBlock? = nil) -> DNSSynchronousThreadingQueue {
        let queue = DNSSynchronousThreadingQueue.init(with: label, and: .initiallyInactive)
        if block != nil {
            queue.run(block: block!)
        }
        return queue
    }

    override public func run(block: @escaping DNSThreadingQueueBlock) {
        super.runSynchronously(block: block)
    }
}
