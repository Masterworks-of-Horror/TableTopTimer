//
//  TimerList.swift
//  TableTopTimer
//
//  Created by Yuhao Chen on 6/21/25.
//

import Foundation
import SwiftData
import SwiftUI

@Model
final class TimerList {
    var id: UUID
    var name: String
    var createdAt: Date
    var lastUsedAt: Date?
    var colorHex: String
    
    @Relationship(deleteRule: .cascade, inverse: \TimerItem.list)
    var timers: [TimerItem] = []
    
    @Relationship(deleteRule: .cascade, inverse: \Counter.list)
    var counters: [Counter] = []
    
    @Relationship(deleteRule: .cascade, inverse: \Automation.list)
    var automations: [Automation] = []
    
    init(name: String, colorHex: String = "#007AFF") {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
        self.colorHex = colorHex
    }
    
    var color: Color {
        Color(hex: colorHex) ?? .accentColor
    }
}

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }
        
        let length = hexSanitized.count
        if length == 6 {
            self.init(
                red: Double((rgb & 0xFF0000) >> 16) / 255.0,
                green: Double((rgb & 0x00FF00) >> 8) / 255.0,
                blue: Double(rgb & 0x0000FF) / 255.0
            )
        } else {
            return nil
        }
    }
    
    var hexString: String {
        let components = UIColor(self).cgColor.components ?? [0, 0, 0]
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
