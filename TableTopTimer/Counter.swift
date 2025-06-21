//
//  Counter.swift
//  TableTopTimer
//
//  Created by Yuhao Chen on 6/21/25.
//

import Foundation
import SwiftData

@Model
final class Counter {
    var id: UUID
    var name: String
    var value: Int
    var initialValue: Int
    var minValue: Int?
    var maxValue: Int?
    var order: Int
    var createdAt: Date
    
    var list: TimerList?
    
    init(name: String, initialValue: Int = 0, minValue: Int? = nil, maxValue: Int? = nil, order: Int = 0) {
        self.id = UUID()
        self.name = name
        self.value = initialValue
        self.initialValue = initialValue
        self.minValue = minValue
        self.maxValue = maxValue
        self.order = order
        self.createdAt = Date()
    }
    
    func increment() {
        if let max = maxValue, value >= max { return }
//        let oldValue = value
        value += 1
        // Note: Counter change notification will be handled at the UI level
    }
    
    func decrement() {
        if let min = minValue, value <= min { return }
//        let oldValue = value
        value -= 1
        // Note: Counter change notification will be handled at the UI level
    }
    
    func reset() {
        value = initialValue
    }
    
    var canIncrement: Bool {
        guard let max = maxValue else { return true }
        return value < max
    }
    
    var canDecrement: Bool {
        guard let min = minValue else { return true }
        return value > min
    }
}
