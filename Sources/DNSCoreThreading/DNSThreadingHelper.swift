//
//  DNSThreadingHelper.swift
//  DoubleNode Swift Framework (DNSFramework) - DNSCoreThreading
//
//  Created by Darren Ehlers.
//  Copyright © 2020 - 2016 DoubleNode.com. All rights reserved.
//

import AtomicSwift
import DNSError
import Foundation
import os.lock

public typealias DNSGroupBlock = @Sendable (DispatchGroup) -> Void

public enum DNSThreading {
    public enum Execution: Sendable {
        case asynchronously
        case synchronously
    }

    public enum QoSClass: Sendable {
        case current
        case `default`
        case background
        case highBackground
        case lowBackground
        case uiMain
    }
}

final class DNSThreadingHelper: Sendable {
    static let shared = DNSThreadingHelper()

    // Thread-safe queue management
    private let queuesLock = OSAllocatedUnfairLock(initialState: [String: QueueInfo]())
    private let threadIndexLock = OSAllocatedUnfairLock(initialState: 0)
    
    // Store queue info to track attributes
    private struct QueueInfo: Sendable {
        let queue: DispatchQueue
        let attributes: DispatchQueue.Attributes
        let label: String
        
        init(queue: DispatchQueue, attributes: DispatchQueue.Attributes, label: String) {
            self.queue = queue
            self.attributes = attributes
            self.label = label
        }
    }
    
    private var threadIndex: Int {
        get { threadIndexLock.withLock { $0 } }
        set { threadIndexLock.withLock { $0 = newValue } }
    }

    private init() {}

    // MARK: - run block methods

    func run(_ execution: DNSThreading.Execution = .asynchronously,
             in qos: DNSThreading.QoSClass = .current,
             _ block: (@Sendable () -> Void)?) {
        var name = ""
        let queue: DNSThreadingQueue
        
        threadIndexLock.withLock { $0 += 1 }
        let currentIndex = threadIndexLock.withLock { $0 }
        
        switch qos {
        case .current:          queue = DNSThreadingQueue.currentQueue
        case .default:          queue = DNSThreadingQueue.defaultQueue;         name = "DNS\(currentIndex)DEF"
        case .background:       queue = DNSThreadingQueue.backgroundQueue;      name = "DNS\(currentIndex)BACK"
        case .highBackground:   queue = DNSThreadingQueue.highBackgroundQueue;  name = "DNS\(currentIndex)HIBK"
        case .lowBackground:    queue = DNSThreadingQueue.lowBackgroundQueue;   name = "DNS\(currentIndex)LOBK"
        case .uiMain:           queue = DNSThreadingQueue.uiMainQueue;          name = "DNS\(currentIndex)UIMAIN"
        }

        if execution == .synchronously {
            let syncName = name + "_SYNC"
            // if running sync on current queue, just run block...(avoid deadlock)
            guard queue != DNSThreadingQueue.currentQueue else {
                if Thread.current.name?.isEmpty ?? true {
                    Thread.current.name = syncName
                }
                block?()
                return
            }

            queue.sync {
                if Thread.current.name?.isEmpty ?? true {
                    Thread.current.name = syncName
                }
                block?()
            }
        } else {
            let asyncName = name + "_ASYNC"
            queue.async {
                if Thread.current.name?.isEmpty ?? true {
                    Thread.current.name = asyncName
                }
                block?()
            }
        }
    }

    // MARK: - run after delay methods

    func run(in qos: DNSThreading.QoSClass = .current,
             after delay: Double,
             _ block: (@Sendable () -> Void)?) -> Timer? {
        
        let timer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { _ in
            DNSThreadingHelper.shared.run(in: qos, block)
        }
        
        return timer
    }

    // MARK: - run repeatedly after delay methods

    func runRepeatedly(in qos: DNSThreading.QoSClass = .current,
                       after delay: Double,
                       _ block: (@Sendable (inout Bool) -> Void)?) -> Timer? {
        
        let timer = Timer.scheduledTimer(withTimeInterval: delay, repeats: true) { timer in
            var stop = false
            block?(&stop)
            if stop {
                timer.invalidate()
            }
        }
        
        return timer
    }

    // MARK: - run group methods

    func run(group: @escaping DNSGroupBlock,
             then completionBlock: @escaping @Sendable ((any DNSError)?) -> Void) {
        self.run(with: DispatchTime.distantFuture, block: group, then: completionBlock)
    }
    
    func run(with timeout: DispatchTime,
             block: @escaping DNSGroupBlock,
             then completionBlock: @escaping @Sendable ((any DNSError)?) -> Void) {
        self.run(in: .background) {
            let group = DispatchGroup()
            block(group)

            guard group.wait(timeout: timeout) == DispatchTimeoutResult.success else {
                let codeLocation = DNSCoreThreadingCodeLocation(self, "\(#file),\(#line),\(#function)")
                completionBlock(DNSError.CoreThreading.groupTimeout(codeLocation))
                return
            }

            completionBlock(nil)
        }
    }
    
    func enter(group: DispatchGroup) {
        group.enter()
    }
    
    func leave(group: DispatchGroup) {
        group.leave()
    }

    // MARK: - thread queuing methods - FIXED VERSION

    func queue(for label: String,
               with attributes: DispatchQueue.Attributes? = .concurrent) -> DispatchQueue {
        let requestedAttributes = attributes ?? .concurrent
        
        return queuesLock.withLock { queues in
            // Check if we have an existing queue with matching attributes
            if let existingQueueInfo = queues[label] {
                // Verify attributes match - if not, create a new queue
                if existingQueueInfo.attributes == requestedAttributes {
                    return existingQueueInfo.queue
                } else {
                    // Remove old queue and create new one with correct attributes
                    let newQueue = DispatchQueue(
                        label: label,
                        attributes: requestedAttributes,
                        autoreleaseFrequency: .workItem
                    )
                    let newQueueInfo = QueueInfo(
                        queue: newQueue,
                        attributes: requestedAttributes,
                        label: label
                    )
                    queues[label] = newQueueInfo
                    return newQueue
                }
            } else {
                // Create new queue
                let newQueue = DispatchQueue(
                    label: label,
                    attributes: requestedAttributes,
                    autoreleaseFrequency: .workItem
                )
                let newQueueInfo = QueueInfo(
                    queue: newQueue,
                    attributes: requestedAttributes,
                    label: label
                )
                queues[label] = newQueueInfo
                return newQueue
            }
        }
    }

    func onQueue(for label: String,
                 run block: @escaping @Sendable () -> Void) {
        self.queue(for: label).async(execute: block)
    }

    func onQueue(for label: String,
                 runSynchronous block: @escaping @Sendable () -> Void) {
        self.queue(for: label).sync(execute: block)
    }
    
    // MARK: - Debug and Testing Methods
    
    #if DEBUG
    /// Clear all cached queues - useful for testing
    func clearQueueCache() {
        queuesLock.withLock { $0.removeAll() }
    }
    
    /// Get current queue count for testing
    func getCachedQueueCount() -> Int {
        queuesLock.withLock { $0.count }
    }
    
    /// Get queue info for debugging
    func getQueueInfo(for label: String) -> (attributes: DispatchQueue.Attributes, label: String)? {
        queuesLock.withLock { queues in
            guard let queueInfo = queues[label] else { return nil }
            return (attributes: queueInfo.attributes, label: queueInfo.label)
        }
    }
    #endif
}
