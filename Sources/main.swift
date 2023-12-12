import Foundation
import Logging

let subsystem = "OnlineRadioBoxToSpotify"
fileprivate let logger = Logger(label: "main")

let input = Input(station: "radiohamburg", daysInPast: 5, playlist: "Radio Hamburg", playlistShallBePublic: true)

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
