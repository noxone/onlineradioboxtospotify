//
//  File.swift
//  
//
//  Created by Olaf Neumann on 30.11.23.
//

import Foundation

class TrackManager {
    func generatePlaylist(fromNewInput tracks: [ORBPlaylistEntry], ignoring ignoreIds: [String]) -> [String] {
        let hrefsToIgnore = ignoreIds.map { "/track/\($0)/" }
        let listedTracks = Dictionary(
            grouping: tracks
                .filter { $0.time != nil }
                .filter { !hrefsToIgnore.contains($0.href) },
            by: {$0.href}
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
            .map { $0.id }
    }
}

fileprivate struct Track : Hashable {
    let id: String
    let time: Date
}
