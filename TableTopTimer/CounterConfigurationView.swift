//
//  CounterConfigurationView.swift
//  TableTopTimer
//
//  Created by Yuhao Chen on 6/21/25.
//

import SwiftUI
import SwiftData

struct CounterConfigurationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let timerList: TimerList
    
    @State private var showingAddCounter = false
    @State private var editingCounter: Counter?
    
    var body: some View {
        NavigationStack {
            VStack {
                if timerList.counters.isEmpty {
                    ContentUnavailableView {
                        Label("No Counters", systemImage: "number.circle")
                    } description: {
                        Text("Add counters for this timer list")
                    } actions: {
                        Button("Add Counter") {
                            showingAddCounter = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        ForEach(timerList.counters.sorted(by: { $0.order < $1.order })) { counter in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(counter.name)
                                        .font(.headline)
                                    
                                    HStack(spacing: 8) {
                                        Text("Initial: \(counter.initialValue)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        
                                        if let min = counter.minValue {
                                            Text("Min: \(min)")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        if let max = counter.maxValue {
                                            Text("Max: \(max)")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                                
                                Spacer()
                                
                                Text("\(counter.value)")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.accentColor)
                                    .monospacedDigit()
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                editingCounter = counter
                            }
                        }
                        .onDelete(perform: deleteCounters)
                        .onMove(perform: moveCounters)
                    }
                }
            }
            .navigationTitle("Counter Configuration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    if !timerList.counters.isEmpty {
                        Button(action: { resetAllCounters() }) {
                            Image(systemName: "arrow.counterclockwise")
                        }
                    }
                    
                    Button(action: { showingAddCounter = true }) {
                        Image(systemName: "plus")
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
    
    private func resetAllCounters() {
        for counter in timerList.counters {
            counter.reset()
        }
        try? modelContext.save()
    }
}