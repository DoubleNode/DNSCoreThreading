//
//  DNSSynchronize.swift
//  DNSCore
//
//  Created by Darren Ehlers on 8/14/19.
//  Copyright © 2019 DoubleNode.com. All rights reserved.
//

import Foundation

//
// DNSSynchronize - run code in synchronize block
//
// Example Code:
//
//  DNSSynchronize.init(with: self, andRun: {
//      () in
//  }).run()
//

class DNSSynchronize {
    var block:  DNSBlock?
    var object: Any?

    required init(with object: Any? = nil, andRun block: DNSBlock? = nil) {
        self.object = object
        self.block  = block
    }

    public func run() {
        if Thread.isMainThread {
            NSException.init(name: NSExceptionName(rawValue: "\(type(of: self)) Exception"),
                             reason: "In Main Thread",
                             userInfo: [ "FILE": "\(#file)", "LINE": "\(#line)", "FUNCTION": "\(#function)" ]).raise()
        }

        objc_sync_enter(self.object ?? self)
        defer { objc_sync_exit(self.object ?? self) }

        self.block?()
    }
}
