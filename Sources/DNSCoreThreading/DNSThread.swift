//
//  DNSThread.swift
//  DoubleNode Swift Framework (DNSFramework) - DNSCoreThreading
//
//  Created by Darren Ehlers.
//  Copyright © 2020 - 2016 DoubleNode.com. All rights reserved.
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

    var execute: DNSThreading.Execution = .synchronously
    var qos: DNSThreading.QoSClass = .background
    
    open class func run(_ execute: DNSThreading.Execution = .synchronously,
                        in qos: DNSThreading.QoSClass = .background,
                        block: @escaping DNSBlock) {
        self.init(execute, in: qos, with: { (_) in block() }).run()
    }

    open class func run(in qos: DNSThreading.QoSClass = .background,
                        after delay: Double,
                        block: @escaping DNSBlock) -> Timer? {
        return self.init(.asynchronously, in: qos, with: { (_) in block() }).run(after: delay)
    }

    open class func runRepeatedly(in qos: DNSThreading.QoSClass = .background,
                                  after delay: Double,
                                  block: @escaping DNSStopBlock) -> Timer? {
        return self.init(.asynchronously, in: qos, with: { (_, stop) in block(&stop) }).runRepeatedly(after: delay)
    }

    required public init(_ execute: DNSThreading.Execution = .synchronously,
                         in qos: DNSThreading.QoSClass = .background,
                         with block: DNSThreadBlock? = nil) {
        self.execute = execute
        self.qos = qos
        self.block = block
    }

    required public init(_ execute: DNSThreading.Execution = .synchronously,
                         in qos: DNSThreading.QoSClass = .background,
                         with stopBlock: DNSThreadStopBlock? = nil) {
        self.execute = execute
        self.qos = qos
        self.stopBlock = stopBlock
    }

    public func run() {
        DNSThreadingHelper.shared.run(self.execute, in: self.qos) {
            guard self.block != nil else {
                var stop = false
                self.stopBlock?(self, &stop)
                return
            }

            self.block?(self)
        }
    }

    public func run(after delay: Double) -> Timer? {
        return DNSThreadingHelper.shared.run(in: self.qos, after: delay) {
            guard self.block != nil else {
                var stop = false
                self.stopBlock?(self, &stop)
                return
            }

            self.block?(self)
        }
    }

    public func runRepeatedly(after delay: Double) -> Timer? {
        return DNSThreadingHelper.shared.runRepeatedly(in: self.qos, after: delay) { (stop) in
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
    override public class func run(_ execute: DNSThreading.Execution = .synchronously,
                                   in qos: DNSThreading.QoSClass = .highBackground,
                                   block: @escaping DNSBlock) {
        self.init(execute, in: qos, with: { (_) in block() }).run()
    }

    override public class func run(in qos: DNSThreading.QoSClass = .highBackground,
                                   after delay: Double,
                                   block: @escaping DNSBlock) -> Timer? {
        return self.init(.synchronously, in: qos, with: { (_) in block() }).run(after: delay)
    }

    override public class func runRepeatedly(in qos: DNSThreading.QoSClass = .highBackground,
                                             after delay: Double,
                                             block: @escaping DNSStopBlock) -> Timer? {
        return self.init(.synchronously, in: qos, with: { (_, stop) in block(&stop) }).runRepeatedly(after: delay)
    }

    required public init(_ execute: DNSThreading.Execution = .synchronously,
                         in qos: DNSThreading.QoSClass = .highBackground,
                         with block: DNSThreadBlock? = nil) {
        super.init(execute, in: qos, with: block)
    }

    required public init(_ execute: DNSThreading.Execution = .synchronously,
                         in qos: DNSThreading.QoSClass = .highBackground,
                         with stopBlock: DNSThreadStopBlock? = nil) {
        super.init(execute, in: qos, with: stopBlock)
    }
}

public class DNSLowThread: DNSThread {
    override public class func run(_ execute: DNSThreading.Execution = .synchronously,
                                   in qos: DNSThreading.QoSClass = .lowBackground,
                                   block: @escaping DNSBlock) {
        self.init(execute, in: qos, with: { (_) in block() }).run()
    }

    override public class func run(in qos: DNSThreading.QoSClass = .lowBackground,
                                   after delay: Double,
                                   block: @escaping DNSBlock) -> Timer? {
        return self.init(.synchronously, in: qos, with: { (_) in block() }).run(after: delay)
    }

    override public class func runRepeatedly(in qos: DNSThreading.QoSClass = .lowBackground,
                                             after delay: Double,
                                             block: @escaping DNSStopBlock) -> Timer? {
        return self.init(.synchronously, in: qos, with: { (_, stop) in block(&stop) }).runRepeatedly(after: delay)
    }

    required public init(_ execute: DNSThreading.Execution = .synchronously,
                         in qos: DNSThreading.QoSClass = .lowBackground,
                         with block: DNSThreadBlock? = nil) {
        super.init(execute, in: qos, with: block)
    }

    required public init(_ execute: DNSThreading.Execution = .synchronously,
                         in qos: DNSThreading.QoSClass = .lowBackground,
                         with stopBlock: DNSThreadStopBlock? = nil) {
        super.init(execute, in: qos, with: stopBlock)
    }
}

public class DNSUIThread: DNSThread {
    override public class func run(_ execute: DNSThreading.Execution = .synchronously,
                                   in qos: DNSThreading.QoSClass = .uiMain,
                                   block: @escaping DNSBlock) {
        self.init(execute, in: qos, with: { (_) in block() }).run()
    }

    override public class func run(in qos: DNSThreading.QoSClass = .uiMain,
                                   after delay: Double,
                                   block: @escaping DNSBlock) -> Timer? {
        return self.init(.synchronously, in: qos, with: { (_) in block() }).run(after: delay)
    }

    override public class func runRepeatedly(in qos: DNSThreading.QoSClass = .uiMain,
                                             after delay: Double,
                                             block: @escaping DNSStopBlock) -> Timer? {
        return self.init(.synchronously, in: qos, with: { (_, stop) in block(&stop) }).runRepeatedly(after: delay)
    }

    required public init(_ execute: DNSThreading.Execution = .synchronously,
                         in qos: DNSThreading.QoSClass = .uiMain,
                         with block: DNSThreadBlock? = nil) {
        super.init(execute, in: qos, with: block)
    }

    required public init(_ execute: DNSThreading.Execution = .synchronously,
                         in qos: DNSThreading.QoSClass = .uiMain,
                         with stopBlock: DNSThreadStopBlock? = nil) {
        super.init(execute, in: qos, with: stopBlock)
    }
}
