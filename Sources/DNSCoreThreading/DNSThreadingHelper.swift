//
//  DNSThreadingHelper.swift
//  DNSCore
//
//  Created by Darren Ehlers.
//  Copyright © 2020 - 2016 DoubleNode.com. All rights reserved.
//

import Foundation

public typealias DNSGroupBlock = (DispatchGroup) -> Void

public enum DNSThreadingError: Error {
    case groupTimeout(domain: String, file: String, line: String, method: String)
}

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

    var queues: [String: DispatchQueue] = [:]

    // MARK: - run block methods

    func run(_ execution: DNSThreading.Execution = .synchronously,
             in qos: DNSThreading.QoSClass = .current,
             _ block: DNSBlock?) {
        var name = ""
        let queue: DispatchQueue

        switch qos {
        case .current:          queue = OperationQueue.current!.underlyingQueue!
        case .default:          queue = DispatchQueue.global(qos: .default);        name = "DNS_\(qos)"
        case .background:       queue = DispatchQueue.global(qos: .utility);        name = "DNS_\(qos)"
        case .highBackground:   queue = DispatchQueue.global(qos: .userInitiated);  name = "DNS_\(qos)"
        case .lowBackground:    queue = DispatchQueue.global(qos: .background);     name = "DNS_\(qos)"
        case .uiMain:           queue = DispatchQueue.main
        }

        if execution == .synchronously {
            // if running sync on current queue, just run block...(avoid deadlock)
            guard queue != OperationQueue.current?.underlyingQueue else {
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
                completionBlock(DNSThreadingError.groupTimeout(domain: "com.doublenode.\(type(of: self))",
                    file: "\(#file)",
                    line: "\(#line)",
                    method: "\(#function)"))
                return
            }

            completionBlock(nil)
        }
    }

    func enter(group: DispatchGroup?) {
        group?.enter()
    }

    func leave(group: DispatchGroup?) {
        group?.leave()
    }

    // MARK: - thread queuing methods

    func queue(for label:String,
               with attributes: DispatchQueue.Attributes? = .concurrent) -> DispatchQueue? {
        var queue: DispatchQueue? = self.queues[label]
        if queue == nil {
            queue = DispatchQueue.init(label: label,
                                       attributes: attributes ?? .concurrent,
                                       autoreleaseFrequency: .workItem)
            self.queues[label] = queue
        }
        return queue
    }

    func onQueue(for label:String,
                 run block:@escaping DNSBlock) {
        self.queue(for:label)?.async(execute: block)
    }

    func onQueue(for label:String,
                 runSynchronous block:@escaping DNSBlock) {
        self.queue(for:label)?.sync(execute: block)
    }
}
