//
//  Automation.swift
//  TableTopTimer
//
//  Created by Yuhao Chen on 6/21/25.
//

import Foundation
import SwiftData

@Model
final class Automation {
    var id: UUID
    var name: String
    var isEnabled: Bool
    var createdAt: Date
    var order: Int
    
    var list: TimerList?
    
    @Relationship(deleteRule: .cascade, inverse: \AutomationTrigger.automation)
    var triggers: [AutomationTrigger] = []
    
    @Relationship(deleteRule: .cascade, inverse: \AutomationAction.automation)
    var actions: [AutomationAction] = []
    
    init(name: String, order: Int = 0) {
        self.id = UUID()
        self.name = name
        self.isEnabled = true
        self.createdAt = Date()
        self.order = order
    }
}

@Model
final class AutomationTrigger {
    var id: UUID
    var type: TriggerType
    var timerName: String?
    var timeValue: Double? // seconds
    var intervalValue: Double? // seconds for repeating triggers
    var counterName: String?
    var counterValue: Int?
    var createdAt: Date
    
    var automation: Automation?
    
    init(type: TriggerType) {
        self.id = UUID()
        self.type = type
        self.createdAt = Date()
    }
}

@Model
final class AutomationAction {
    var id: UUID
    var type: ActionType
    var soundType: SoundType?
    var counterName: String?
    var counterChange: Int?
    var message: String?
    var createdAt: Date
    
    var automation: Automation?
    
    init(type: ActionType) {
        self.id = UUID()
        self.type = type
        self.createdAt = Date()
    }
}

enum TriggerType: String, CaseIterable, Codable {
    case timerStart = "timer_start"
    case timerEnd = "timer_end"
    case timerTimeRemaining = "timer_time_remaining"
    case timerTimeElapsed = "timer_time_elapsed"
    case repeatingInterval = "repeating_interval"
    case counterReachesValue = "counter_reaches_value"
    case anyTimerStart = "any_timer_start"
    case anyTimerEnd = "any_timer_end"
    
    var displayName: String {
        switch self {
        case .timerStart: return "Timer Starts"
        case .timerEnd: return "Timer Ends"
        case .timerTimeRemaining: return "X Seconds Before Timer Ends"
        case .timerTimeElapsed: return "X Seconds After Timer Starts"
        case .repeatingInterval: return "Every X Seconds"
        case .counterReachesValue: return "Counter Reaches Value"
        case .anyTimerStart: return "Any Timer Starts"
        case .anyTimerEnd: return "Any Timer Ends"
        }
    }
    
    var needsTimer: Bool {
        switch self {
        case .timerStart, .timerEnd, .timerTimeRemaining, .timerTimeElapsed:
            return true
        case .repeatingInterval, .counterReachesValue, .anyTimerStart, .anyTimerEnd:
            return false
        }
    }
    
    var needsTimeValue: Bool {
        switch self {
        case .timerTimeRemaining, .timerTimeElapsed:
            return true
        case .timerStart, .timerEnd, .repeatingInterval, .counterReachesValue, .anyTimerStart, .anyTimerEnd:
            return false
        }
    }
    
    var needsIntervalValue: Bool {
        return self == .repeatingInterval
    }
    
    var needsCounter: Bool {
        switch self {
        case .counterReachesValue:
            return true
        default:
            return false
        }
    }
}

enum ActionType: String, CaseIterable, Codable {
    case playSound = "play_sound"
    case modifyCounter = "modify_counter"
    case showNotification = "show_notification"
    case pauseTimer = "pause_timer"
    case skipTimer = "skip_timer"
    
    var displayName: String {
        switch self {
        case .playSound: return "Play Sound"
        case .modifyCounter: return "Modify Counter"
        case .showNotification: return "Show Notification"
        case .pauseTimer: return "Pause Timer"
        case .skipTimer: return "Skip to Next Timer"
        }
    }
    
    var needsSound: Bool {
        return self == .playSound
    }
    
    var needsCounter: Bool {
        return self == .modifyCounter
    }
    
    var needsMessage: Bool {
        return self == .showNotification
    }
}

enum SoundType: String, CaseIterable, Codable {
    case bell = "bell"
    case chime = "chime"
    case alert = "alert"
    case notification = "notification"
    case custom = "custom"
    
    var displayName: String {
        switch self {
        case .bell: return "Bell"
        case .chime: return "Chime"
        case .alert: return "Alert"
        case .notification: return "Notification"
        case .custom: return "Custom"
        }
    }
    
    var systemSoundID: UInt32 {
        switch self {
        case .bell: return 1005 // System bell
        case .chime: return 1016 // Chime
        case .alert: return 1007 // Alert
        case .notification: return 1003 // Notification
        case .custom: return 1005 // Default to bell for now
        }
    }
}