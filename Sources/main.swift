import Foundation
import AWSLambdaRuntime
import AsyncHTTPClient
import SwiftSoup
import CollectionConcurrencyKit
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

struct Input: Codable {
    let station: String
}

struct Output: Codable {
    let result: String
    let items: Int
}

struct Track {
    let name: String
    let artist: String
    let albumName: String?
    let albumYear: Int?
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
        let tracks = try await loadStationPlaylist(forStation: input.station)
        count = tracks.count
        print(tracks)
    } catch {
        logger.error("Error loading data: \(error.localizedDescription)")
    }
    let output = Output(result: "Station: \(input.station)", items: count)
    return output
}

private func loadStationPlaylist(forStation station: String) async throws -> [Track] {
    let document = try await loadStationPage(forStation: station)
    let trackHrefs = try extractPlaylistData(from: document)
    let tracks = try await trackHrefs.asyncMap {
        let document = try await loadTrackPage(forHref: $0)
        return try extractTrackData(from: document)
    }
    return tracks
}

private func extractPlaylistData(from document: Document) throws -> [String] {
    return try document.select(".track_history_item > a")
        .compactMap { try? $0.attr("href") }
}

private func extractTrackData(from document: Document) throws -> Track {
    let title = try document.select(".subject__title").text(trimAndNormaliseWhitespace: true)
    let artist = try document.select(".subject__info > a")
        .filter { try $0.attr("itemprop") == "byArtist" }
        .first?.text(trimAndNormaliseWhitespace: true) ?? ""
    return Track(name: title, artist: artist, albumName: nil, albumYear: nil)
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
    let url = URL(string: "https://onlineradiobox.com/de/\(station)/playlist")
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

