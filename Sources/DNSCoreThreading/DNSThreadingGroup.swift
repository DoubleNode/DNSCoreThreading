//
//  DNSThreadingGroup.swift
//  DoubleNode Swift Framework (DNSFramework) - DNSCoreThreading
//
//  Created by Darren Ehlers.
//  Copyright © 2020 - 2016 DoubleNode.com. All rights reserved.
//

import DNSError
import Foundation
import os.lock

public typealias DNSCompletionBlock = @Sendable ((any DNSError)?) -> Void
public typealias DNSThreadingGroupBlock = @Sendable (DNSThreadingGroup) -> Void

public protocol DNSThreadingGroupProtocol: AnyObject, Sendable {
    func run(in group: DNSThreadingGroup)
    func done()
}

//
// threadingGroup
//
// Example Code:
//
//  let thread1 = DNSThread(.asynchronously) { thread in
//      // Do background work here
//      thread.done()
//  }
//
//  let thread2 = DNSThread(.asynchronously) { thread in
//      // Do background work here
//      thread.done()
//  }
//
//  DNSThreadingGroup.run { threadingGroup in
//      threadingGroup.run(thread1)
//      threadingGroup.run(thread2)
//  } then: { error in
//      // This runs after all threads are "done" or after timeout
//  }
//

public final class DNSThreadingGroup: @unchecked Sendable {
    public let name: String

    var count: Int {
        guard let group = self.group else { return -2 }
        return group.debugDescription.components(separatedBy: ",")
            .filter({$0.contains("count")})
            .first?.components(separatedBy: CharacterSet.decimalDigits.inverted)
            .compactMap{Int($0)}.first ?? -1
    }
    
    private let groupLock = OSAllocatedUnfairLock<DispatchGroup?>(initialState: nil)
    private let threadsLock = OSAllocatedUnfairLock<[any DNSThreadingGroupProtocol]>(initialState: [])
    
    private var group: DispatchGroup? {
        get { groupLock.withLock { $0 } }
        set { groupLock.withLock { $0 = newValue } }
    }
    
    private var threads: [any DNSThreadingGroupProtocol] {
        get { threadsLock.withLock { $0 } }
        set { threadsLock.withLock { $0 = newValue } }
    }

    @discardableResult
    public static func run(_ name: String = "",
                          block: @escaping DNSThreadingGroupBlock,
                          then completionBlock: @escaping DNSCompletionBlock) -> DNSThreadingGroup {
        let threadingGroup = DNSThreadingGroup(name)
        
        // Use modern async pattern instead of Task for better Swift 6 compatibility
        Task.detached {
            await threadingGroup.runAsync(block: {
                threadingGroup.run(DNSLowThread(.asynchronously) { thread in
                    block(threadingGroup)
                    thread.done()
                })
            }, then: completionBlock)
        }
        return threadingGroup
    }
    
    @discardableResult
    public static func run(_ name: String = "",
                          block: @escaping DNSThreadingGroupBlock,
                          with timeout: DispatchTime,
                          then completionBlock: @escaping DNSCompletionBlock) -> DNSThreadingGroup {
        let threadingGroup = DNSThreadingGroup(name)
        
        Task.detached {
            await threadingGroup.runAsync(block: {
                block(threadingGroup)
            }, with: timeout, then: completionBlock)
        }
        return threadingGroup
    }

    public init(_ name: String = "") {
        self.name = name.isEmpty ? String.dnsRandom() : name
    }
    
    public func run(_ thread: any DNSThreadingGroupProtocol) {
        self.startThread()
        threadsLock.withLock { $0.append(thread) }
    }

    public func run(block: @escaping @Sendable () -> Void,
                    then completionBlock: @escaping DNSCompletionBlock) {
        Task.detached {
            await self.runAsync(block: block, with: DispatchTime.distantFuture, then: completionBlock)
        }
    }

    public func run(block: @escaping @Sendable () -> Void,
                    with timeout: DispatchTime,
                    then completionBlock: @escaping DNSCompletionBlock) {
        Task.detached {
            await self.runAsync(block: block, with: timeout, then: completionBlock)
        }
    }
    
    // Internal async method for proper Swift 6 concurrency
    private func runAsync(block: @escaping @Sendable () -> Void,
                         then completionBlock: @escaping DNSCompletionBlock) async {
        await runAsync(block: block, with: DispatchTime.distantFuture, then: completionBlock)
    }
    
    private func runAsync(block: @escaping @Sendable () -> Void,
                         with timeout: DispatchTime,
                         then completionBlock: @escaping DNSCompletionBlock) async {
        await withCheckedContinuation { continuation in
            DNSThreadingHelper.shared.run(with: timeout, block: { (group: DispatchGroup) in
                self.group = group
                self.threadsLock.withLock { $0.removeAll() }
                block()

                let currentThreads = self.threadsLock.withLock { $0 }
                for thread in currentThreads {
                    thread.run(in: self)
                }
            }, then: { error in
                completionBlock(error)
                continuation.resume()
            })
        }
    }

    public func startThread() {
        guard let group = self.group else { return }
        DNSThreadingHelper.shared.enter(group: group)
    }
    
    public func completeThread() {
        guard let group = self.group else { return }
        DNSThreadingHelper.shared.leave(group: group)
    }
}

extension String {
    @discardableResult
    static public func dnsRandom(_ n: Int = 16) -> String {
        let digits = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890"
        return String(Array(0..<n).map { _ in digits.randomElement()! })
    }
}
