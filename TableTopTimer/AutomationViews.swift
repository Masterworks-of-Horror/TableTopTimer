//
//  AutomationViews.swift
//  TableTopTimer
//
//  Created by Yuhao Chen on 6/21/25.
//

import SwiftUI
import SwiftData

struct AutomationConfigurationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let timerList: TimerList
    
    @State private var showingAddAutomation = false
    @State private var editingAutomation: Automation?
    
    @Query private var allAutomations: [Automation]
    
    private var automations: [Automation] {
        allAutomations.filter { automation in
            automation.list?.id == timerList.id
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                if automations.isEmpty {
                    ContentUnavailableView {
                        Label("No Automations", systemImage: "gearshape.2")
                    } description: {
                        Text("Create automations to add smart behaviors to your timers")
                    } actions: {
                        Button("Add Automation") {
                            showingAddAutomation = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        ForEach(automations.sorted(by: { $0.order < $1.order })) { automation in
                            AutomationRow(automation: automation, editingAutomation: $editingAutomation)
                        }
                        .onDelete(perform: deleteAutomations)
                        .onMove(perform: moveAutomations)
                    }
                }
            }
            .navigationTitle("Automations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddAutomation = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddAutomation) {
                ComprehensiveAutomationView(timerList: timerList, automation: nil)
            }
            .sheet(item: $editingAutomation) { automation in
                ComprehensiveAutomationView(timerList: timerList, automation: automation)
            }
        }
    }
    
    private func deleteAutomations(at offsets: IndexSet) {
        for index in offsets {
            let automation = automations.sorted(by: { $0.order < $1.order })[index]
            modelContext.delete(automation)
        }
        updateAutomationOrders()
        try? modelContext.save()
    }
    
    private func moveAutomations(from source: IndexSet, to destination: Int) {
        var sortedAutomations = automations.sorted(by: { $0.order < $1.order })
        sortedAutomations.move(fromOffsets: source, toOffset: destination)
        
        for (index, automation) in sortedAutomations.enumerated() {
            automation.order = index
        }
        
        try? modelContext.save()
    }
    
    private func updateAutomationOrders() {
        let sortedAutomations = automations.sorted(by: { $0.order < $1.order })
        for (index, automation) in sortedAutomations.enumerated() {
            automation.order = index
        }
    }
}

struct AutomationRow: View {
    let automation: Automation
    @Binding var editingAutomation: Automation?
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(automation.name)
                        .font(.headline)
                    
                    if !automation.isEnabled {
                        Text("Disabled")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.3))
                            .foregroundColor(.secondary)
                            .clipShape(Capsule())
                    }
                }
                
                Text(automationDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: Binding(
                get: { automation.isEnabled },
                set: { newValue in
                    automation.isEnabled = newValue
                    try? modelContext.save()
                }
            ))
        }
        .contentShape(Rectangle())
        .onTapGesture {
            editingAutomation = automation
        }
    }
    
    private var automationDescription: String {
        let triggerCount = automation.triggers.count
        let actionCount = automation.actions.count
        
        if triggerCount == 0 && actionCount == 0 {
            return "No triggers or actions"
        } else if triggerCount == 0 {
            return "\(actionCount) action(s), no triggers"
        } else if actionCount == 0 {
            return "\(triggerCount) trigger(s), no actions"
        } else {
            return "\(triggerCount) trigger(s) → \(actionCount) action(s)"
        }
    }
}

struct AddAutomationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let timerList: TimerList
    
    @State private var name = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Automation Name") {
                    TextField("Enter automation name", text: $name)
                }
                
                Section(footer: Text("You can add triggers and actions after creating the automation.")) {
                    // Empty section for spacing
                }
            }
            .navigationTitle("New Automation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createAutomation()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
    
    private func createAutomation() {
        // Count current automations for this timer list
        let descriptor = FetchDescriptor<Automation>()
        let allAutomations = (try? modelContext.fetch(descriptor)) ?? []
        let currentCount = allAutomations.filter { $0.list?.id == timerList.id }.count
        
        let newAutomation = Automation(name: name, order: currentCount)
        newAutomation.list = timerList
        modelContext.insert(newAutomation)
        
        try? modelContext.save()
        dismiss()
    }
}

