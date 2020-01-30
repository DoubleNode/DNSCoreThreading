//
//  DNSLogger.swift
//  DNSCore
//
//  Created by Darren Ehlers on 8/14/19.
//  Copyright © 2019 DoubleNode.com. All rights reserved.
//

import Foundation
import SwiftyBeaver

public let dnsLog = DNSLogger().dnsLog

public class DNSLogger {
    public var dnsLog = SwiftyBeaver.self
    
    required init() {
        // SwiftyBeaver Initialization
        // add log destinations. at least one is needed!
        let console = ConsoleDestination()  // log to Xcode Console
        //let file = FileDestination()  // log to default swiftybeaver.log file
        //let cloud = SBPlatformDestination(appID: "foo", appSecret: "bar", encryptionKey: "123") // to cloud

        // use custom format and set console output to short time, log level & message
        console.format = "$DHH:mm:ss$d $L $M"
        console.asynchronously = false
        console.levelString.verbose = "💙"
        console.levelString.debug = "💚"
        console.levelString.info = "🧡🧡"
        console.levelString.warning = "💛💛"
        console.levelString.error = "❤️❤️❤️❤️"
        console.minLevel = .verbose
        // or use this for JSON output: console.format = "$J"

        // add the destinations to SwiftyBeaver
        dnsLog.addDestination(console)
        //dnsLog.addDestination(file)
        //dnsLog.addDestination(cloud)
    }
    
    public func consoleDestination() -> ConsoleDestination? {
        return SwiftyBeaver.destinations.first { ($0 as? ConsoleDestination) != nil } as? ConsoleDestination
    }
}