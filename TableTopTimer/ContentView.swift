//
//  ContentView.swift
//  TableTopTimer
//
//  Created by Yuhao Chen on 6/20/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        TimerListsView()
    }
}

struct CurrentTimerSheet: View {
    @Environment(TimerManager.self) private var timerManager
    @Environment(\.modelContext) private var modelContext
    
    let timerList: TimerList
    
    @State private var showingAddTimer = false
    @State private var editingTimer: TimerItem?
    
    var body: some View {
        GeometryReader { geometry in
            let isCompact = geometry.size.height < 400
            
            if isCompact {
                CompactTimerView(timerList: timerList)
            } else {
                FullScreenTimerView(
                    timerList: timerList,
                    showingAddTimer: $showingAddTimer,
                    editingTimer: $editingTimer
                )
            }
        }
        .sheet(isPresented: $showingAddTimer) {
            AddTimerToListView(timerList: timerList)
        }
        .sheet(item: $editingTimer) { timer in
            EditTimerView(timer: timer)
        }
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

struct CompactTimerView: View {
    @Environment(TimerManager.self) private var timerManager
    
    let timerList: TimerList
    
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
                
                TimerControlsView(currentIndex: currentIndex)
                    .padding(.horizontal)
                    .padding(.bottom, 20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemBackground))
    }
}

struct FullScreenTimerView: View {
    @Environment(TimerManager.self) private var timerManager
    @Environment(\.modelContext) private var modelContext
    
    let timerList: TimerList
    @Binding var showingAddTimer: Bool
    @Binding var editingTimer: TimerItem?
    
    @State private var showingAddCounter = false
    @State private var editingCounter: Counter?
    
    var body: some View {
        VStack(spacing: 0) {
            if let currentIndex = timerManager.currentTimerIndex,
               currentIndex < timerManager.timers.count {
                let currentTimer = timerManager.timers[currentIndex]
                
                VStack(spacing: 16) {
                    Text(currentTimer.name)
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text(timerManager.formatTime(timerManager.timeRemaining))
                        .font(.system(size: 48, weight: .bold, design: .monospaced))
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
                    
                    TimerControlsView(currentIndex: currentIndex)
                }
                .padding(.top, 20)
                .padding(.bottom, 16)
                
                Divider()
                
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Counters")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        if !timerList.counters.isEmpty {
                            Button(action: { resetAllCounters() }) {
                                Image(systemName: "arrow.counterclockwise")
                            }
                        }
                        
                        Button(action: { showingAddCounter = true }) {
                            Image(systemName: "plus")
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    
                    if timerList.counters.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "plus.circle.dashed")
                                .font(.largeTitle)
                                .foregroundColor(.secondary)
                            
                            Text("No counters yet")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            Text("Tap + to add a counter for this game")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            
                            Button("Add Counter") {
                                showingAddCounter = true
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.horizontal, 40)
                    } else {
                        List {
                            ForEach(timerList.counters.sorted(by: { $0.order < $1.order })) { counter in
                                CounterRow(counter: counter, editingCounter: $editingCounter)
                            }
                            .onDelete(perform: deleteCounters)
                            .onMove(perform: moveCounters)
                        }
                        .listStyle(PlainListStyle())
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemBackground))
        .sheet(isPresented: $showingAddCounter) {
            AddCounterView(timerList: timerList)
        }
        .sheet(item: $editingCounter) { counter in
            EditCounterView(counter: counter)
        }
    }
    
    private func resetAllCounters() {
        for counter in timerList.counters {
            counter.reset()
        }
        try? modelContext.save()
    }
    
    private func deleteCounters(at offsets: IndexSet) {
        for index in offsets {
            let counter = timerList.counters.sorted(by: { $0.order < $1.order })[index]
            if let timerIndex = timerList.counters.firstIndex(where: { $0.id == counter.id }) {
                timerList.counters.remove(at: timerIndex)
            }
            modelContext.delete(counter)
        }
        updateCounterOrders()
        try? modelContext.save()
    }
    
    private func moveCounters(from source: IndexSet, to destination: Int) {
        var sortedCounters = timerList.counters.sorted(by: { $0.order < $1.order })
        sortedCounters.move(fromOffsets: source, toOffset: destination)
        
        for (index, counter) in sortedCounters.enumerated() {
            counter.order = index
        }
        
        try? modelContext.save()
    }
    
    private func updateCounterOrders() {
        let sortedCounters = timerList.counters.sorted(by: { $0.order < $1.order })
        for (index, counter) in sortedCounters.enumerated() {
            counter.order = index
        }
    }
}

struct CounterRow: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(TimerManager.self) private var timerManager
    let counter: Counter
    @Binding var editingCounter: Counter?
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(counter.name)
                    .font(.body)
                
                if let min = counter.minValue, let max = counter.maxValue {
                    Text("Range: \(min) - \(max)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else if let min = counter.minValue {
                    Text("Min: \(min)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else if let max = counter.maxValue {
                    Text("Max: \(max)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                editingCounter = counter
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                Button(action: {
                    let oldValue = counter.value
                    counter.decrement()
                    timerManager.notifyCounterChanged(counter, oldValue: oldValue, newValue: counter.value)
                    try? modelContext.save()
                }) {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundColor(counter.canDecrement ? .red : .gray)
                }
                .disabled(!counter.canDecrement)
                .buttonStyle(PlainButtonStyle())
                
                Text("\(counter.value)")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .frame(minWidth: 40)
                    .monospacedDigit()
                
                Button(action: {
                    let oldValue = counter.value
                    counter.increment()
                    timerManager.notifyCounterChanged(counter, oldValue: oldValue, newValue: counter.value)
                    try? modelContext.save()
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(counter.canIncrement ? .green : .gray)
                }
                .disabled(!counter.canIncrement)
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}

struct TimerControlsView: View {
    @Environment(TimerManager.self) private var timerManager
    
    let currentIndex: Int
    
    var body: some View {
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
                .background(Color.red.opacity(0.2))
                .foregroundColor(.red)
                .clipShape(Circle())
                
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
    }
}


#Preview {
    ContentView()
        .environment(TimerManager())
        .modelContainer(for: TimerItem.self, inMemory: true)
}
