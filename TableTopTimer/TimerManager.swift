//
//  TimerManager.swift
//  TableTopTimer
//
//  Created by Yuhao Chen on 6/20/25.
//

import Foundation
import SwiftUI
import SwiftData
import Combine
import AVFoundation

@Observable
class TimerManager {
    var timers: [TimerItem] = []
    var currentTimerIndex: Int?
    var timeRemaining: TimeInterval = 0
    var isRunning: Bool = false
    var isPaused: Bool = false
    var autoPlayEnabled: Bool = true
    
    private var timer: Timer?
    private var audioPlayer: AVAudioPlayer?
    private var automationManager = AutomationManager()
    var currentTimerItem: TimerItem? { didSet { } }  // Made public for AutomationManager
    
    func startTimers(fromIndex: Int = 0) {
        guard !timers.isEmpty else { return }
        
        if isPaused {
            resumeTimer()
        } else {
            currentTimerIndex = fromIndex
            startCurrentTimer()
        }
    }
    
    func pauseTimer() {
        timer?.invalidate()
        timer = nil
        isPaused = true
        isRunning = false
        
        // Pause automations
        automationManager.pauseAutomations()
    }
    
    func resumeTimer() {
        guard isPaused else { return }
        isPaused = false
        isRunning = true
        
        // Resume automations
        automationManager.resumeAutomations(timerManager: self)
        
        startCountdown()
    }
    
    func stopTimers() {
        timer?.invalidate()
        timer = nil
        currentTimerIndex = nil
        currentTimerItem = nil
        timeRemaining = 0
        isRunning = false
        isPaused = false
        
        // Stop all automations
        automationManager.stopAutomations()
    }
    
    func skipToNext() {
        guard let currentIndex = currentTimerIndex else { return }
        
        timer?.invalidate()
        timer = nil
        
        if currentIndex < timers.count - 1 {
            currentTimerIndex = currentIndex + 1
            startCurrentTimer()
        } else {
            stopTimers()
        }
    }
    
    private func startCurrentTimer() {
        guard let index = currentTimerIndex,
              index < timers.count else {
            stopTimers()
            return
        }
        
        let currentTimer = timers[index]
        currentTimerItem = currentTimer
        timeRemaining = currentTimer.duration
        isRunning = true
        isPaused = false
        
        // Notify automation manager
        automationManager.timerStarted(currentTimer, timerManager: self)
        
        startCountdown()
    }
    
    private func startCountdown() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            self.timeRemaining -= 0.1
            
            // Notify automation manager on each tick
            if let currentTimer = self.currentTimerItem {
                self.automationManager.timerTick(currentTimer, timeRemaining: self.timeRemaining, timerManager: self)
            }
            
            if self.timeRemaining <= 0 {
                self.timerCompleted()
            }
        }
    }
    
    private func timerCompleted() {
        timer?.invalidate()
        timer = nil
        
        // Notify automation manager before default sound
        if let currentTimer = currentTimerItem {
            automationManager.timerEnded(currentTimer, timerManager: self)
        }
        
        playNotificationSound()
        
        guard let currentIndex = currentTimerIndex else { return }
        
        if autoPlayEnabled && currentIndex < timers.count - 1 {
            currentTimerIndex = currentIndex + 1
            startCurrentTimer()
        } else {
            stopTimers()
        }
    }
    
    private func playNotificationSound() {
        AudioServicesPlaySystemSound(1005)
        
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()
    }
    
    func addTimer(name: String = "New Timer", duration: TimeInterval = 60) {
        let newTimer = TimerItem(name: name, duration: duration, order: timers.count)
        timers.append(newTimer)
    }
    
    func deleteTimer(at index: Int) {
        guard index < timers.count else { return }
        timers.remove(at: index)
        
        for i in index..<timers.count {
            timers[i].order = i
        }
    }
    
    func moveTimer(from source: IndexSet, to destination: Int) {
        timers.move(fromOffsets: source, toOffset: destination)
        
        for i in 0..<timers.count {
            timers[i].order = i
        }
    }
    
    func updateTimer(at index: Int, name: String? = nil, duration: TimeInterval? = nil) {
        guard index < timers.count else { return }
        
        if let name = name {
            timers[index].name = name
        }
        
        if let duration = duration {
            timers[index].duration = duration
        }
    }
    
    func formatTime(_ timeInterval: TimeInterval) -> String {
        let totalSeconds = Int(timeInterval)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    // MARK: - Automation Integration
    
    func setModelContext(_ context: ModelContext) {
        automationManager.setModelContext(context)
    }
    
    func notifyCounterChanged(_ counter: Counter, oldValue: Int, newValue: Int) {
        automationManager.counterChanged(counter, oldValue: oldValue, newValue: newValue, timerManager: self)
    }
}