struct EditAutomationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let automation: Automation
    @State private var name: String = ""
    @State private var showingAddTrigger = false
    @State private var showingAddAction = false
    @State private var editingTrigger: AutomationTrigger?
    @State private var editingAction: AutomationAction?
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Automation Name") {
                    TextField("Enter automation name", text: $name)
                }
                
                Section("Triggers") {
                    if automation.triggers.isEmpty {
                        Text("No triggers")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(automation.triggers, id: \.id) { trigger in
                            TriggerRow(trigger: trigger)
                                .onTapGesture {
                                    editingTrigger = trigger
                                }
                        }
                        .onDelete(perform: deleteTriggers)
                    }
                    
                    Button("Add Trigger") {
                        showingAddTrigger = true
                    }
                    .foregroundColor(.accentColor)
                }
                
                Section("Actions") {
                    if automation.actions.isEmpty {
                        Text("No actions")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(automation.actions, id: \.id) { action in
                            ActionRow(action: action)
                                .onTapGesture {
                                    editingAction = action
                                }
                        }
                        .onDelete(perform: deleteActions)
                    }
                    
                    Button("Add Action") {
                        showingAddAction = true
                    }
                    .foregroundColor(.accentColor)
                }
            }
            .navigationTitle("Edit Automation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(name.isEmpty)
                }
            }
            .onAppear {
                name = automation.name
            }
            .sheet(isPresented: $showingAddTrigger) {
                AddTriggerView(automation: automation)
            }
            .sheet(isPresented: $showingAddAction) {
                AddActionView(automation: automation)
            }
            .sheet(item: $editingTrigger) { trigger in
                EditTriggerView(trigger: trigger)
            }
            .sheet(item: $editingAction) { action in
                EditActionView(action: action)
            }
        }
    }
    
    private func saveChanges() {
        automation.name = name
        try? modelContext.save()
        dismiss()
    }
    
    private func deleteTriggers(at offsets: IndexSet) {
        for index in offsets {
            let trigger = automation.triggers[index]
            automation.triggers.remove(at: index)
            modelContext.delete(trigger)
        }
        try? modelContext.save()
    }
    
    private func deleteActions(at offsets: IndexSet) {
        for index in offsets {
            let action = automation.actions[index]
            automation.actions.remove(at: index)
            modelContext.delete(action)
        }
        try? modelContext.save()
    }
}

struct TriggerRow: View {
    let trigger: AutomationTrigger
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(trigger.type.displayName)
                .font(.subheadline)
            
            if let description = triggerDescription {
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var triggerDescription: String? {
        switch trigger.type {
        case .timerStart, .timerEnd:
            return trigger.timerName ?? "No timer selected"
        case .timerTimeRemaining:
            if let timer = trigger.timerName, let time = trigger.timeValue {
                return "\(Int(time)) seconds before \(timer) ends"
            }
            return "Not configured"
        case .timerTimeElapsed:
            if let timer = trigger.timerName, let time = trigger.timeValue {
                return "\(Int(time)) seconds after \(timer) starts"
            }
            return "Not configured"
        case .repeatingInterval:
            if let interval = trigger.intervalValue {
                return "Every \(Int(interval)) seconds"
            }
            return "Not configured"
        case .counterReachesValue:
            if let counter = trigger.counterName, let value = trigger.counterValue {
                return "\(counter) reaches \(value)"
            }
            return "Not configured"
        case .anyTimerStart:
            return "When any timer starts"
        case .anyTimerEnd:
            return "When any timer ends"
        }
    }
}

struct ActionRow: View {
    let action: AutomationAction
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(action.type.displayName)
                .font(.subheadline)
            
            if let description = actionDescription {
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var actionDescription: String? {
        switch action.type {
        case .playSound:
            return action.soundType?.displayName ?? "No sound selected"
        case .modifyCounter:
            if let counter = action.counterName, let change = action.counterChange {
                let changeText = change > 0 ? "+\(change)" : "\(change)"
                return "\(counter) \(changeText)"
            }
            return "Not configured"
        case .showNotification:
            return action.message ?? "No message"
        case .pauseTimer:
            return "Pause current timer"
        case .skipTimer:
            return "Skip to next timer"
        }
    }
}

// MARK: - Add/Edit Trigger Views

struct AddTriggerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let automation: Automation
    
