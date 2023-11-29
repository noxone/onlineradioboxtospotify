//
//  File.swift
//  
//
//  Created by Olaf Neumann on 29.11.23.
//

import Foundation
import CollectionConcurrencyKit
import SwiftSoup

func loadTrackInformation(forStation station: String) async throws -> [ORBTrack] {
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
