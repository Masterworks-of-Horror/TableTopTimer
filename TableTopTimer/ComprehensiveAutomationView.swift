//
//  ComprehensiveAutomationView.swift
//  TableTopTimer
//
//  Created by Yuhao Chen on 6/21/25.
//

import SwiftUI
import SwiftData

struct ComprehensiveAutomationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let timerList: TimerList
    let automation: Automation?
    
    @State private var name = ""
    @State private var isEnabled = true
    
    // Trigger configuration
    @State private var triggerType: TriggerType = .timerStart
    @State private var selectedTimer: TimerItem?
    @State private var timeValue: Double = 10
    @State private var intervalValue: Double = 5
    @State private var selectedCounter: Counter?
    @State private var counterValue: Int = 0
    
    // Action configuration
    @State private var actionType: ActionType = .playSound
    @State private var selectedSound: SoundType = .bell
    @State private var actionCounter: Counter?
    @State private var counterChange: Int = 1
    @State private var message = ""
    
    private var availableTimers: [TimerItem] {
        timerList.timers.sorted { $0.order < $1.order }
    }
    
    private var availableCounters: [Counter] {
        timerList.counters.sorted { $0.order < $1.order }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Automation Details") {
                    TextField("Automation name", text: $name)
                    
                    Toggle("Enabled", isOn: $isEnabled)
                }
                
                Section("When (Trigger)") {
                    Picker("Trigger Type", selection: $triggerType) {
                        ForEach(TriggerType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    
                    // Timer selection for specific timer triggers
                    if triggerType.needsTimer {
                        if availableTimers.isEmpty {
                            Text("No timers available. Add timers first.")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        } else {
                            Picker("Timer", selection: $selectedTimer) {
                                Text("Select Timer").tag(nil as TimerItem?)
                                ForEach(availableTimers, id: \.id) { timer in
                                    Text(timer.name).tag(timer as TimerItem?)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                        }
                    }
                    
                    // Time value for time-based triggers
                    if triggerType.needsTimeValue {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Time: \(Int(timeValue)) seconds")
                                .font(.subheadline)
                            Slider(value: $timeValue, in: 1...300, step: 1)
                        }
                    }
                    
                    // Interval for repeating triggers
                    if triggerType.needsIntervalValue {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Every \(Int(intervalValue)) seconds")
                                .font(.subheadline)
                            Slider(value: $intervalValue, in: 1...60, step: 1)
                        }
                    }
                    
                    // Counter selection for counter triggers
                    if triggerType.needsCounter {
                        if availableCounters.isEmpty {
                            Text("No counters available. Add counters first.")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        } else {
                            Picker("Counter", selection: $selectedCounter) {
                                Text("Select Counter").tag(nil as Counter?)
                                ForEach(availableCounters, id: \.id) { counter in
                                    Text(counter.name).tag(counter as Counter?)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            
                            Stepper("When value reaches: \(counterValue)", value: $counterValue, in: -999...999)
                        }
                    }
                }
                
                Section("Then (Action)") {
                    Picker("Action Type", selection: $actionType) {
                        ForEach(ActionType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    
                    // Sound selection for play sound action
                    if actionType.needsSound {
                        Picker("Sound", selection: $selectedSound) {
                            ForEach(SoundType.allCases, id: \.self) { sound in
                                Text(sound.displayName).tag(sound)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                    }
                    
                    // Counter modification for counter actions
                    if actionType.needsCounter {
                        if availableCounters.isEmpty {
                            Text("No counters available. Add counters first.")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        } else {
                            Picker("Counter", selection: $actionCounter) {
                                Text("Select Counter").tag(nil as Counter?)
                                ForEach(availableCounters, id: \.id) { counter in
                                    Text(counter.name).tag(counter as Counter?)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            
                            Stepper("Change by: \(counterChange > 0 ? "+" : "")\(counterChange)", value: $counterChange, in: -99...99)
                        }
                    }
                    
                    // Message for notification action
                    if actionType.needsMessage {
                        TextField("Notification message", text: $message, axis: .vertical)
                            .lineLimit(2...4)
                    }
                }
                
                Section {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Preview")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text(automationPreview)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle(automation == nil ? "New Automation" : "Edit Automation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(automation == nil ? "Create" : "Save") {
                        saveAutomation()
                    }
                    .disabled(!isValidConfiguration)
                }
            }
            .onAppear {
                if let automation = automation {
                    loadExistingAutomation(automation)
                }
            }
        }
    }
    
    private var automationPreview: String {
        var triggerText = triggerType.displayName
        var actionText = actionType.displayName
        
        // Add trigger details
        switch triggerType {
        case .timerStart, .timerEnd:
            if let timer = selectedTimer {
                triggerText += " (\(timer.name))"
            }
        case .timerTimeRemaining:
            if let timer = selectedTimer {
                triggerText += " (\(Int(timeValue))s before \(timer.name) ends)"
            }
        case .timerTimeElapsed:
            if let timer = selectedTimer {
                triggerText += " (\(Int(timeValue))s after \(timer.name) starts)"
            }
        case .repeatingInterval:
            triggerText += " (every \(Int(intervalValue))s)"
        case .counterReachesValue:
            if let counter = selectedCounter {
                triggerText += " (\(counter.name) = \(counterValue))"
            }
        case .anyTimerStart, .anyTimerEnd:
            break
        }
        
        // Add action details
        switch actionType {
        case .playSound:
            actionText += " (\(selectedSound.displayName))"
        case .modifyCounter:
            if let counter = actionCounter {
                let changeText = counterChange > 0 ? "+\(counterChange)" : "\(counterChange)"
                actionText += " (\(counter.name) \(changeText))"
            }
        case .showNotification:
            if !message.isEmpty {
                actionText += " (\"\(message)\")"
            }
        case .pauseTimer, .skipTimer:
            break
        }
        
        return "\(triggerText) → \(actionText)"
    }
    
    private var isValidConfiguration: Bool {
        if name.isEmpty { return false }
        
        // Validate trigger configuration
        switch triggerType {
        case .timerStart, .timerEnd, .timerTimeRemaining, .timerTimeElapsed:
            if selectedTimer == nil { return false }
        case .counterReachesValue:
            if selectedCounter == nil { return false }
        case .anyTimerStart, .anyTimerEnd, .repeatingInterval:
            break
        }
        
        // Validate action configuration
        switch actionType {
        case .modifyCounter:
            if actionCounter == nil { return false }
        case .showNotification:
            if message.isEmpty { return false }
        case .playSound, .pauseTimer, .skipTimer:
            break
        }
        
        return true
    }
    
    private func loadExistingAutomation(_ automation: Automation) {
        name = automation.name
        isEnabled = automation.isEnabled
        
        // Load trigger data
        if let trigger = automation.triggers.first {
            triggerType = trigger.type
            
            if let timerName = trigger.timerName {
                selectedTimer = availableTimers.first { $0.name == timerName }
            }
            
            timeValue = trigger.timeValue ?? 10
            intervalValue = trigger.intervalValue ?? 5
            
            if let counterName = trigger.counterName {
                selectedCounter = availableCounters.first { $0.name == counterName }
            }
            
            counterValue = trigger.counterValue ?? 0
        }
        
        // Load action data
        if let action = automation.actions.first {
            actionType = action.type
            selectedSound = action.soundType ?? .bell
            
            if let counterName = action.counterName {
                actionCounter = availableCounters.first { $0.name == counterName }
            }
            
            counterChange = action.counterChange ?? 1
            message = action.message ?? ""
        }
    }
    
    private func saveAutomation() {
        let targetAutomation: Automation
        
        if let existingAutomation = automation {
            targetAutomation = existingAutomation
            targetAutomation.name = name
            targetAutomation.isEnabled = isEnabled
            
            // Clear existing triggers and actions
            for trigger in targetAutomation.triggers {
                modelContext.delete(trigger)
            }
            for action in targetAutomation.actions {
                modelContext.delete(action)
            }
            targetAutomation.triggers.removeAll()
            targetAutomation.actions.removeAll()
        } else {
            // Count current automations for this timer list
            let descriptor = FetchDescriptor<Automation>()
            let allAutomations = (try? modelContext.fetch(descriptor)) ?? []
            let currentCount = allAutomations.filter { $0.list?.id == timerList.id }.count
            
            targetAutomation = Automation(name: name, order: currentCount)
            targetAutomation.list = timerList
            targetAutomation.isEnabled = isEnabled
            modelContext.insert(targetAutomation)
        }
        
        // Create new trigger
        let trigger = AutomationTrigger(type: triggerType)
        trigger.automation = targetAutomation
        
        if triggerType.needsTimer {
            trigger.timerName = selectedTimer?.name
        }
        
        if triggerType.needsTimeValue {
            trigger.timeValue = timeValue
        }
        
        if triggerType.needsIntervalValue {
            trigger.intervalValue = intervalValue
        }
        
        if triggerType.needsCounter {
            trigger.counterName = selectedCounter?.name
            trigger.counterValue = counterValue
        }
        
        targetAutomation.triggers.append(trigger)
        modelContext.insert(trigger)
        
        // Create new action
        let action = AutomationAction(type: actionType)
        action.automation = targetAutomation
        
        if actionType.needsSound {
            action.soundType = selectedSound
        }
        
        if actionType.needsCounter {
            action.counterName = actionCounter?.name
            action.counterChange = counterChange
        }
        
        if actionType.needsMessage {
            action.message = message
        }
        
        targetAutomation.actions.append(action)
        modelContext.insert(action)
        
        try? modelContext.save()
        dismiss()
    }
}