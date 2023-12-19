import Foundation
import Logging

let subsystem = "OnlineRadioBoxToSpotify"
fileprivate let logger = Logger(label: "main")

let input = Input(
    station: "radiohamburg", // "deltadeutsch", "radiohamburg", "radiorsh"
    daysInPast: 5,
    playlist: "Radio Hamburg", // "Delta Radio", "Radio Hamburg", "R.SH"
    playlistShallBePublic: false,
    maxPlaylistItems: 0,
    trackIdsToIgnore: ["288254391476651696", "936772812185958052"]
)

print ("Text")


//main()
//
//func main() {
//    runAndWait {
//        do {
//            let converter = try await OnlineradioboxToSpotifyConverter(spotify: Spotify())
//            try await converter.doDownloadAndConversion(for: input)
//        } catch {
//            logger.error("Error loading data: \(error.localizedDescription)")
//        }
//    }
//}
