//
//  File.swift
//  
//
//  Created by Olaf Neumann on 30.11.23.
//

import Foundation

class TrackManager {
    func generatePlaylist(fromNewInput trackList: [ORBTrack], ignoring idsToIgnore: [String]) -> [ORBTrack] {
        let tracks = trackList.reduce(into: [String:ORBTrack]()) { $0[$1.id] = $1 }
        
        let listedTracks = Dictionary(
            grouping: trackList
                .filter { $0.time != nil }
                .filter { !idsToIgnore.contains($0.id) },
            by: {$0.id}
        )
        
        let list =  listedTracks
            .map { (id: $0.key, time: $0.value.map { $0.time! }.max(), count: $0.value.count) }
            .sorted(by: { (lhs,rhs) in
                if lhs.count == rhs.count, let lhsTime = lhs.time, let rhsTime = rhs.time {
                    return lhsTime < rhsTime
                }
                return lhs.count < rhs.count
            })
            .reversed()
        
        return list
            .compactMap { tracks[$0.id] }
    }
}

fileprivate struct Track : Hashable {
    let id: String
    let time: Date
}
