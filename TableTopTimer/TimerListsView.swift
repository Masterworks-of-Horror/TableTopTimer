//
//  TimerListsView.swift
//  TableTopTimer
//
//  Created by Yuhao Chen on 6/21/25.
//

import SwiftUI
import SwiftData

struct TimerListsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TimerList.createdAt) private var timerLists: [TimerList]
    
    @State private var showingAddList = false
    @State private var editingList: TimerList?
    
    var body: some View {
        NavigationStack {
            VStack {
                if timerLists.isEmpty {
                    ContentUnavailableView {
                        Label("No Timer Lists", systemImage: "list.bullet.rectangle")
                    } description: {
                        Text("Create a timer list to get started")
                    } actions: {
                        Button("Create Timer List") {
                            showingAddList = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        ForEach(timerLists) { list in
                            NavigationLink(destination: TimerListDetailView(timerList: list)) {
                                TimerListRow(timerList: list)
                            }
                            .contextMenu {
                                Button {
                                    editingList = list
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                
                                Button(role: .destructive) {
                                    deleteList(list)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                        .onDelete(perform: deleteLists)
                    }
                }
            }
            .navigationTitle("Timer Lists")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddList = true }) {
                        Label("Add List", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddList) {
                AddTimerListView()
            }
            .sheet(item: $editingList) { list in
                EditTimerListView(timerList: list)
            }
        }
    }
    
    private func deleteLists(at offsets: IndexSet) {
        for index in offsets {
            let list = timerLists[index]
            modelContext.delete(list)
        }
        try? modelContext.save()
    }
    
    private func deleteList(_ list: TimerList) {
        modelContext.delete(list)
        try? modelContext.save()
    }
}

struct TimerListRow: View {
    let timerList: TimerList
    
    var body: some View {
        HStack {
            Circle()
                .fill(timerList.color)
                .frame(width: 10, height: 10)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(timerList.name)
                    .font(.headline)
                
                HStack(spacing: 8) {
                    Text("\(timerList.timers.count) timers")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let lastUsed = timerList.lastUsedAt {
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(lastUsed.formatted(.relative(presentation: .named)))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            if !timerList.timers.isEmpty {
                Text(totalDurationText)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var totalDurationText: String {
        let totalSeconds = timerList.timers.reduce(0) { $0 + $1.duration }
        let minutes = Int(totalSeconds) / 60
        let seconds = Int(totalSeconds) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct AddTimerListView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var name = ""
    @State private var selectedColor = Color.accentColor
    
    let colors: [Color] = [
        .blue, .green, .orange, .red, .purple,
        .pink, .yellow, .cyan, .indigo, .mint
    ]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("List Name") {
                    TextField("Enter list name", text: $name)
                }
                
                Section("Color") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(colors, id: \.self) { color in
                                Circle()
                                    .fill(color)
                                    .frame(width: 44, height: 44)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.primary, lineWidth: selectedColor == color ? 3 : 0)
                                    )
                                    .onTapGesture {
                                        selectedColor = color
                                    }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            .navigationTitle("New Timer List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createList()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
    
    private func createList() {
        let newList = TimerList(name: name, colorHex: selectedColor.hexString)
        modelContext.insert(newList)
        try? modelContext.save()
        dismiss()
    }
}

struct EditTimerListView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let timerList: TimerList
    @State private var name: String = ""
    @State private var selectedColor: Color = .accentColor
    
    let colors: [Color] = [
        .blue, .green, .orange, .red, .purple,
        .pink, .yellow, .cyan, .indigo, .mint
    ]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("List Name") {
                    TextField("Enter list name", text: $name)
                }
                
                Section("Color") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(colors, id: \.self) { color in
                                Circle()
                                    .fill(color)
                                    .frame(width: 44, height: 44)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.primary, lineWidth: selectedColor == color ? 3 : 0)
                                    )
                                    .onTapGesture {
                                        selectedColor = color
                                    }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            .navigationTitle("Edit Timer List")
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
                name = timerList.name
                selectedColor = timerList.color
            }
        }
    }
    
    private func saveChanges() {
        timerList.name = name
        timerList.colorHex = selectedColor.hexString
        try? modelContext.save()
        dismiss()
    }
}