//
//  File.swift
//  
//
//  Created by Olaf Neumann on 29.11.23.
//

import Foundation
import CollectionConcurrencyKit
import SwiftSoup

class OnlineradioBox {
    private let http = Http()
    
    func loadTrackInformation(forStation station: String, forDay day: ORBDay) async throws -> [ORBTrack] {
        try await loadTrackInformation(forStation: station, forTodayMinus: day.dayCount)
    }
    
    func loadTrackInformation(forStation station: String, forTodayMinus todayMinus: Int = 1) async throws -> [ORBTrack] {
        guard todayMinus >= 0 else { throw ORBTSError.numberOfDaysTooLow(number: todayMinus) }
            
        let rawPlaylistEntries = try await loadStationPlaylist(forStation: station, andAmountOfDays: todayMinus)
        // FIXME: REMOVE NEXT LINE
            .prefix(10)
        let hrefs = Set(rawPlaylistEntries.map { $0.href })
        let trackDictionary = try await hrefs
            .concurrentMap { href in
                let document = try await self.loadTrackPage(forHref: href)
                let track = try self.extractTrackData(from: document)
                return (href: href, track: track)
            }.reduce(into: [String:ORBTrack]()) { map, tuple in
                map[tuple.href] = tuple.track
            }
        
        let tracks = rawPlaylistEntries.compactMap { trackDictionary[$0.href] }
        return tracks
    }
    
    private func loadStationPlaylist(forStation station: String, andAmountOfDays days: Int) async throws -> [ORBPlaylistEntry] {
        let documents = try await loadStationPages(forStation: station, andAmountOfDays: days)
        let rawPlaylistEntries = try await documents
            .concurrentFlatMap { 
                try self.extractRawPlaylistEntries(from: $0)
                    .filter { !$0.href.isEmpty }
            }
        return rawPlaylistEntries
    }
    
    private func extractRawPlaylistEntries(from document: Document) throws -> [ORBPlaylistEntry] {
        let lines = try document.select("table.tablelist-schedule tr")
        return try lines.map { line in
            let time = try line.select(".time--schedule").text()
            let href = try line.select(".track_history_item > a").attr("href")
            return ORBPlaylistEntry(time: time, href: href)
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
    
    private func loadStationPages(forStation station: String, andAmountOfDays days: Int) async throws -> [Document] {
        return try await (0...days)
            .concurrentMap { try await self.loadStationPage(forStation: station, andDay: $0) }
    }
    
    private func loadStationPage(forStation station: String, andDay day: Int) async throws -> Document {
        let url = try createUrl(forStation: station, andDay: day)
        return try await loadAndParsePage(for: url)
    }
    
    private func loadTrackPage(forHref href: String) async throws -> Document {
        let url = try createUrl(forHref: href)
        return try await loadAndParsePage(for: url)
    }
    
    private func createUrl(forStation station: String, andDay day: Int) throws -> URL {
        let url = URL(string: "https://onlineradiobox.com/de/\(station)/playlist/\(day)")
        guard let url else { throw ORBTSError.unableToBuildUrl(station: station) }
        return url
    }
    
    private func createUrl(forHref href: String) throws -> URL {
        let url = URL(string: "https://onlineradiobox.com\(href)")
        guard let url else { throw ORBTSError.unableToBuildUrl(station: href) }
        return url
    }
    
    private func loadAndParsePage(for url: URL) async throws -> Document {
        let html = try await http.downloadString(from: url)
        let document = try SwiftSoup.parse(html, url.absoluteString)
        return document
    }
}

private struct ORBPlaylistEntry {
    let time: String
    let href: String
}

struct ORBTrack {
    let name: String
    let artist: String
    let albumName: String?
}

enum ORBDay {
    case dayInPast(dayCount: Int)
    
    static let today = ORBDay.dayInPast(dayCount: 0)
    static let yesterday = ORBDay.dayInPast(dayCount: 1)
    static let dayBeforeYesterday = ORBDay.dayInPast(dayCount: 2)
    
    var dayCount: Int {
        if case let .dayInPast(dayCount) = self {
            return dayCount
        } else {
            return 0
        }
    }
}

private enum ORBTSError: LocalizedError {
    case numberOfDaysTooLow(number: Int)
    case unableToLoadPage
    case invalidResponseType
    case downloadFailed
    case unableToBuildUrl(station: String)
}
