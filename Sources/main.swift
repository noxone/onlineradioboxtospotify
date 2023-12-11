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
        let playlistUri = try await spotify.getOrCreate(playlist: input.playlist, isPublic: input.playlistShallBePublic)
        logger.info("Playlist uri: \(playlistUri)")
        try await spotify.updatePlaylist(uri: playlistUri, with: spots)
        logger.info("Updated playlist.")
        //let spots = [0]
        
        count = spots.count
    } catch {
        logger.error("Error loading data: \(error.localizedDescription)")
    }
    let output = Output(result: "Station: \(input.station)", items: count)
    return output
}