    @State private var selectedType: TriggerType = .timerStart
    @State private var timerName = ""
    @State private var timeValue: Double = 10
    @State private var intervalValue: Double = 5
    @State private var counterName = ""
    @State private var counterValue: Int = 0
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Trigger Type") {
                    Picker("Type", selection: $selectedType) {
                        ForEach(TriggerType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                if selectedType.needsTimer {
                    Section("Timer") {
                        TextField("Timer name", text: $timerName)
                    }
                }
                
                if selectedType.needsTimeValue {
                    Section("Time (seconds)") {
                        HStack {
                            Slider(value: $timeValue, in: 1...300, step: 1)
                            Text("\(Int(timeValue))s")
                                .frame(width: 40)
                        }
                    }
                }
                
                if selectedType == .repeatingInterval {
                    Section("Interval (seconds)") {
                        HStack {
                            Slider(value: $intervalValue, in: 1...60, step: 1)
                            Text("\(Int(intervalValue))s")
                                .frame(width: 40)
                        }
                    }
                }
                
                if selectedType.needsCounter {
                    Section("Counter") {
                        TextField("Counter name", text: $counterName)
                        Stepper("Value: \(counterValue)", value: $counterValue, in: -999...999)
                    }
                }
            }
            .navigationTitle("Add Trigger")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        addTrigger()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }
    
    private var isValid: Bool {
        if selectedType.needsTimer && timerName.isEmpty { return false }
        if selectedType.needsCounter && counterName.isEmpty { return false }
        return true
    }
    
    private func addTrigger() {
        let trigger = AutomationTrigger(type: selectedType)
        
        if selectedType.needsTimer {
            trigger.timerName = timerName
        }
        
        if selectedType.needsTimeValue {
            trigger.timeValue = timeValue
        }
        
        if selectedType == .repeatingInterval {
            trigger.intervalValue = intervalValue
        }
        
        if selectedType.needsCounter {
            trigger.counterName = counterName
            trigger.counterValue = counterValue
        }
        
        trigger.automation = automation
        automation.triggers.append(trigger)
        modelContext.insert(trigger)
        
        try? modelContext.save()
        dismiss()
    }
}

struct EditTriggerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let trigger: AutomationTrigger
    
