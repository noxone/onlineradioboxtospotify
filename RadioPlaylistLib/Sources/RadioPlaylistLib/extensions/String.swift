//
//  File.swift
//  
//
//  Created by Olaf Neumann on 23.12.23.
//

import Foundation

// https://stackoverflow.com/questions/35840156/named-capture-groups-in-nsregularexpression-get-a-ranges-groups-name
extension String {
    func range(from nsRange: NSRange) -> Range<String.Index>? {
        guard
            let from16 = utf16.index(utf16.startIndex, offsetBy: nsRange.location, limitedBy: utf16.endIndex),
            let to16 = utf16.index(utf16.startIndex, offsetBy: nsRange.location + nsRange.length, limitedBy: utf16.endIndex),
            let from = from16.samePosition(in: self),
            let to = to16.samePosition(in: self)
        else { return nil }
        return from ..< to
    }
}
