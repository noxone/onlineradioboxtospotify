import Foundation
import Logging

let subsystem = "OnlineRadioBoxToSpotify"
fileprivate let logger = Logger(label: "main")

let input = Input(
    station: "radiohamburg",
    daysInPast: 5,
    playlist: "Radio Hamburg",
    playlistShallBePublic: false,
    trackIdsToIgnore: ["288254391476651696", "936772812185958052"]
)

main()

func main() {
    runAndWait {
        do {
            let converter = try await OnlineradioboxToSpotifyConverter()
            try await converter.doDownloadAndConversion(for: input)
        } catch {
            logger.error("Error loading data: \(error.localizedDescription)")
        }
    }
}
