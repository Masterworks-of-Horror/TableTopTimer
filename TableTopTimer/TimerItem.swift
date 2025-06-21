//
//  Timer.swift
//  TableTopTimer
//
//  Created by Yuhao Chen on 6/20/25.
//

import Foundation
import SwiftData

@Model
final class TimerItem {
    var id: UUID
    var name: String
    var duration: TimeInterval
    var order: Int
    var createdAt: Date
    
    var list: TimerList?
    
    init(name: String = "New Timer", duration: TimeInterval = 60, order: Int = 0) {
        self.id = UUID()
        self.name = name
        self.duration = duration
        self.order = order
        self.createdAt = Date()
    }
}