    @State private var timerName = ""
    @State private var timeValue: Double = 10
    @State private var intervalValue: Double = 5
    @State private var counterName = ""
    @State private var counterValue: Int = 0
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Trigger Type") {
                    Text(trigger.type.displayName)
                        .foregroundColor(.secondary)
                }
                
                if trigger.type.needsTimer {
                    Section("Timer") {
                        TextField("Timer name", text: $timerName)
                    }
                }
                
                if trigger.type.needsTimeValue {
                    Section("Time (seconds)") {
                        HStack {
                            Slider(value: $timeValue, in: 1...300, step: 1)
                            Text("\(Int(timeValue))s")
                                .frame(width: 40)
                        }
                    }
                }
                
                if trigger.type == .repeatingInterval {
                    Section("Interval (seconds)") {
                        HStack {
                            Slider(value: $intervalValue, in: 1...60, step: 1)
                            Text("\(Int(intervalValue))s")
                                .frame(width: 40)
                        }
                    }
                }
                
                if trigger.type.needsCounter {
                    Section("Counter") {
                        TextField("Counter name", text: $counterName)
                        Stepper("Value: \(counterValue)", value: $counterValue, in: -999...999)
                    }
                }
            }
            .navigationTitle("Edit Trigger")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(!isValid)
                }
            }
            .onAppear {
                loadTriggerData()
            }
        }
    }
    
    private var isValid: Bool {
        if trigger.type.needsTimer && timerName.isEmpty { return false }
        if trigger.type.needsCounter && counterName.isEmpty { return false }
        return true
    }
    
    private func loadTriggerData() {
        timerName = trigger.timerName ?? ""
        timeValue = trigger.timeValue ?? 10
        intervalValue = trigger.intervalValue ?? 5
        counterName = trigger.counterName ?? ""
        counterValue = trigger.counterValue ?? 0
    }
    
    private func saveChanges() {
        if trigger.type.needsTimer {
            trigger.timerName = timerName
        }
        
        if trigger.type.needsTimeValue {
            trigger.timeValue = timeValue
        }
        
        if trigger.type == .repeatingInterval {
            trigger.intervalValue = intervalValue
        }
        
        if trigger.type.needsCounter {
            trigger.counterName = counterName
            trigger.counterValue = counterValue
        }
        
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Add/Edit Action Views

struct AddActionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let automation: Automation
    
    @State private var selectedType: ActionType = .playSound
    @State private var selectedSound: SoundType = .bell
    @State private var counterName = ""
    @State private var counterChange: Int = 1
    @State private var message = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Action Type") {
                    Picker("Type", selection: $selectedType) {
                        ForEach(ActionType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                if selectedType.needsSound {
                    Section("Sound") {
                        Picker("Sound", selection: $selectedSound) {
                            ForEach(SoundType.allCases, id: \.self) { sound in
                                Text(sound.displayName).tag(sound)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                    }
                }
                
                if selectedType.needsCounter {
                    Section("Counter") {
                        TextField("Counter name", text: $counterName)
                        Stepper("Change: \(counterChange > 0 ? "+" : "")\(counterChange)", value: $counterChange, in: -99...99)
                    }
                }
                
                if selectedType.needsMessage {
                    Section("Message") {
                        TextField("Enter message", text: $message, axis: .vertical)
                            .lineLimit(3...6)
                    }
                }
            }
            .navigationTitle("Add Action")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        addAction()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }
    
    private var isValid: Bool {
        if selectedType.needsCounter && counterName.isEmpty { return false }
        if selectedType.needsMessage && message.isEmpty { return false }
        return true
    }
    
    private func addAction() {
        let action = AutomationAction(type: selectedType)
        
        if selectedType.needsSound {
            action.soundType = selectedSound
        }
        
        if selectedType.needsCounter {
            action.counterName = counterName
            action.counterChange = counterChange
        }
        
        if selectedType.needsMessage {
            action.message = message
        }
        
        action.automation = automation
        automation.actions.append(action)
        modelContext.insert(action)
        
        try? modelContext.save()
        dismiss()
    }
}

struct EditActionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let action: AutomationAction
    
    @State private var selectedSound: SoundType = .bell
    @State private var counterName = ""
    @State private var counterChange: Int = 1
    @State private var message = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Action Type") {
                    Text(action.type.displayName)
                        .foregroundColor(.secondary)
                }
                
                if action.type.needsSound {
                    Section("Sound") {
                        Picker("Sound", selection: $selectedSound) {
                            ForEach(SoundType.allCases, id: \.self) { sound in
                                Text(sound.displayName).tag(sound)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                    }
                }
                
                if action.type.needsCounter {
                    Section("Counter") {
                        TextField("Counter name", text: $counterName)
                        Stepper("Change: \(counterChange > 0 ? "+" : "")\(counterChange)", value: $counterChange, in: -99...99)
                    }
                }
                
                if action.type.needsMessage {
                    Section("Message") {
                        TextField("Enter message", text: $message, axis: .vertical)
                            .lineLimit(3...6)
                    }
                }
            }
            .navigationTitle("Edit Action")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(!isValid)
                }
            }
            .onAppear {
                loadActionData()
            }
        }
    }
    
    private var isValid: Bool {
        if action.type.needsCounter && counterName.isEmpty { return false }
        if action.type.needsMessage && message.isEmpty { return false }
        return true
    }
    
    private func loadActionData() {
        selectedSound = action.soundType ?? .bell
        counterName = action.counterName ?? ""
        counterChange = action.counterChange ?? 1
        message = action.message ?? ""
    }
    
    private func saveChanges() {
        if action.type.needsSound {
            action.soundType = selectedSound
        }
        
        if action.type.needsCounter {
            action.counterName = counterName
            action.counterChange = counterChange
        }
        
        if action.type.needsMessage {
            action.message = message
        }
        
        try? modelContext.save()
        dismiss()
    }
}