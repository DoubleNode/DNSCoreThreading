//
//  DNSThread.swift
//  DoubleNode Swift Framework (DNSFramework) - DNSCoreThreading
//
//  Created by Darren Ehlers.
//  Copyright © 2020 - 2016 DoubleNode.com. All rights reserved.
//

import Foundation

public typealias DNSBlock = @Sendable () -> Void
public typealias DNSStringBlock = @Sendable (String) -> Void
public typealias DNSStopBlock = @Sendable (inout Bool) -> Void
public typealias DNSThreadBlock = @Sendable (DNSThread) -> Void
public typealias DNSThreadStopBlock = @Sendable (DNSThread, inout Bool) -> Void
public typealias DNSUIThreadBlock = @Sendable (DNSUIThread) -> Void
public typealias DNSUIThreadStopBlock = @Sendable (DNSUIThread, inout Bool) -> Void

//
// DNSThread - run code on background thread
//
// Example Code:
//
//  DNSThread.run {
//      // Background work
//  }
//
// or...
//
//  let thread = DNSThread(.asynchronously) { thread in
//      // Background work
//  }
//  thread.run()
//

public class DNSThread: DNSThreadingGroupProtocol, @unchecked Sendable {
    var block: DNSThreadBlock?
    var stopBlock: DNSThreadStopBlock?
    weak var group: DNSThreadingGroup?

    var execute: DNSThreading.Execution = .asynchronously
    var qos: DNSThreading.QoSClass = .background
    var timer: Timer?

    open class func run(_ execute: DNSThreading.Execution = .asynchronously,
                        in qos: DNSThreading.QoSClass = .background,
                        block: @escaping DNSBlock) {
        self.init(execute, in: qos, with: { _ in block() }).run()
    }

    @discardableResult
    open class func run(in qos: DNSThreading.QoSClass = .background,
                        after delay: Double,
                        block: @escaping DNSBlock) -> Timer? {
        return self.init(.asynchronously, in: qos, with: { _ in
            block()
        }).run(after: delay)
    }

    @discardableResult
    open class func runRepeatedly(in qos: DNSThreading.QoSClass = .background,
                                  after delay: Double,
                                  block: @escaping DNSStopBlock) -> Timer? {
        return self.init(.asynchronously, in: qos, with: { (_, stop) in
            block(&stop)
        }).runRepeatedly(after: delay)
    }

    required public init(_ execute: DNSThreading.Execution = .asynchronously,
                         in qos: DNSThreading.QoSClass = .background,
                         with block: DNSThreadBlock? = nil) {
        self.execute = execute
        self.qos = qos
        self.block = block
    }

    required public init(_ execute: DNSThreading.Execution = .asynchronously,
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

    @discardableResult
    public func run(after delay: Double) -> Timer? {
        self.timer = DNSThreadingHelper.shared.run(in: self.qos, after: delay) {
            guard self.block != nil else {
                var stop = false
                self.stopBlock?(self, &stop)
                return
            }

            self.block?(self)
        }
        return self.timer
    }

    @discardableResult
    public func runRepeatedly(after delay: Double) -> Timer? {
        self.timer = DNSThreadingHelper.shared
            .runRepeatedly(in: self.qos, after: delay) { stop in
            self.stopBlock?(self, &stop) ?? self.block?(self)
        }
        return self.timer
    }

    public func run(in group: DNSThreadingGroup) {
        self.group = group
        run()
    }

    @discardableResult
    public func run(after delay: Double, in group: DNSThreadingGroup) -> Timer? {
        self.group = group
        self.timer = run(after: delay)
        return timer
    }

    public func done() {
        guard let group = group else { return }
        group.completeThread()
        self.group = nil
    }
}

public class DNSHighThread: DNSThread, @unchecked Sendable {
    override public class func run(_ execute: DNSThreading.Execution = .asynchronously,
                                   in qos: DNSThreading.QoSClass = .highBackground,
                                   block: @escaping DNSBlock) {
        self.init(execute, in: qos, with: { _ in block() }).run()
    }

    @discardableResult
    override public class func run(in qos: DNSThreading.QoSClass = .highBackground,
                                   after delay: Double,
                                   block: @escaping DNSBlock) -> Timer? {
        return self.init(.asynchronously, in: qos, with: { _ in
            block()
        }).run(after: delay)
    }

    @discardableResult
    override public class func runRepeatedly(in qos: DNSThreading.QoSClass = .highBackground,
                                             after delay: Double,
                                             block: @escaping DNSStopBlock) -> Timer? {
        return self.init(.asynchronously, in: qos, with: { (_, stop) in
            block(&stop)
        }).runRepeatedly(after: delay)
    }

    required public init(_ execute: DNSThreading.Execution = .asynchronously,
                         in qos: DNSThreading.QoSClass = .highBackground,
                         with block: DNSThreadBlock? = nil) {
        super.init(execute, in: qos, with: block)
    }

    required public init(_ execute: DNSThreading.Execution = .asynchronously,
                         in qos: DNSThreading.QoSClass = .highBackground,
                         with stopBlock: DNSThreadStopBlock? = nil) {
        super.init(execute, in: qos, with: stopBlock)
    }
}

public class DNSLowThread: DNSThread, @unchecked Sendable {
    override public class func run(_ execute: DNSThreading.Execution = .asynchronously,
                                   in qos: DNSThreading.QoSClass = .lowBackground,
                                   block: @escaping DNSBlock) {
        self.init(execute, in: qos, with: { _ in block() }).run()
    }

    @discardableResult
    override public class func run(in qos: DNSThreading.QoSClass = .lowBackground,
                                   after delay: Double,
                                   block: @escaping DNSBlock) -> Timer? {
        return self.init(.asynchronously, in: qos, with: { _ in
            block()
        }).run(after: delay)
    }

    @discardableResult
    override public class func runRepeatedly(in qos: DNSThreading.QoSClass = .lowBackground,
                                             after delay: Double,
                                             block: @escaping DNSStopBlock) -> Timer? {
        return self.init(.asynchronously, in: qos, with: { (_, stop) in
            block(&stop)
        }).runRepeatedly(after: delay)
    }

    required public init(_ execute: DNSThreading.Execution = .asynchronously,
                         in qos: DNSThreading.QoSClass = .lowBackground,
                         with block: DNSThreadBlock? = nil) {
        super.init(execute, in: qos, with: block)
    }

    required public init(_ execute: DNSThreading.Execution = .asynchronously,
                         in qos: DNSThreading.QoSClass = .lowBackground,
                         with stopBlock: DNSThreadStopBlock? = nil) {
        super.init(execute, in: qos, with: stopBlock)
    }
}

@MainActor
public class DNSUIThread: DNSThread, @unchecked Sendable {
    override public class func run(_ execute: DNSThreading.Execution = .synchronously,
                                   in qos: DNSThreading.QoSClass = .uiMain,
                                   block: @escaping DNSBlock) {
        self.init(execute, in: qos, with: { _ in block() }).run()
    }

    @discardableResult
    override public class func run(in qos: DNSThreading.QoSClass = .uiMain,
                                   after delay: Double,
                                   block: @escaping DNSBlock) -> Timer? {
        return self.init(.synchronously, in: qos, with: { _ in
            block()
        }).run(after: delay)
    }

    @discardableResult
    override public class func runRepeatedly(in qos: DNSThreading.QoSClass = .uiMain,
                                             after delay: Double,
                                             block: @escaping DNSStopBlock) -> Timer? {
        return self.init(.synchronously, in: qos, with: { (_, stop) in
            block(&stop)
        }).runRepeatedly(after: delay)
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
