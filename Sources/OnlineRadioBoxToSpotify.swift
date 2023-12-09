import Foundation
import Logging

let subsystem = "OnlineRadioBoxToSpotify"
fileprivate let logger = Logger(label: "main")

@main
struct Main {
    static func main() async {
        let input = Input(station: "radiohamburg", daysInPast: 3, playlist: "Radio/Radio Hamburg")
        let output = await actualLogicToRun(with: input)
        logger.info("\(String(describing: output))")
    }
}

private func actualLogicToRun(with input: Input) async -> Output {
    var count = -1
    do {
        let orb = OnlineradioBox()
        let trackManager = TrackManager()
        let spotify = Spotify()
        try await spotify.logInToSpotify()
        
        logger.info("Station: \(input.station); days in past: \(input.daysInPast)")
        let tracksFromOrb = try await orb.loadTrackInformation(forStation: input.station, forTodayMinus: input.daysInPast)
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
