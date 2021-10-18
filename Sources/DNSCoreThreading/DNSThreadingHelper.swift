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

public typealias DNSGroupBlock = (DispatchGroup) -> Void

public enum DNSThreading {
    public enum Execution {
        case asynchronously
        case synchronously
    }

    public enum QoSClass {
        case current
        case `default`
        case background
        case highBackground
        case lowBackground
        case uiMain
    }
}

class DNSThreadingHelper {
    static let shared = DNSThreadingHelper()

    @Atomic
    var queues: [String: DispatchQueue] = [:]
    var threadIndex: Int = 0

    // MARK: - run block methods

    func run(_ execution: DNSThreading.Execution = .asynchronously,
             in qos: DNSThreading.QoSClass = .current,
             _ block: DNSBlock?) {
        var name = ""
        let queue: DNSThreadingQueue
        
        self.threadIndex += 1
        
        switch qos {
        case .current:          queue = DNSThreadingQueue.currentQueue
        case .default:          queue = DNSThreadingQueue.defaultQueue;         name = "DNS\(self.threadIndex)DEF"
        case .background:       queue = DNSThreadingQueue.backgroundQueue;      name = "DNS\(self.threadIndex)BACK"
        case .highBackground:   queue = DNSThreadingQueue.highBackgroundQueue;  name = "DNS\(self.threadIndex)HIBK"
        case .lowBackground:    queue = DNSThreadingQueue.lowBackgroundQueue;   name = "DNS\(self.threadIndex)LOBK"
        case .uiMain:           queue = DNSThreadingQueue.uiMainQueue;          name = "DNS\(self.threadIndex)UIMAIN"
        }

        if execution == .synchronously {
            name = name + "_SYNC"
            // if running sync on current queue, just run block...(avoid deadlock)
            guard queue != DNSThreadingQueue.currentQueue else {
                if Thread.current.name?.isEmpty ?? true {
                    Thread.current.name = name
                }
                block?()
                return
            }

            queue.sync {
                if Thread.current.name?.isEmpty ?? true {
                    Thread.current.name = name
                }
                block?()
            }
        } else {
            name = name + "_ASYNC"
            queue.async {
                if Thread.current.name?.isEmpty ?? true {
                    Thread.current.name = name
                }
                Thread.current.name = name
                block?()
            }
        }
    }

    // MARK: - run after delay methods

    func run(in qos: DNSThreading.QoSClass = .current,
             after delay: Double,
             _ block: DNSBlock?) -> Timer? {
        var timer: Timer?

        self.run(.synchronously, in: qos) {
            timer = Timer.scheduledTimer(withTimeInterval:delay, repeats:false) { (_) in
                self.run(in: qos, block)
            }
        }

        return timer
    }

    // MARK: - run repeatedly after delay methods

    func runRepeatedly(in qos: DNSThreading.QoSClass = .current,
                       after delay: Double,
                       _ block: DNSStopBlock?) -> Timer? {
        var timer: Timer?

        self.run(.synchronously, in: qos) {
            timer = Timer.scheduledTimer(withTimeInterval:delay, repeats:true) { (timer) in
                var stop = false
                block?(&stop)
                if stop {
                    timer.invalidate()
                }
            }
        }

        return timer
    }

    // MARK: - run group methods

    func run(group: @escaping DNSGroupBlock,
             then completionBlock: @escaping DNSCompletionBlock) {
        self.run(with: DispatchTime.distantFuture, block: group, then: completionBlock)
    }
    func run(with timeout: DispatchTime,
             block: @escaping DNSGroupBlock,
             then completionBlock: @escaping DNSCompletionBlock) {
        self.run(in: .background) {
            let group = DispatchGroup()
            block(group)

            guard group.wait(timeout: timeout) == DispatchTimeoutResult.success else {
                completionBlock(DNSError.CoreThreading
                                    .groupTimeout(DNSCodeLocation.coreThreading(self, "\(#file),\(#line),\(#function)")))
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

    // MARK: - thread queuing methods

    func queue(for label:String,
               with attributes: DispatchQueue.Attributes? = .concurrent) -> DispatchQueue {
        var queue: DispatchQueue? = self.queues[label]
        guard queue == nil else {
            return queue!
        }
        queue = DispatchQueue.init(label: label,
                                   attributes: attributes ?? .concurrent,
                                   autoreleaseFrequency: .workItem)
        self.queues[label] = queue
        return queue!
    }

    func onQueue(for label:String,
                 run block:@escaping DNSBlock) {
        self.queue(for:label).async(execute: block)
    }

    func onQueue(for label:String,
                 runSynchronous block:@escaping DNSBlock) {
        self.queue(for:label).sync(execute: block)
    }
}
