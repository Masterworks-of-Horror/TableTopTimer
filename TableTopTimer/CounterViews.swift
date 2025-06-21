//
//  CounterViews.swift
//  TableTopTimer
//
//  Created by Yuhao Chen on 6/21/25.
//

import SwiftUI
import SwiftData

struct CounterGridView: View {
    @Environment(\.modelContext) private var modelContext
    let timerList: TimerList
    
    @State private var showingAddCounter = false
    @State private var editingCounter: Counter?
    
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Counters")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if !timerList.counters.isEmpty {
                    Button("Reset All") {
                        resetAllCounters()
                    }
                    .font(.caption)
                    .foregroundColor(.orange)
                }
                
                Button(action: { showingAddCounter = true }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.accentColor)
                }
            }
            
            if timerList.counters.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "plus.circle.dashed")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    
                    Text("No counters yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("Tap + to add a counter")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(timerList.counters.sorted(by: { $0.order < $1.order })) { counter in
                        CounterCardView(counter: counter)
                            .onTapGesture {
                                editingCounter = counter
                            }
                    }
                }
            }
        }
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
}

struct CounterCardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(TimerManager.self) private var timerManager
    let counter: Counter
    
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
        .padding(.vertical, 8)
        .contextMenu {
            Button {
                counter.reset()
                try? modelContext.save()
            } label: {
                Label("Reset", systemImage: "arrow.counterclockwise")
            }
            
            Button(role: .destructive) {
                deleteCounter()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
    
    private func deleteCounter() {
        counter.list?.counters.removeAll { $0.id == counter.id }
        modelContext.delete(counter)
        try? modelContext.save()
    }
}

struct AddCounterView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let timerList: TimerList
    
    @State private var name = ""
    @State private var initialValue = 0
    @State private var hasMinValue = false
    @State private var minValue = 0
    @State private var hasMaxValue = false
    @State private var maxValue = 10
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Counter Name") {
                    TextField("Enter counter name", text: $name)
                }
                
                Section("Initial Value") {
                    Stepper("\(initialValue)", value: $initialValue, in: -999...999)
                }
                
                Section("Limits") {
                    Toggle("Minimum Value", isOn: $hasMinValue)
                    if hasMinValue {
                        Stepper("Min: \(minValue)", value: $minValue, in: -999...999)
                    }
                    
                    Toggle("Maximum Value", isOn: $hasMaxValue)
                    if hasMaxValue {
                        Stepper("Max: \(maxValue)", value: $maxValue, in: -999...999)
                    }
                }
            }
            .navigationTitle("New Counter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        addCounter()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
    
    private func addCounter() {
        let newCounter = Counter(
            name: name,
            initialValue: initialValue,
            minValue: hasMinValue ? minValue : nil,
            maxValue: hasMaxValue ? maxValue : nil,
            order: timerList.counters.count
        )
        
        newCounter.list = timerList
        timerList.counters.append(newCounter)
        modelContext.insert(newCounter)
        
        try? modelContext.save()
        dismiss()
    }
}

struct EditCounterView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let counter: Counter
    
    @State private var name: String = ""
    @State private var initialValue: Int = 0
    @State private var hasMinValue: Bool = false
    @State private var minValue: Int = 0
    @State private var hasMaxValue: Bool = false
    @State private var maxValue: Int = 10
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Counter Name") {
                    TextField("Enter counter name", text: $name)
                }
                
                Section("Initial Value") {
                    Stepper("\(initialValue)", value: $initialValue, in: -999...999)
                }
                
                Section("Current Value") {
                    HStack {
                        Text("Current: \(counter.value)")
                        Spacer()
                        Button("Reset to Initial") {
                            counter.value = initialValue
                        }
                        .font(.caption)
                    }
                }
                
                Section("Limits") {
                    Toggle("Minimum Value", isOn: $hasMinValue)
                    if hasMinValue {
                        Stepper("Min: \(minValue)", value: $minValue, in: -999...999)
                    }
                    
                    Toggle("Maximum Value", isOn: $hasMaxValue)
                    if hasMaxValue {
                        Stepper("Max: \(maxValue)", value: $maxValue, in: -999...999)
                    }
                }
            }
            .navigationTitle("Edit Counter")
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
                name = counter.name
                initialValue = counter.initialValue
                hasMinValue = counter.minValue != nil
                minValue = counter.minValue ?? 0
                hasMaxValue = counter.maxValue != nil
                maxValue = counter.maxValue ?? 10
            }
        }
    }
    
    private func saveChanges() {
        counter.name = name
        counter.initialValue = initialValue
        counter.minValue = hasMinValue ? minValue : nil
        counter.maxValue = hasMaxValue ? maxValue : nil
        
        try? modelContext.save()
        dismiss()
    }
}