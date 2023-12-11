import Foundation
import Logging

let subsystem = "OnlineRadioBoxToSpotify"
fileprivate let logger = Logger(label: "main")

let input = Input(station: "radiohamburg", daysInPast: 3, playlist: "bernd Brot 1233", playlistShallBePublic: false)

main()

func main() {
    runAndWait {
        // _ = await actualLogicToRun(with: input)
        do {
            let converter = try await OnlineradioboxToSpotifyConverter()
            try await converter.doDownloadAndConversion(for: input)
        } catch {
            logger.error("Error loading data: \(error.localizedDescription)")
        }
    }
}
