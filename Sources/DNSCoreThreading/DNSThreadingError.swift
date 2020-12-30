//
//  DNSThreadingError.swift
//  DoubleNode Swift Framework (DNSFramework) - DNSCoreThreading
//
//  Created by Darren Ehlers.
//  Copyright © 2020 - 2016 DoubleNode.com. All rights reserved.
//

import Foundation

public enum DNSThreadingError: Error {
    case groupTimeout(domain: String, file: String, line: String, method: String)
}
extension DNSThreadingError: DNSError {
    public static let domain = "DNSTHREADING"
    public enum Code: Int
    {
        case groupTimeout = 1001
    }
    
    public var nsError: NSError! {
        switch self {
        case .groupTimeout(let domain, let file, let line, let method):
            let userInfo: [String : Any] = [
                "DNSDomain": domain, "DNSFile": file, "DNSLine": line, "DNSMethod": method,
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
        case .groupTimeout(let domain, let file, let line, let method):
            return "\(domain):\(file):\(line):\(method)"
        }
    }
}
