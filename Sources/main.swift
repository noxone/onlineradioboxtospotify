import Foundation
import os.log

let subsystem = "OnlineRadioBoxToSpotify"
fileprivate let logger = Logger(subsystem: subsystem, category: "main")

main()

func main() {
    runAndWait {
        let input = Input(station: "radiohamburg", playlist: "Radio/Radio Hamburg")
        _ = await actualLogicToRun(with: input)
    }
}


private func actualLogicToRun(with input: Input) async -> Output {
    var count = -1
    do {
        let orb = OnlineradioBox()
        let trackManager = TrackManager()
        let spotify = Spotify()
        try await spotify.logInToSpotify()

        let tracksFromOrb = try await orb.loadTrackInformation(forStation: input.station)
        logger.info("Loaded \(tracksFromOrb.count) tracks from OnlineRadioBox.")
        let playlistTracks = trackManager.generatePlaylist(fromNewInput: tracksFromOrb)
        logger.info("Generated playlist with \(playlistTracks.count) items.")
        let spots = try await spotify.convertToSpotify(playlistTracks)
        logger.info("Found \(spots.count) tracks on Spotify.")
        try await spotify.updatePlaylist(input.playlist, with: spots)
        logger.info("Updated playlist.")
        
        count = spots.count
    } catch {
        logger.error("Error loading data: \(error.localizedDescription)")
    }
    let output = Output(result: "Station: \(input.station)", items: count)
    return output
}

