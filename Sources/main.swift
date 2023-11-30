import Foundation
import os.log

let subsystem = "OnlineRadioBoxToSpotify"
fileprivate let logger = Logger(subsystem: subsystem, category: "main")

main()

func main() {
    runAndWait {
        let input = Input(station: "radiohamburg")
        let output = await actualLogicToRun(with: input)
        logger.info("item count: \(output.items)")
    }
}


private func actualLogicToRun(with input: Input) async -> Output {
    var count = -1
    do {
        let orb = OnlineradioBox()
        let spotify = Spotify()
        try await spotify.logInToSpotify()

        let tracks = try await orb.loadTrackInformation(forStation: input.station)
        logger.info("\(String(describing: tracks))")
        let spots = try await spotify.convertToSpotify(tracks)
        count = spots.count
        logger.info("\(spots)")
    } catch {
        logger.error("Error loading data: \(error.localizedDescription)")
    }
    let output = Output(result: "Station: \(input.station)", items: count)
    return output
}

