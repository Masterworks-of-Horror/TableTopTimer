//
//  ContentView.swift
//  TableTopTimer
//
//  Created by Yuhao Chen on 6/20/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(TimerManager.self) private var timerManager
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TimerItem.order) private var savedTimers: [TimerItem]
    
    @State private var showingAddTimer = false
    @State private var editingTimer: TimerItem?
    @State private var showingTimerSheet = false
    
    var body: some View {
        NavigationStack {
            VStack {
                if timerManager.timers.isEmpty {
                    ContentUnavailableView {
                        Label("No Timers", systemImage: "timer")
                    } description: {
                        Text("Add timers to get started")
                    } actions: {
                        Button("Add Timer") {
                            showingAddTimer = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    TimerListView(editingTimer: $editingTimer)
                }
            }
            .navigationTitle("Table Top Timer")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddTimer = true }) {
                        Label("Add Timer", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddTimer) {
                AddTimerView()
            }
            .sheet(item: $editingTimer) { timer in
                EditTimerView(timer: timer)
            }
            .sheet(isPresented: $showingTimerSheet) {
                CurrentTimerSheet()
                    .presentationDetents([.height(300)])
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
    }
    
    private func loadTimers() {
        timerManager.timers = savedTimers.sorted { $0.order < $1.order }
    }
}

struct CurrentTimerSheet: View {
    @Environment(TimerManager.self) private var timerManager
    
    var body: some View {
        VStack(spacing: 20) {
            if let currentIndex = timerManager.currentTimerIndex,
               currentIndex < timerManager.timers.count {
                let currentTimer = timerManager.timers[currentIndex]
                
                VStack(spacing: 12) {
                    Text(currentTimer.name)
                        .font(.title)
                        .fontWeight(.semibold)
                    
                    Text(timerManager.formatTime(timerManager.timeRemaining))
                        .font(.system(size: 60, weight: .bold, design: .monospaced))
                        .monospacedDigit()
                    
                    if timerManager.autoPlayEnabled {
                        HStack {
                            Text("Timer \(currentIndex + 1) of \(timerManager.timers.count)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            if currentIndex < timerManager.timers.count - 1 {
                                Text("•")
                                    .foregroundColor(.secondary)
                                Text("Next: \(timerManager.timers[currentIndex + 1].name)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
                .padding(.top, 20)
                
                Spacer()
                
                HStack(spacing: 16) {
                    if timerManager.isRunning {
                        Button(action: { timerManager.pauseTimer() }) {
                            Image(systemName: "pause.fill")
                                .font(.title)
                        }
                        .frame(width: 60, height: 60)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .clipShape(Circle())
                        
                        Button(action: { timerManager.skipToNext() }) {
                            Image(systemName: "forward.fill")
                                .font(.title2)
                        }
                        .frame(width: 50, height: 50)
                        .foregroundColor(.primary)
                        
                        if currentIndex < timerManager.timers.count - 1 {
                            Button(action: { timerManager.autoPlayEnabled.toggle() }) {
                                Image(systemName: timerManager.autoPlayEnabled ? "repeat.circle.fill" : "repeat.circle")
                                    .font(.title2)
                            }
                            .frame(width: 50, height: 50)
                            .foregroundColor(timerManager.autoPlayEnabled ? .accentColor : .secondary)
                        }
                    } else if timerManager.isPaused {
                        Button(action: { timerManager.stopTimers() }) {
                            Image(systemName: "stop.fill")
                                .font(.title2)
                        }
                        .frame(width: 50, height: 50)
                        .foregroundColor(.primary)
                        
                        Button(action: { timerManager.resumeTimer() }) {
                            Image(systemName: "play.fill")
                                .font(.title)
                        }
                        .frame(width: 60, height: 60)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .clipShape(Circle())
                        
                        if currentIndex < timerManager.timers.count - 1 {
                            Button(action: { timerManager.autoPlayEnabled.toggle() }) {
                                Image(systemName: timerManager.autoPlayEnabled ? "repeat.circle.fill" : "repeat.circle")
                                    .font(.title2)
                            }
                            .frame(width: 50, height: 50)
                            .foregroundColor(timerManager.autoPlayEnabled ? .accentColor : .secondary)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemBackground))
    }
}

struct TimerListView: View {
    @Environment(TimerManager.self) private var timerManager
    @Environment(\.modelContext) private var modelContext
    @Binding var editingTimer: TimerItem?
    
    var body: some View {
        List {
            ForEach(Array(timerManager.timers.enumerated()), id: \.element.id) { index, timer in
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
                timerManager.moveTimer(from: source, to: destination)
                saveTimers()
            }
        }
        .listStyle(PlainListStyle())
    }
    
    private func deleteTimers(at offsets: IndexSet) {
        for index in offsets {
            let timer = timerManager.timers[index]
            if let savedTimer = modelContext.model(for: timer.id) as? TimerItem {
                modelContext.delete(savedTimer)
            }
            timerManager.deleteTimer(at: index)
        }
        saveTimers()
    }
    
    private func saveTimers() {
        for timer in timerManager.timers {
            modelContext.insert(timer)
        }
        try? modelContext.save()
    }
}

struct AddTimerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(TimerManager.self) private var timerManager
    @Environment(\.modelContext) private var modelContext
    
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
        let newTimer = TimerItem(name: name.isEmpty ? "Timer" : name, duration: duration, order: timerManager.timers.count)
        
        timerManager.timers.append(newTimer)
        modelContext.insert(newTimer)
        
        try? modelContext.save()
        dismiss()
    }
}

struct EditTimerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(TimerManager.self) private var timerManager
    @Environment(\.modelContext) private var modelContext
    
    let timer: TimerItem
    @State private var name: String = ""
    @State private var minutes: Int = 0
    @State private var seconds: Int = 0
    
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
            .navigationTitle("Edit Timer")
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
                    .disabled(name.isEmpty || (minutes == 0 && seconds == 0))
                }
            }
            .onAppear {
                name = timer.name
                let totalSeconds = Int(timer.duration)
                minutes = totalSeconds / 60
                seconds = totalSeconds % 60
            }
        }
    }
    
    private func saveChanges() {
        timer.name = name
        timer.duration = TimeInterval(minutes * 60 + seconds)
        
        if let index = timerManager.timers.firstIndex(where: { $0.id == timer.id }) {
            timerManager.timers[index] = timer
        }
        
        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    ContentView()
        .environment(TimerManager())
        .modelContainer(for: TimerItem.self, inMemory: true)
}
