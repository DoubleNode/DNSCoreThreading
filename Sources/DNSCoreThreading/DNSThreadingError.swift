//
//  DNSThreadingError.swift
//  DoubleNode Swift Framework (DNSFramework) - DNSCoreThreading
//
//  Created by Darren Ehlers.
//  Copyright © 2020 - 2016 DoubleNode.com. All rights reserved.
//

import DNSError
import Foundation

public enum DNSThreadingError: Error {
    case groupTimeout(_ codeLocation: CodeLocation)
}
extension DNSThreadingError: DNSError {
    public static let domain = "DNSTHREADING"
    public enum Code: Int
    {
        case groupTimeout = 1001
    }
    
    public var nsError: NSError! {
        switch self {
        case .groupTimeout(let codeLocation):
            let userInfo: [String : Any] = [
                "DNSDomain": codeLocation.domain, "DNSFile": codeLocation.file,
                "DNSLine": codeLocation.line, "DNSMethod": codeLocation.method,
                NSLocalizedDescriptionKey: self.errorDescription ?? "Group Timeout Error"
            ]
            return NSError.init(domain: Self.domain,
                                code: Self.Code.groupTimeout.rawValue,
                                userInfo: userInfo)
        }
    }
    public var errorDescription: String? {
        switch self {
        case .groupTimeout:
            return NSLocalizedString("DNSTHREADING-Group Timeout Error", comment: "")
                + " (\(Self.domain):\(Self.Code.groupTimeout.rawValue))"
        }
    }
    public var failureReason: String? {
        switch self {
        case .groupTimeout(let codeLocation):
            return codeLocation.failureReason
        }
    }
}
