//
//  AutomationManager.swift
//  TableTopTimer
//
//  Created by Yuhao Chen on 6/21/25.
//

import Foundation
import SwiftUI
import AVFoundation
import SwiftData

@Observable
class AutomationManager {
    private var modelContext: ModelContext?
    private var activeIntervals: [UUID: Timer] = [:]
    private var intervalStartTimes: [UUID: Date] = [:]
    private var intervalElapsedTimes: [UUID: TimeInterval] = [:]
    private var lastTriggerStates: [String: Any] = [:]
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }
    
    // MARK: - Trigger Events
    
    func timerStarted(_ timer: TimerItem, timerManager: TimerManager) {
        guard let context = modelContext else { return }
        
        let automations = fetchAutomations(for: timer.list, context: context)
        
        for automation in automations {
            guard automation.isEnabled else { continue }
            
            for trigger in automation.triggers {
                switch trigger.type {
                case .timerStart:
                    if trigger.timerName == timer.name {
                        executeActions(automation.actions, context: context, timerManager: timerManager)
                    }
                case .anyTimerStart:
                    executeActions(automation.actions, context: context, timerManager: timerManager)
                case .timerTimeElapsed:
                    if trigger.timerName == timer.name, let timeValue = trigger.timeValue {
                        scheduleDelayedAction(after: timeValue, automation: automation, context: context, timerManager: timerManager)
                    }
                case .repeatingInterval:
                    if let intervalValue = trigger.intervalValue {
                        startRepeatingInterval(intervalValue, automation: automation, context: context, timerManager: timerManager)
                    }
                default:
                    break
                }
            }
        }
    }
    
    func timerEnded(_ timer: TimerItem, timerManager: TimerManager) {
        guard let context = modelContext else { return }
        
        stopAllIntervals()
        
        let automations = fetchAutomations(for: timer.list, context: context)
        
        for automation in automations {
            guard automation.isEnabled else { continue }
            
            for trigger in automation.triggers {
                switch trigger.type {
                case .timerEnd:
                    if trigger.timerName == timer.name {
                        executeActions(automation.actions, context: context, timerManager: timerManager)
                    }
                case .anyTimerEnd:
                    executeActions(automation.actions, context: context, timerManager: timerManager)
                default:
                    break
                }
            }
        }
    }
    
    func timerTick(_ timer: TimerItem, timeRemaining: Double, timerManager: TimerManager) {
        guard let context = modelContext else { return }
        
        let automations = fetchAutomations(for: timer.list, context: context)
        
        for automation in automations {
            guard automation.isEnabled else { continue }
            
            for trigger in automation.triggers {
                if trigger.type == .timerTimeRemaining,
                   trigger.timerName == timer.name,
                   let timeValue = trigger.timeValue {
                    
                    let triggerKey = "\(automation.id)_\(trigger.id)_remaining"
                    
                    // Check if we've crossed the threshold
                    if timeRemaining <= timeValue && (lastTriggerStates[triggerKey] as? Bool != true) {
                        lastTriggerStates[triggerKey] = true
                        executeActions(automation.actions, context: context, timerManager: timerManager)
                    } else if timeRemaining > timeValue {
                        lastTriggerStates[triggerKey] = false
                    }
                }
            }
        }
    }
    
    func counterChanged(_ counter: Counter, oldValue: Int, newValue: Int, timerManager: TimerManager) {
        guard let context = modelContext else { return }
        
        let automations = fetchAutomations(for: counter.list, context: context)
        
        for automation in automations {
            guard automation.isEnabled else { continue }
            
            for trigger in automation.triggers {
                if trigger.type == .counterReachesValue,
                   trigger.counterName == counter.name,
                   let targetValue = trigger.counterValue {
                    
                    if newValue == targetValue && oldValue != targetValue {
                        executeActions(automation.actions, context: context, timerManager: timerManager)
                    }
                }
            }
        }
    }
    
    // MARK: - Action Execution
    
    private func executeActions(_ actions: [AutomationAction], context: ModelContext, timerManager: TimerManager) {
        for action in actions {
            executeAction(action, context: context, timerManager: timerManager)
        }
    }
    
    private func executeAction(_ action: AutomationAction, context: ModelContext, timerManager: TimerManager) {
        switch action.type {
        case .playSound:
            if let soundType = action.soundType {
                playSound(soundType)
            }
            
        case .modifyCounter:
            if let counterName = action.counterName,
               let change = action.counterChange {
                modifyCounter(named: counterName, by: change, context: context)
            }
            
        case .showNotification:
            if let message = action.message {
                showNotification(message)
            }
            
        case .pauseTimer:
            timerManager.pauseTimer()
            
        case .skipTimer:
            timerManager.skipToNext()
        }
    }
    
    // MARK: - Helper Methods
    
    private func fetchAutomations(for timerList: TimerList?, context: ModelContext) -> [Automation] {
        guard let timerList = timerList else { return [] }
        
        // Use a simpler approach to avoid predicate compilation issues
        let descriptor = FetchDescriptor<Automation>()
        let allAutomations = (try? context.fetch(descriptor)) ?? []
        
        // Filter manually to avoid complex predicate syntax
        return allAutomations.filter { automation in
            automation.list?.id == timerList.id
        }
    }
    
    private func scheduleDelayedAction(after delay: Double, automation: Automation, context: ModelContext, timerManager: TimerManager) {
        Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { _ in
            self.executeActions(automation.actions, context: context, timerManager: timerManager)
        }
    }
    
    private func startRepeatingInterval(_ interval: Double, automation: Automation, context: ModelContext, timerManager: TimerManager) {
        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            self.executeActions(automation.actions, context: context, timerManager: timerManager)
        }
        activeIntervals[automation.id] = timer
        intervalStartTimes[automation.id] = Date()
    }
    
    private func stopAllIntervals() {
        for timer in activeIntervals.values {
            timer.invalidate()
        }
        activeIntervals.removeAll()
        intervalStartTimes.removeAll()
        lastTriggerStates.removeAll()
    }
    
    private func playSound(_ soundType: SoundType) {
        AudioServicesPlaySystemSound(soundType.systemSoundID)
        
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
    
    private func modifyCounter(named counterName: String, by change: Int, context: ModelContext) {
        // Use simpler fetch approach
        let descriptor = FetchDescriptor<Counter>()
        let allCounters = (try? context.fetch(descriptor)) ?? []
        
        let matchingCounters = allCounters.filter { counter in
            counter.name == counterName
        }
        
        for counter in matchingCounters {
            let newValue = counter.value + change
            
            // Respect min/max limits
            if let min = counter.minValue, newValue < min {
                counter.value = min
            } else if let max = counter.maxValue, newValue > max {
                counter.value = max
            } else {
                counter.value = newValue
            }
        }
        try? context.save()
    }
    
    private func showNotification(_ message: String) {
        // For now, we'll use a simple alert-style notification
        // In a full implementation, you might want to use a custom notification view
        DispatchQueue.main.async {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                
                let alert = UIAlertController(title: "Automation", message: message, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                
                window.rootViewController?.present(alert, animated: true)
            }
        }
    }
    
    // MARK: - Timer State Management
    
    func pauseAutomations() {
        // Save elapsed time for each active interval and stop timers
        for (automationId, timer) in activeIntervals {
            timer.invalidate()
            
            if let startTime = intervalStartTimes[automationId] {
                let elapsed = Date().timeIntervalSince(startTime)
                intervalElapsedTimes[automationId] = (intervalElapsedTimes[automationId] ?? 0) + elapsed
            }
        }
        activeIntervals.removeAll()
        intervalStartTimes.removeAll()
    }
    
    func resumeAutomations(timerManager: TimerManager) {
        guard let context = modelContext,
              let currentTimer = timerManager.currentTimerItem else { return }
        
        let automations = fetchAutomations(for: currentTimer.list, context: context)
        
        for automation in automations {
            guard automation.isEnabled else { continue }
            
            for trigger in automation.triggers {
                if trigger.type == .repeatingInterval,
                   let intervalValue = trigger.intervalValue {
                    
                    let elapsedTime = intervalElapsedTimes[automation.id] ?? 0
                    let remainingTime = intervalValue - (elapsedTime.truncatingRemainder(dividingBy: intervalValue))
                    
                    // Schedule next trigger based on remaining time
                    Timer.scheduledTimer(withTimeInterval: remainingTime, repeats: false) { _ in
                        self.executeActions(automation.actions, context: context, timerManager: timerManager)
                        // Then start regular interval
                        self.startRepeatingInterval(intervalValue, automation: automation, context: context, timerManager: timerManager)
                    }
                }
            }
        }
    }
    
    // MARK: - Cleanup
    
    func stopAutomations() {
        stopAllIntervals()
        intervalElapsedTimes.removeAll()
    }
}