//
//  MediaCenter.swift
//  YT Music
//
//  Created by Stephen Radford on 05/07/2018.
//  Copyright © 2018 Cocoon Development Ltd. All rights reserved.
//

import Cocoa
import WebKit
import AVFoundation
import UserNotifications

#if canImport(MediaPlayer)
import MediaPlayer
#endif

class MediaCenter: NSObject, WKScriptMessageHandler, NSUserNotificationCenterDelegate {
    
    static let `default` = MediaCenter()
    override private init() { }
    
    private var titleChanged = false
    
    private var byChanged = false
    
    let fakePlayer = AVPlayer(url: Bundle.main.url(forResource: "silence", withExtension: "mp3")!)

    var title: String? {
        didSet {
            titleChanged = title != oldValue
        }
    }
    
    var by: String? {
        didSet {
            byChanged = by != oldValue
        }
    }
    
    var thumbnail: String? {
        didSet {
            guard oldValue != thumbnail else { return }
            
            guard let thumbnail = thumbnail,
            let thumbnailURL = URL(string: thumbnail) else {
                image = nil
                return
            }
            
            DispatchQueue.global(qos: .background).async {
                self.image = NSImage(contentsOf: thumbnailURL)
            }
        }
    }
    
    var image: NSImage?
    
    var length: TimeInterval = 0
    
    var progress: TimeInterval = 0
    
    var isPlaying = false {
        didSet {
            let newMenuTitle = isPlaying ? "Pause" : "Play"
            (NSApp.delegate as? AppDelegate)?.dockMenu.item(at: 0)?.title = newMenuTitle
            NSApp.mainMenu?.items.filter { $0.title == "Playback" }.first?.submenu?.items.first?.title = newMenuTitle
        }
    }
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let dict = message.body as? [String:Any] else { return }
        
        title = dict["title"] as? String
        by = dict["by"] as? String
        thumbnail = dict["thumbnail"] as? String
        length = dict["length"] as? TimeInterval ?? 0
        progress = dict["progress"] as? TimeInterval ?? 0
        isPlaying = dict["isPlaying"] as? Bool ?? false

        sendRichPresence(title: title ?? "Unknown Title", artist: by ?? "Unknown Artist", thumbnail: thumbnail ?? "Unknown Thumbnail", length: length, progress: progress, isPlaying: isPlaying)

        sendNotificationIfRequired()
        
        if #available(OSX 10.12.2, *) {
            DispatchQueue.main.async {
                self.setNowPlaying()
            }
        }
    }
    
    /// Sends an `NSUserNotification` regarding the song change.
    func sendNotificationIfRequired() {
        guard GeneralPreferences.pushNotifications.isEnabled,
            let title,
            let by,
            let thumbnail,
            let thumbnailURL = URL(string: thumbnail),
            !title.isEmpty,
            !by.isEmpty,
            titleChanged || byChanged else {
            return
        }

        // Create notification content
        let content = UNMutableNotificationContent()
        content.title = title
        content.subtitle = by

        // Asynchronously load the image and create the notification
        downloadImage(from: thumbnailURL) { attachment in
            if let attachment = attachment {
                content.attachments = [attachment]
            }

            // Create a trigger to fire the notification immediately
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

            // Create a request with a unique identifier
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)

            // Schedule the notification
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("Error delivering notification: \(error)")
                }
            }
        }

        // Reset change flags
        titleChanged = false
        byChanged = false
    }
    
    private func downloadImage(from url: URL, completion: @escaping (UNNotificationAttachment?) -> Void) {
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("Error downloading image: \(error)")
                completion(nil)
                return
            }
            
            guard let data = data, let image = NSImage(data: data) else {
                print("Failed to load image from data")
                completion(nil)
                return
            }
            
            do {
                let tempDir = FileManager.default.temporaryDirectory
                let tempFileURL = tempDir.appendingPathComponent(UUID().uuidString + ".jpg")
                try data.write(to: tempFileURL)
                
                let attachment = try UNNotificationAttachment(identifier: UUID().uuidString, url: tempFileURL)
                completion(attachment)
            } catch {
                print("Error creating notification attachment: \(error)")
                completion(nil)
            }
        }.resume()
    }
    
    func requestNotificationAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification authorization error: \(error)")
            }
        }
    }
    
    /// Sets the information in `MPNowPlayingInfoCenter`
    @available(OSX 10.12.2, *)
    func setNowPlaying() {
        guard let title = title, let by = by else { return }
        
        // This seems to be working.
        // Required to stop WKWebView stealing control.
        fakePlayer.seek(to: CMTime(seconds: 0, preferredTimescale: 1))
        fakePlayer.play()
        
        let components = by.components(separatedBy: " • ")
        
        var info: [String:Any] = [
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyArtist: components[0],
            MPMediaItemPropertyMediaType: MPMediaType.music.rawValue,
            MPMediaItemPropertyPlaybackDuration: length,
            MPNowPlayingInfoPropertyPlaybackRate: 1.0,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: progress
        ]
        
        // Add the album title if there's one
        if components.count > 1 {
            info[MPMediaItemPropertyAlbumTitle] = components[1]
        }
        
        if #available(OSX 10.13.2, *) {
            var artwork: MPMediaItemArtwork?
            
            if let image = image {
                artwork = MPMediaItemArtwork(boundsSize: CGSize(width: 500, height: 500)) { (_) -> NSImage in
                    return image
                }
            }
            
            info[MPMediaItemPropertyArtwork] = artwork
        }
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        MPNowPlayingInfoCenter.default().playbackState = isPlaying ? .playing : .paused
        
    }
    
}
