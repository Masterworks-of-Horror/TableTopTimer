//
//  TimerListDetailView.swift
//  TableTopTimer
//
//  Created by Yuhao Chen on 6/21/25.
//

import SwiftUI
import SwiftData

struct TimerListDetailView: View {
    @Environment(TimerManager.self) private var timerManager
    @Environment(\.modelContext) private var modelContext
    
    let timerList: TimerList
    
    @State private var showingAddTimer = false
    @State private var editingTimer: TimerItem?
    @State private var showingTimerSheet = false
    @State private var showingCounterConfig = false
    @State private var showingAutomationConfig = false
    
    var body: some View {
        VStack {
            if timerList.timers.isEmpty {
                ContentUnavailableView {
                    Label("No Timers", systemImage: "timer")
                } description: {
                    Text("Add timers to this list")
                } actions: {
                    Button("Add Timer") {
                        showingAddTimer = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                TimerListContent(timerList: timerList, editingTimer: $editingTimer)
            }
        }
        .navigationTitle(timerList.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button(action: { showingAutomationConfig = true }) {
                    Label("Automations", systemImage: "gearshape.2")
                }
                
                Button(action: { showingCounterConfig = true }) {
                    Label("Counters", systemImage: "number.circle")
                }
                
                Button(action: { showingAddTimer = true }) {
                    Label("Add Timer", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddTimer) {
            AddTimerToListView(timerList: timerList)
        }
        .sheet(item: $editingTimer) { timer in
            EditTimerView(timer: timer)
        }
        .sheet(isPresented: $showingCounterConfig) {
            CounterConfigurationView(timerList: timerList)
        }
        .sheet(isPresented: $showingAutomationConfig) {
            AutomationConfigurationView(timerList: timerList)
        }
        .sheet(isPresented: $showingTimerSheet) {
            CurrentTimerSheet(timerList: timerList)
                .presentationDetents([.height(300), .large])
                .presentationDragIndicator(.visible)
                .interactiveDismissDisabled()
                .presentationBackgroundInteraction(.enabled(upThrough: .height(300)))
                .presentationCornerRadius(20)
        }
        .onAppear {
            loadTimers()
        }
        .onChange(of: timerManager.isRunning) { _, newValue in
            showingTimerSheet = newValue || timerManager.isPaused
        }
        .onChange(of: timerManager.currentTimerIndex) { _, newValue in
            showingTimerSheet = newValue != nil
        }
    }
    
    private func loadTimers() {
        timerManager.timers = timerList.timers.sorted { $0.order < $1.order }
        timerManager.setModelContext(modelContext)
        timerList.lastUsedAt = Date()
        try? modelContext.save()
    }
}

struct TimerListContent: View {
    @Environment(TimerManager.self) private var timerManager
    @Environment(\.modelContext) private var modelContext
    
    let timerList: TimerList
    @Binding var editingTimer: TimerItem?
    
    var body: some View {
        List {
            ForEach(Array(timerList.timers.sorted(by: { $0.order < $1.order }).enumerated()), id: \.element.id) { index, timer in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(timer.name)
                            .font(.headline)
                        Text(timerManager.formatTime(timer.duration))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        if timerManager.currentTimerIndex == nil {
                            timerManager.timers = timerList.timers.sorted { $0.order < $1.order }
                            timerManager.startTimers(fromIndex: index)
                        }
                    }) {
                        Image(systemName: timerManager.currentTimerIndex == index ? "play.circle.fill" : "play.circle")
                            .font(.title2)
                            .foregroundColor(timerManager.currentTimerIndex == index ? .green : .accentColor)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(timerManager.currentTimerIndex != nil && timerManager.currentTimerIndex != index)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    editingTimer = timer
                }
            }
            .onDelete { indexSet in
                deleteTimers(at: indexSet)
            }
            .onMove { source, destination in
                moveTimers(from: source, to: destination)
            }
        }
        .listStyle(PlainListStyle())
    }
    
    private func deleteTimers(at offsets: IndexSet) {
        for index in offsets {
            let timer = timerList.timers.sorted(by: { $0.order < $1.order })[index]
            if let timerIndex = timerList.timers.firstIndex(where: { $0.id == timer.id }) {
                timerList.timers.remove(at: timerIndex)
            }
            modelContext.delete(timer)
        }
        updateTimerOrders()
        try? modelContext.save()
    }
    
    private func moveTimers(from source: IndexSet, to destination: Int) {
        var sortedTimers = timerList.timers.sorted(by: { $0.order < $1.order })
        sortedTimers.move(fromOffsets: source, toOffset: destination)
        
        for (index, timer) in sortedTimers.enumerated() {
            timer.order = index
        }
        
        try? modelContext.save()
    }
    
    private func updateTimerOrders() {
        let sortedTimers = timerList.timers.sorted(by: { $0.order < $1.order })
        for (index, timer) in sortedTimers.enumerated() {
            timer.order = index
        }
    }
}

struct AddTimerToListView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let timerList: TimerList
    
    @State private var name = ""
    @State private var minutes = 1
    @State private var seconds = 0
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Timer Name") {
                    TextField("Enter timer name", text: $name)
                }
                
                Section("Duration") {
                    HStack {
                        Picker("Minutes", selection: $minutes) {
                            ForEach(0..<60) { minute in
                                Text("\(minute) min").tag(minute)
                            }
                        }
                        .pickerStyle(WheelPickerStyle())
                        
                        Picker("Seconds", selection: $seconds) {
                            ForEach(0..<60) { second in
                                Text("\(second) sec").tag(second)
                            }
                        }
                        .pickerStyle(WheelPickerStyle())
                    }
                }
            }
            .navigationTitle("New Timer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        addTimer()
                    }
                    .disabled(name.isEmpty || (minutes == 0 && seconds == 0))
                }
            }
        }
    }
    
    private func addTimer() {
        let duration = TimeInterval(minutes * 60 + seconds)
        let newTimer = TimerItem(name: name.isEmpty ? "Timer" : name, duration: duration, order: timerList.timers.count)
        
        newTimer.list = timerList
        timerList.timers.append(newTimer)
        modelContext.insert(newTimer)
        
        try? modelContext.save()
        dismiss()
    }
}