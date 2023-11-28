import Foundation
import AWSLambdaRuntime
import AsyncHTTPClient
import SwiftSoup
import CollectionConcurrencyKit
import SpotifyWebAPI
import Combine
import os.log

fileprivate let logger = Logger(subsystem: "OnlineRadioBoxToSpotify", category: "main")

let urlSession = URLSession(configuration: {
    let sessionConfig = URLSessionConfiguration.default
    sessionConfig.timeoutIntervalForRequest = 30.0
    sessionConfig.timeoutIntervalForResource = 60.0
    return sessionConfig
}())
defer {
    urlSession.invalidateAndCancel()
}

let spotify = SpotifyAPI(authorizationManager: ClientCredentialsFlowManager(clientId: spotifyClientId, clientSecret: spotifyClientSecret))
private var cancellables: Set<AnyCancellable> = []

struct Input: Codable {
    let station: String
}

struct Output: Codable {
    let result: String
    let items: Int
}

struct RawPlaylistEntry {
    let time: String
    let href: String
}

struct ORBTrack {
    let name: String
    let artist: String
    let albumName: String?
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
        print("item count: \(output.items)")
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
        let tracks = try await loadTrackInformation(forStation: input.station)
        print(tracks)
        let spots = try await convertToSpotify(tracks)
        count = spots.count
        print(spots)
    } catch {
        logger.error("Error loading data: \(error.localizedDescription)")
    }
    let output = Output(result: "Station: \(input.station)", items: count)
    return output
}

private func convertToSpotify(_ tracks: [ORBTrack]) async throws -> [Track] {
    try await spotify.authorizationManager.authorize().async()
    
    let spots = try await tracks.asyncCompactMap { try await searchSpotify(forTrack: $0) }
    return spots
}

private func createPlaylist(from tracks: [Track]) async throws {
    let playlist = try await spotify.playlist("").async()
}

private func searchSpotify(forTrack track: ORBTrack) async throws -> Track? {
    let result = try await spotify.search(query: "\(track.artist) - \(track.name)", categories: [.track]).async()
    return result.tracks?.items.first
}

private func loadTrackInformation(forStation station: String) async throws -> [ORBTrack] {
    let rawPlaylistEntries = try await loadStationPlaylist(forStation: station)
        // FIXME: REMOVE NEXT LINE
        .prefix(10)
    let hrefs = Set(rawPlaylistEntries.map { $0.href })
    let trackDictionary = try await hrefs
        .concurrentMap { href in
            let document = try await loadTrackPage(forHref: href)
            let track = try extractTrackData(from: document)
            return (href: href, track: track)
        }.reduce(into: [String:ORBTrack]()) { map, tuple in
            map[tuple.href] = tuple.track
        }
    
    let tracks = rawPlaylistEntries.compactMap { trackDictionary[$0.href] }
    return tracks
}

private func loadStationPlaylist(forStation station: String) async throws -> [RawPlaylistEntry] {
    let document = try await loadStationPage(forStation: station)
    let rawPlaylistEntries = try extractRawPlaylistEntries(from: document)
        .filter { !$0.href.isEmpty }
    return rawPlaylistEntries
}

private func extractRawPlaylistEntries(from document: Document) throws -> [RawPlaylistEntry] {
    let lines = try document.select("table.tablelist-schedule tr")
    return try lines.map { line in
        let time = try line.select(".time--schedule").text()
        let href = try line.select(".track_history_item > a").attr("href")
        return RawPlaylistEntry(time: time, href: href)
    }
}

private func extractTrackData(from document: Document) throws -> ORBTrack {
    let title = try document.select(".subject__title").text(trimAndNormaliseWhitespace: true)
    let artist = try document.select(".subject__info > a")
        .filter { try $0.attr("itemprop") == "byArtist" }
        .first?.text(trimAndNormaliseWhitespace: true) ?? ""
    let album = try document.select(".subject__info > a")
        .filter { try $0.attr("itemprop") == "byAlbum" }
        .first?.text(trimAndNormaliseWhitespace: true)
    return ORBTrack(name: title, artist: artist, albumName: album)
}

private func loadStationPage(forStation station: String) async throws -> Document {
    let url = try createUrl(forStation: station)
    return try await loadAndParsePage(for: url)
}

private func loadTrackPage(forHref href: String) async throws -> Document {
    let url = try createUrl(forHref: href)
    return try await loadAndParsePage(for: url)
}

private func loadAndParsePage(for url: URL) async throws -> Document {
    let html = try await downloadString(from: url)
    let document = try SwiftSoup.parse(html, url.absoluteString)
    return document
}

private func createUrl(forStation station: String) throws -> URL {
    let url = URL(string: "https://onlineradiobox.com/de/\(station)/playlist/1")
    guard let url else { throw ORBTSError.unableToBuildUrl(station: station) }
    return url
}

private func createUrl(forHref href: String) throws -> URL {
    let url = URL(string: "https://onlineradiobox.com\(href)")
    guard let url else { throw ORBTSError.unableToBuildUrl(station: href) }
    return url
}

private func downloadString(from url: URL) async throws -> String {
    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    
    let (data, response) = try await urlSession.data(for: request)
    guard response is HTTPURLResponse else { throw ORBTSError.invalidResponseType }
    let httpResponse = response as! HTTPURLResponse
    guard 200..<300 ~= httpResponse.statusCode else { throw ORBTSError.downloadFailed }
    logger.info("Loaded \(data.count) bytes from \(url.absoluteString)")
    if let content = String(data: data, encoding: httpResponse.encoding) {
        return content
    } else {
        throw ORBTSError.downloadFailed
    }
}

enum ORBTSError: LocalizedError {
    case unableToLoadPage
    case invalidResponseType
    case downloadFailed
    case unableToBuildUrl(station: String)
}

fileprivate extension HTTPURLResponse {
    var encoding: String.Encoding {
        var usedEncoding = String.Encoding.utf8 // Some fallback value
        if let encodingName = self.textEncodingName {
            let encoding = CFStringConvertEncodingToNSStringEncoding(CFStringConvertIANACharSetNameToEncoding(encodingName as CFString))
            if encoding != UInt(kCFStringEncodingInvalidId) {
                usedEncoding = String.Encoding(rawValue: encoding)
            }
        }
        return usedEncoding
    }
}

// https://medium.com/geekculture/from-combine-to-async-await-c08bf1d15b77
extension AnyPublisher {
    func async() async throws -> Output {
        try await withCheckedThrowingContinuation { continuation in
            var cancellable: AnyCancellable?
            
            cancellable = first()
                .sink { result in
                    switch result {
                    case .finished:
                        break
                    case let .failure(error):
                        continuation.resume(throwing: error)
                    }
                    cancellable?.cancel()
                } receiveValue: { value in
                    continuation.resume(with: .success(value))
                }
        }
    }
}
