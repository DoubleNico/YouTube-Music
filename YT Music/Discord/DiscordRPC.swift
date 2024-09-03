//
//  DiscordRPC.swift
//  YT Music
//
//  Created by Tomescu Vlad on 03.09.2024.
//  Copyright © 2024 Cocoon Development Ltd. All rights reserved.
//

import SwordRPC

let rpc = SwordRPC(appId: "1280278762088300565")

//TODO: fix socket for discordrpc
func sendRPC(title: String, by: String, thumbnail: String, length: TimeInterval, progress: TimeInterval, isPlaying: Bool, retryCount: Int = 3) {

    // Function to attempt to connect and set presence
    func attemptConnection(attemptsLeft: Int) {
        guard attemptsLeft > 0 else {
            print("Failed to connect to Discord after several attempts.")
            return
        }
        
        // Connect to Discord
        rpc.connect()

        // Handle successful connection
        rpc.onConnect { rpc in
            print("Connected to Discord.")
            var presence = RichPresence()
            presence.details = title
            presence.state = by

            let startTime = Date() - progress
            let endTime = startTime + length
            presence.timestamps.start = startTime
            presence.timestamps.end = endTime

            if !thumbnail.isEmpty {
                presence.assets.largeImage = thumbnail
                presence.assets.largeText = title
            } else {
                presence.assets.largeImage = "default_image"
                presence.assets.largeText = title
            }
            rpc.setPresence(presence)
        }
        
        // Handle disconnection and retry
        rpc.onDisconnect { rpc, code, msg in
            print("Disconnected from Discord with code: \(String(describing: code)) and message: \(String(describing: msg)), attempting to reconnect...")
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                attemptConnection(attemptsLeft: attemptsLeft - 1)
            }
        }
        
        // Handle errors and retry
        rpc.onError { error, code, msg in
            print("Encountered an error: \(error) with code: \(String(describing: code)) and message: \(String(describing: msg)), retrying...")
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                attemptConnection(attemptsLeft: attemptsLeft - 1)
            }
        }
    }
    
    // Start the connection attempt
    attemptConnection(attemptsLeft: retryCount)
}
