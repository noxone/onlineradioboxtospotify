import Foundation
import AWSLambdaRuntime
import os.log

let subsystem = "OnlineRadioBoxToSpotify"
fileprivate let logger = Logger(subsystem: subsystem, category: "main")

let urlSession = URLSession(configuration: {
    let sessionConfig = URLSessionConfiguration.default
    sessionConfig.timeoutIntervalForRequest = 30.0
    sessionConfig.timeoutIntervalForResource = 60.0
    return sessionConfig
}())
defer {
    urlSession.invalidateAndCancel()
}

/*Lambda.run { (context, input: Input, callback: @escaping (Result<Output, Error>) -> Void) in
    Task {
        let output = await actualLogicToRun(with: input)
        
        callback(.success(output))
    }
}*/

main()

func main() {
    runAndWait {
        let input = Input(station: "radiohamburg")
        let output = await actualLogicToRun(with: input)
        logger.info("item count: \(output.items)")
    }
}

private func runAndWait(_ code: @escaping () async -> Void) {
    let group = DispatchGroup()
    group.enter()
    
    Task {
        await code()
        group.leave()
    }
    
    group.wait()
    print("done")
}

private func actualLogicToRun(with input: Input) async -> Output {
    var count = -1
    do {
        let spotify = Spotify()
        try await spotify.logInToSpotify()

        let tracks = try await loadTrackInformation(forStation: input.station)
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

