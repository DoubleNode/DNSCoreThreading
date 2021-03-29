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
    case unknown(_ codeLocation: DNSCodeLocation)
    case groupTimeout(_ codeLocation: DNSCodeLocation)
}
extension DNSThreadingError: DNSError {
    public static let domain = "DNSTHREADING"
    public enum Code: Int
    {
        case unknown = 1001
        case groupTimeout = 1002
    }
    
    public var nsError: NSError! {
        switch self {
        case .unknown(let codeLocation):
            var userInfo = codeLocation.userInfo
            userInfo[NSLocalizedDescriptionKey] = self.errorString
            return NSError.init(domain: Self.domain,
                                code: Self.Code.unknown.rawValue,
                                userInfo: userInfo)
        case .groupTimeout(let codeLocation):
            var userInfo = codeLocation.userInfo
            userInfo[NSLocalizedDescriptionKey] = self.errorString
            return NSError.init(domain: Self.domain,
                                code: Self.Code.groupTimeout.rawValue,
                                userInfo: userInfo)
        }
    }
    public var errorDescription: String? {
        return self.errorString
    }
    public var errorString: String {
        switch self {
        case .unknown:
            return String(format: NSLocalizedString("DNSTHREADING-Unknown Error%@", comment: ""),
                          " (\(Self.domain):\(Self.Code.unknown.rawValue))")
        case .groupTimeout:
            return String(format: NSLocalizedString("DNSTHREADING-Group Timeout Error%@", comment: ""),
                          " (\(Self.domain):\(Self.Code.groupTimeout.rawValue))")
        }
    }
    public var failureReason: String? {
        switch self {
        case .unknown(let codeLocation),
             .groupTimeout(let codeLocation):
            return codeLocation.failureReason
        }
    }
}
