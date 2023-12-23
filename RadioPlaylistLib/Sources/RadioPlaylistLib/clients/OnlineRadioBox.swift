//
//  File.swift
//
//
//  Created by Olaf Neumann on 29.11.23.
//

import Foundation
import CollectionConcurrencyKit
import SwiftSoup
import RegexBuilder

class OnlineradioBox {
    private let http = Http()
    private let regexForId = try! NSRegularExpression(pattern: "/track/(?<id>\\d+)/", options: [.caseInsensitive])
    private let regexForTime = try! NSRegularExpression(pattern: "(?<hour>\\d+):(?<minute>\\d+)", options: [.caseInsensitive])
    
    init() {}
    
    private func extractId(fromHref href: String) -> String? {
        let range = NSRange(location: 0, length: href.count)
        let matches = regexForId.matches(in: href, options: [], range: range)
        if let first = matches.first,
           let range = href.range(from: first.range(withName: "id")) {
            return String(href[range])
        }
        return nil
    }
    
    func loadTrackDetails(for tracks: [ORBTrack]) async throws -> [ORBTrack] {
        return try await tracks.concurrentMap { try await self.loadTrackDetails(for: $0) }
            .compactMap { $0 }
    }
    
    private func loadTrackDetails(for track: ORBTrack) async throws -> ORBTrack? {
        let page = try await loadTrackPage(forId: track.id)
        return try extractTrackData(from: page, withId: track.id)
    }
    
    func loadPlaylist(forStation station: String, forTheLastDays todayMinus: Int = 1) async throws -> [ORBTrack] {
        guard todayMinus >= 0 else { throw ORBTSError.numberOfDaysTooLow(number: todayMinus) }
        return try await loadStationPlaylist(forStation: station, andAmountOfDays: todayMinus)
    }
    
    private func loadStationPlaylist(forStation station: String, andAmountOfDays days: Int) async throws -> [ORBTrack] {
        let documents = try await loadStationPages(forStation: station, andAmountOfDays: days)
        let rawPlaylistEntries = try await documents
            .concurrentFlatMap { try self.extractRawPlaylistEntries(from: $0.document, forDate: $0.date) }
        return rawPlaylistEntries
    }
    
    private func extractRawPlaylistEntries(from document: Document, forDate date: Date) throws -> [ORBTrack] {
        let lines = try document.select("table.tablelist-schedule tr")
        return try lines.compactMap { try extractRawPlaylistEntry(from: $0, forDate: date) }
    }
    
    private func extractRawPlaylistEntry(from line: Element, forDate date: Date) throws -> ORBTrack? {
        let time = try line.select(".time--schedule").text(trimAndNormaliseWhitespace: true)
        let link = try line.select(".track_history_item > a")
        let href = try link.attr("href")
        guard let id = extractId(fromHref: href) else { return nil }
        let display = try link.text(trimAndNormaliseWhitespace: true)
        guard let parsedTime = parse(time: time) else { return nil }
        let entryTime = date.at(hour: parsedTime.hour, minute: parsedTime.minute)
        return ORBTrack(id: id, time: entryTime, display: display, title: nil, artist: nil)
    }
    
    private func parse(time: String) -> (hour: Int, minute: Int)? {
        let range = NSRange(location: 0, length: time.count)
        let matches = regexForTime.matches(in: time, options: [], range: range)
        if let first = matches.first,
           let rangeHour = time.range(from: first.range(withName: "hour")),
           let rangeMinute = time.range(from: first.range(withName: "minute")) {
            let hour = String(time[rangeHour])
            let minute = String(time[rangeMinute])
            return (hour: Int(hour)!, minute: Int(minute)!)
        }
        return nil
    }
    
    private func extractTrackData(from document: Document, withId id: String) throws -> ORBTrack {
        let title = try document.select(".subject__title").text(trimAndNormaliseWhitespace: true)
        let artist = try document.select(".subject__info > a")
            .filter { try $0.attr("itemprop") == "byArtist" }
            .first?.text(trimAndNormaliseWhitespace: true) ?? ""
        //        let album = try document.select(".subject__info > a")
        //            .filter { try $0.attr("itemprop") == "byAlbum" }
        //            .first?.text(trimAndNormaliseWhitespace: true)
        return ORBTrack(id: id, time: nil, display: nil, title: title, artist: artist)
    }
    
    private func loadStationPages(forStation station: String, andAmountOfDays days: Int) async throws -> [(date: Date, document: Document)] {
        return try await (0...days)
            .concurrentMap { try await self.loadStationPage(forStation: station, andDay: $0) }
    }
    
    private func loadStationPage(forStation station: String, andDay day: Int) async throws -> (date: Date, document: Document) {
        let url = try createUrl(forStation: station, andDay: day)
        return try await (date: Date().minus(days: day), document: loadAndParsePage(for: url))
    }
    
    private func loadTrackPage(forId id: String) async throws -> Document {
        let url = try createUrl(forTrackId: id)
        return try await loadAndParsePage(for: url)
    }
    
    private func createUrl(forStation station: String, andDay day: Int) throws -> URL {
        let url = URL(string: "https://onlineradiobox.com/de/\(station)/playlist/\(day)")
        guard let url else { throw ORBTSError.unableToBuildUrl(station: station) }
        return url
    }
    
    private func createUrl(forTrackId id: String) throws -> URL {
        let url = URL(string: "https://onlineradiobox.com/track/\(id)/")
        guard let url else { throw ORBTSError.unableToBuildUrl(station: id) }
        return url
    }
    
    private func loadAndParsePage(for url: URL) async throws -> Document {
        let html = try await http.downloadString(from: url)
        let document = try SwiftSoup.parse(html, url.absoluteString)
        return document
    }
}

struct ORBTrack {
    let id: String
    let time: Date?
    let display: String?
    let title: String?
    let artist: String?
}
