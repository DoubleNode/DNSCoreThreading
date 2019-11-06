//
//  DNSThread.swift
//  DNSCore
//
//  Created by Darren Ehlers on 8/14/19.
//  Copyright © 2019 DoubleNode.com. All rights reserved.
//

import Foundation

public typealias DNSBlock = () -> Void
public typealias DNSStopBlock = (inout Bool) -> Void
public typealias DNSThreadBlock = (DNSThread) -> Void
public typealias DNSThreadStopBlock = (DNSThread, inout Bool) -> Void
public typealias DNSUIThreadBlock = (DNSUIThread) -> Void
public typealias DNSUIThreadStopBlock = (DNSUIThread, inout Bool) -> Void

//
// DNCThread - run code on background thread
//
// Example Code:
//
//  [DNCThread run:
//   ^()
//   {
//   }];
//
// or...
//
//  DNCThread* thread = [DNCThread create:
//   ^(DNCThread* thread)
//   {
//   }];
//
//  [thread run];
//

public class DNSThread: DNSThreadingGroupProtocol {
    var block: DNSThreadBlock?
    var stopBlock: DNSThreadStopBlock?
    var group: DNSThreadingGroup?

    open class func run(_ execute: DNSThreading.Execution = .synchronously,
                        in qos: DNSThreading.QoSClass = .background,
                        block: @escaping DNSBlock) {
        self.init(with: { (_) in block() }).run(execute, in: qos)
    }

    open class func run(in qos: DNSThreading.QoSClass = .background,
                        after delay: Double,
                        block: @escaping DNSBlock) -> Timer? {
        return self.init(with: { (_) in block() }).run(in: qos, after: delay)
    }

    open class func runRepeatedly(in qos: DNSThreading.QoSClass = .background,
                                  after delay: Double,
                                  block: @escaping DNSStopBlock) -> Timer? {
        return self.init(with: { (_, stop) in block(&stop) }).runRepeatedly(in: qos, after: delay)
    }

    required init(with block: DNSThreadBlock? = nil) {
        self.block = block
    }

    required init(with stopBlock: DNSThreadStopBlock? = nil) {
        self.stopBlock = stopBlock
    }

    public func run(_ execute: DNSThreading.Execution = .synchronously,
                    in qos: DNSThreading.QoSClass = .background) {
        DNSThreadingHelper.shared.run(execute, in: qos) {
            guard self.block != nil else {
                var stop = false
                self.stopBlock?(self, &stop)
                return
            }

            self.block?(self)
        }
    }

    public func run(in qos: DNSThreading.QoSClass = .background, after delay: Double) -> Timer? {
        return DNSThreadingHelper.shared.run(in: qos, after: delay) {
            guard self.block != nil else {
                var stop = false
                self.stopBlock?(self, &stop)
                return
            }

            self.block?(self)
        }
    }

    public func runRepeatedly(in qos: DNSThreading.QoSClass = .background, after delay: Double) -> Timer? {
        return DNSThreadingHelper.shared.runRepeatedly(in: qos, after: delay) { (stop) in
            self.stopBlock?(self, &stop) ?? self.block?(self)
        }
    }

    public func run(in group: DNSThreadingGroup) {
        self.group = group
        run()
    }

    public func run(after delay: Double, in group: DNSThreadingGroup) -> Timer? {
        self.group = group
        return run(after: delay)
    }

    public func done() {
        group?.completeThread()
    }
}

public class DNSHighThread: DNSThread {
    override public func run(_ execute: DNSThreading.Execution = .synchronously,
                             in qos: DNSThreading.QoSClass = .highBackground) {
        super.run(execute, in: qos)
    }

    override public func run(in qos: DNSThreading.QoSClass = .highBackground,
                             after delay: Double) -> Timer? {
        return super.run(in: qos, after: delay)
    }

    override public func runRepeatedly(in qos: DNSThreading.QoSClass = .highBackground,
                                       after delay: Double) -> Timer? {
        return super.runRepeatedly(in: qos, after: delay)
    }
}

public class DNSLowThread: DNSThread {
    override public func run(_ execute: DNSThreading.Execution = .synchronously,
                             in qos: DNSThreading.QoSClass = .lowBackground) {
        super.run(execute, in: qos)
    }

    override public func run(in qos: DNSThreading.QoSClass = .lowBackground,
                             after delay: Double) -> Timer? {
        return super.run(in: qos, after: delay)
    }

    override public func runRepeatedly(in qos: DNSThreading.QoSClass = .lowBackground,
                                       after delay: Double) -> Timer? {
        return super.runRepeatedly(in: qos, after: delay)
    }
}

public class DNSUIThread: DNSThread {
    required init(with block: DNSUIThreadBlock? = nil) {
        super.init { (thread) in
            // swiftlint:disable:next force_cast
            block?(thread as! DNSUIThread)
        }
    }

    required init(with stopBlock: DNSUIThreadStopBlock? = nil) {
        super.init { (thread, stop) in
            // swiftlint:disable:next force_cast
            stopBlock?(thread as! DNSUIThread, &stop)
        }
    }

    override public func run(_ execute: DNSThreading.Execution = .synchronously,
                             in qos: DNSThreading.QoSClass = .uiMain) {
        super.run(execute, in: qos)
    }

    override public func run(in qos: DNSThreading.QoSClass = .uiMain,
                             after delay: Double) -> Timer? {
        return super.run(in: qos, after: delay)
    }

    override public func runRepeatedly(in qos: DNSThreading.QoSClass = .uiMain,
                                       after delay: Double) -> Timer? {
        return super.runRepeatedly(in: qos, after: delay)
    }
}
