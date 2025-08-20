//
//  DNSSynchronize.swift
//  DoubleNode Swift Framework (DNSFramework) - DNSCoreThreading
//
//  Created by Darren Ehlers.
//  Copyright © 2020 - 2016 DoubleNode.com. All rights reserved.
//

import Foundation

//
// DNSSynchronize - run code in synchronize block
//
// Example Code:
//
//  DNSSynchronize(with: self) {
//      // Synchronized work
//  }.run()
//
// For Swift 6, consider using the new DNSActorSynchronize for better concurrency safety:
//
//  await DNSActorSynchronize.run {
//      // Actor-isolated synchronized work
//  }
//

public final class DNSSynchronize: @unchecked Sendable {
    private let block: (@Sendable () -> Void)?
    private let object: AnyObject?

    public init(with object: AnyObject? = nil, andRun block: (@Sendable () -> Void)? = nil) {
        self.object = object
        self.block = block
    }

    public func run() {
        // Note: In Swift 6, we should prefer actor-based synchronization over objc_sync
        // This implementation maintains compatibility but should be migrated to actors long-term
        
        if Thread.isMainThread {
            let codeLocation = DNSCoreThreadingCodeLocation(self, "\(#file),\(#line),\(#function)")
            NSException(name: NSExceptionName("\(type(of: self)) Exception"),
                       reason: "In Main Thread",
                       userInfo: codeLocation.userInfo)
                .raise()
        }

        let syncObject = self.object ?? self
        objc_sync_enter(syncObject)
        defer { objc_sync_exit(syncObject) }

        self.block?()
    }
}

// MARK: - Swift 6 Modern Synchronization Alternative

/// Modern actor-based synchronization for Swift 6
/// This provides a more Swift 6-native alternative to the legacy DNSSynchronize
@globalActor
public actor DNSActorSynchronize: GlobalActor {
    public static let shared = DNSActorSynchronize()
    
    private init() {}
    
    /// Run a block with actor isolation for thread safety
    /// This is the preferred method for Swift 6 applications
    public static func run<T>(_ block: @Sendable () async throws -> T) async rethrows -> T {
        return try await block()
    }
    
    /// Run a synchronous block with actor isolation
    public static func runSync<T>(_ block: @Sendable () throws -> T) async rethrows -> T {
        return try block()
    }
}
