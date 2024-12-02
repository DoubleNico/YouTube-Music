import SwordRPC

let rpc = SwordRPC.init(appId: "1280278762088300565")

var songStartTime: Date?
var songDuration: TimeInterval = 0
var currentProgress: TimeInterval = 0
var statusUpdateTimer: Timer?
var discordConnectTimer: Timer?
var lastReportedProgress: TimeInterval = 0
var lastReportedTitle: String = ""
var lastReportedIsPlaying: Bool = false

func connectRPC() {
    print("Connecting Discord RPC...")
        
    discordConnectTimer = Timer.scheduledTimer(
        withTimeInterval: 5.0,
        repeats: true,
        block: { timer in
            print("Attempting to connect to Discord...")
            if rpc.connect() {
                timer.invalidate()
            }
        }
    )
}

func disconnectRPC() {
    print("Disconecting Discord RPC...")
    discordConnectTimer?.invalidate()
    statusUpdateTimer?.invalidate()
    rpc.disconnect()
}

func sendRichPresence(title: String, artist: String, thumbnail: String, length: TimeInterval, progress: TimeInterval, isPlaying: Bool) {
    guard isPlaying else {
        var pausedPresence = RichPresence()
        pausedPresence.details = "Paused"
        pausedPresence.state = "by \(artist)"
        pausedPresence.assets.largeImage = thumbnail
        pausedPresence.assets.largeText = title
        pausedPresence.timestamps.start = nil
        pausedPresence.timestamps.end = nil
        pausedPresence.assets.smallImage = "https://upload.wikimedia.org/wikipedia/commons/thumb/6/6a/Youtube_Music_icon.svg/2048px-Youtube_Music_icon.svg.png"
        pausedPresence.assets.smallText = "Made by DoubleNico"

        rpc.setPresence(pausedPresence)
        return
    }

    let now = Date()

    if songStartTime == nil || abs(progress - currentProgress) > 1.0 {
        songStartTime = now - progress
    }

    let elapsedTime = now.timeIntervalSince(songStartTime!)
    let effectiveProgress = max(elapsedTime, 0)
    let endTime = songStartTime!.addingTimeInterval(length)


    if abs(progress - lastReportedProgress) < 1.0 && title == lastReportedTitle {
        return
    }

    lastReportedProgress = progress
    lastReportedTitle = title
    lastReportedIsPlaying = isPlaying

    var presence = RichPresence()
    presence.details = title
    presence.state = "by \(artist)"
    presence.timestamps.start = songStartTime
    presence.timestamps.end = endTime

    if !thumbnail.isEmpty {
        presence.assets.largeImage = thumbnail
        presence.assets.largeText = title
        presence.assets.smallImage = "https://upload.wikimedia.org/wikipedia/commons/thumb/6/6a/Youtube_Music_icon.svg/2048px-Youtube_Music_icon.svg.png"
        presence.assets.smallText = "Made by DoubleNico"
    } else {
        presence.assets.largeImage = "default_image"
        presence.assets.largeText = title
        presence.assets.smallImage = "https://upload.wikimedia.org/wikipedia/commons/thumb/6/6a/Youtube_Music_icon.svg/2048px-Youtube_Music_icon.svg.png"
        presence.assets.smallText = "Made by DoubleNico"
    }
    
    presence.party.max = 5
    presence.party.size = 3
    presence.party.id = "partyId"
    presence.secrets.join = "https://github.com/DoubleNico/YouTube-Music"
    
    rpc.setPresence(presence)
}
