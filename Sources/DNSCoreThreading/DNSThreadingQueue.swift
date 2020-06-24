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

public class DNSThreadingQueue {
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
