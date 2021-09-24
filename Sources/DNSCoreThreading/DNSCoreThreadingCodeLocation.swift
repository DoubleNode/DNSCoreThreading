//
//  DNSCoreThreadingCodeLocation.swift
//  DoubleNode Swift Framework (DNSFramework) - DNSCoreThreading
//
//  Created by Darren Ehlers.
//  Copyright © 2020 - 2016 DoubleNode.com. All rights reserved.
//

import DNSError

public extension DNSCodeLocation {
    typealias coreThreading = DNSCoreThreadingCodeLocation
}
open class DNSCoreThreadingCodeLocation: DNSCodeLocation {
    override open class var domainPreface: String { "com.doublenode.coreThreading." }
}
