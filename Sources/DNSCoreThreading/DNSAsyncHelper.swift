//
//  DNSAsyncHelper.swift
//  DoubleNode Swift Framework (DNSFramework) - DNSCoreThreading
//
//  Created by Claude Code Assistant for async/await migration.
//  Copyright © 2025 - 2016 DoubleNode.com. All rights reserved.
//

import Foundation

// MARK: - Async-Compatible Block Types
public typealias DNSAsyncBlock<T> = () async throws -> T
public typealias DNSAsyncVoidBlock = () async throws -> Void
public typealias DNSAsyncResultBlock<T> = (Result<T, Error>) async -> Void

// MARK: - Async Result Types
public enum AsyncResult<Success, Failure: Error> {
    case success(Success)
    case failure(Failure)
    
    // Conversion methods from Result
    public init(_ result: Result<Success, Failure>) {
        switch result {
        case .success(let value):
            self = .success(value)
        case .failure(let error):
            self = .failure(error)
        }
    }
    
    // Convert to Result
    public var result: Result<Success, Failure> {
        switch self {
        case .success(let value):
            return .success(value)
        case .failure(let error):
            return .failure(error)
        }
    }
}

// MARK: - Global Actor for Background Operations
@globalActor
public actor DNSBackgroundActor {
    public static let shared = DNSBackgroundActor()
    
    private init() {}
    
    // Helper methods for safe data access
    @DNSBackgroundActor
    public static func run<T>(_ operation: @DNSBackgroundActor @escaping () async throws -> T) async rethrows -> T {
        return try await operation()
    }
}

// MARK: - DNS Async Helper
public final class DNSAsyncHelper {
    public static let shared = DNSAsyncHelper()
    
    private init() {}
    
    // MARK: - QoS to TaskPriority Mapping
    private func taskPriority(for qos: DNSThreading.QoSClass) -> TaskPriority {
        switch qos {
        case .background, .lowBackground:
            return .background
        case .default:
            return .medium
        case .highBackground:
            return .high
        case .uiMain:
            return .userInitiated
        case .current:
            return .medium
        }
    }
    
    // MARK: - Basic Async Operations
    
    /// Run an async operation with specified QoS
    public func runAsync<T>(
        in qos: DNSThreading.QoSClass = .background,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        let priority = taskPriority(for: qos)
        
        return try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask(priority: priority) {
                try await operation()
            }
            return try await group.next()!
        }
    }
    
    /// Run an async operation on the main actor
    @MainActor
    public func runOnMain<T>(
        operation: @MainActor @escaping () async throws -> T
    ) async throws -> T {
        return try await operation()
    }
    
    /// Run an async operation on the background actor
    public func runOnBackground<T>(
        operation: @DNSBackgroundActor @escaping () async throws -> T
    ) async throws -> T {
        return try await DNSBackgroundActor.run(operation)
    }
    
    // MARK: - Bridge Methods from Legacy to Async
    
    /// Bridge DNSThread.run to async/await
    public func bridgeFromLegacy<T>(
        _ execution: DNSThreading.Execution = .asynchronously,
        in qos: DNSThreading.QoSClass = .background,
        operation: @escaping () -> T
    ) async -> T {
        let priority = taskPriority(for: qos)
        
        return await withTaskGroup(of: T.self) { group in
            group.addTask(priority: priority) {
                return operation()
            }
            return await group.next()!
        }
    }
    
    /// Bridge async operation to legacy completion handler
    public func bridgeToLegacy<T>(
        operation: @escaping () async throws -> T,
        completion: @escaping (Result<T, Error>) -> Void
    ) {
        Task {
            do {
                let result = try await operation()
                completion(.success(result))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Async Delay Operations
    
    /// Run operation after delay using async/await
    public func runAfterDelay<T>(
        _ delay: TimeInterval,
        in qos: DNSThreading.QoSClass = .background,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        let priority = taskPriority(for: qos)
        
        return try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask(priority: priority) {
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                return try await operation()
            }
            return try await group.next()!
        }
    }
    
    // MARK: - Cancellation Support
    
    /// Check if current task is cancelled and throw if needed
    public static func checkCancellation() throws {
        try Task.checkCancellation()
    }
    
    /// Run operation with automatic cancellation checks
    public func runWithCancellation<T>(
        operation: @escaping () async throws -> T
    ) async throws -> T {
        try Task.checkCancellation()
        let result = try await operation()
        try Task.checkCancellation()
        return result
    }
    
    // MARK: - Batch Operations (TaskGroup replacements for DNSThreadingGroup)
    
    /// Run multiple operations concurrently and collect results
    public func runConcurrently<T>(
        operations: [() async throws -> T],
        in qos: DNSThreading.QoSClass = .background
    ) async throws -> [T] {
        let priority = taskPriority(for: qos)
        
        return try await withThrowingTaskGroup(of: T.self, returning: [T].self) { group in
            for operation in operations {
                group.addTask(priority: priority) {
                    try await operation()
                }
            }
            
            var results: [T] = []
            for try await result in group {
                results.append(result)
            }
            return results
        }
    }
    
    /// Run operations concurrently with individual error handling
    public func runConcurrentlyWithResults<T>(
        operations: [() async throws -> T],
        in qos: DNSThreading.QoSClass = .background
    ) async -> [Result<T, Error>] {
        let priority = taskPriority(for: qos)
        
        return await withTaskGroup(of: Result<T, Error>.self, returning: [Result<T, Error>].self) { group in
            for operation in operations {
                group.addTask(priority: priority) {
                    do {
                        let result = try await operation()
                        return .success(result)
                    } catch {
                        return .failure(error)
                    }
                }
            }
            
            var results: [Result<T, Error>] = []
            for await result in group {
                results.append(result)
            }
            return results
        }
    }
    
    // MARK: - Stream Processing
    
    /// Process items as a stream with controlled concurrency
    public func processStream<T, R>(
        items: [T],
        maxConcurrency: Int = 5,
        in qos: DNSThreading.QoSClass = .background,
        processor: @escaping (T) async throws -> R
    ) async throws -> [R] {
        let priority = taskPriority(for: qos)
        
        // Use simple batching instead of complex semaphore
        let batches = items.chunked(into: maxConcurrency)
        var allResults: [R] = []
        
        for batch in batches {
            let batchResults = try await withThrowingTaskGroup(of: R.self, returning: [R].self) { group in
                for item in batch {
                    group.addTask(priority: priority) {
                        try await processor(item)
                    }
                }
                
                var results: [R] = []
                for try await result in group {
                    results.append(result)
                }
                return results
            }
            allResults.append(contentsOf: batchResults)
        }
        
        return allResults
    }
}

// MARK: - Async Semaphore
public actor AsyncSemaphore {
    private var count: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []
    
    public init(count: Int) {
        self.count = count
    }
    
    public func wait() async {
        if count > 0 {
            count -= 1
            return
        }
        
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }
    
    public func signal() async {
        if waiters.isEmpty {
            count += 1
        } else {
            let waiter = waiters.removeFirst()
            waiter.resume()
        }
    }
}

// MARK: - Convenience Extensions

extension Array {
    /// Split array into chunks of specified size
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}


// MARK: - Task Extensions for DNS Framework

extension Task {
    /// Create a task with DNS QoS mapping
    public static func dns<T>(
        priority: DNSThreading.QoSClass = .background,
        operation: @escaping () async throws -> T
    ) -> Task<T, any Error> {
        return Task<T, any Error>(priority: priority.taskPriority) {
            try await operation()
        }
    }
}