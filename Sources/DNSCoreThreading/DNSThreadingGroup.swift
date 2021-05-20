//
//  DNSThreadingGroup.swift
//  DoubleNode Swift Framework (DNSFramework) - DNSCoreThreading
//
//  Created by Darren Ehlers.
//  Copyright © 2020 - 2016 DoubleNode.com. All rights reserved.
//

import DNSError
import Foundation

public typealias DNSCompletionBlock = (DNSError?) -> Void
public typealias DNSThreadingGroupBlock = (DNSThreadingGroup) -> Void

public protocol DNSThreadingGroupProtocol: AnyObject {
    func run(in group: DNSThreadingGroup)
    func done()
}

//
// threadingGroup
//
// Example Code:
//
//  DNSThread* thread1 = [DNSThread create:
//   ^(DNSThread* thread)
//   {
//       // Do background work here
//       [thread done];
//   }];
//
//  DNSThread* thread2 = [DNSThread create:
//   ^(DNSThread* thread)
//   {
//       // Do background work here
//       [thread done];
//   }];
//
//  DNSThread* thread3 = [DNSThread create:
//   ^(DNSThread* thread)
//   {
//       // Do background work here
//       [thread done];
//   }];
//
//  DNSThread* uiThread = [DNSThread create:
//   ^(DNSThread* thread)
//   {
//       // Do main thread UI work here
//       [thread done];
//   }];
//
//  [DNSThreadingGroup run:
//   ^(DNSThreadingGroup* threadingGroup)
//   {
//       [threadingGroup runThread:uiThread];
//
//       [threadingGroup runThread:thread1];
//       [threadingGroup runThread:thread2];
//       [threadingGroup runThread:thread3];
//   }
//               then:
//   ^()
//   {
//       // This runs after all threads are "done" or after timeout
//   }];
//

public class DNSThreadingGroup {
    var group: DispatchGroup?
    var threads: [DNSThreadingGroupProtocol] = []

    class public func run(block: @escaping DNSThreadingGroupBlock,
                          then completionBlock: @escaping DNSCompletionBlock) -> DNSThreadingGroup {
        let group = DNSThreadingGroup()
        group.run(block: {
            block(group)
        }, then: completionBlock)

        return group
    }

    class public func run(block: @escaping DNSThreadingGroupBlock,
                          with timeout:DispatchTime,
                          then completionBlock: @escaping DNSCompletionBlock) -> DNSThreadingGroup {
        let group = DNSThreadingGroup()
        group.run(block: {
            block(group)
        }, with: timeout, then: completionBlock)

        return group
    }

    public func run(_ thread: DNSThreadingGroupProtocol) {
        self.startThread()
        self.threads.append(thread)
    }

    public func run(block: @escaping DNSBlock,
                    then completionBlock: @escaping DNSCompletionBlock) {
        self.run(block: block, with: DispatchTime.distantFuture, then: completionBlock)
    }

    public func run(block: @escaping DNSBlock,
                    with timeout:DispatchTime,
                    then completionBlock: @escaping DNSCompletionBlock) {
        DNSThreadingHelper.shared.run(with:timeout, block: { (group: DispatchGroup) in
            self.group      = group
            self.threads    = []
            block()

            for thread: DNSThreadingGroupProtocol in self.threads {
                thread.run(in:self)
            }
        }, then: completionBlock)
    }

    public func startThread() {
        DNSThreadingHelper.shared.enter(group: self.group)
    }

    public func completeThread() {
        DNSThreadingHelper.shared.leave(group: self.group)
    }
}
