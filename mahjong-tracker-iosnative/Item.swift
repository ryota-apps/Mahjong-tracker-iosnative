//
//  Item.swift
//  mahjong-tracker-iosnative
//
//  Created by 本間諒太 on 2026/03/14.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
