//
//  TaskTracker.swift
//  PersonalAnalytics
//
//  Created by Chris Satterfield on 2020-05-25.
//

import Foundation

class TaskTracker: ITracker, IWindowsActivityListener {
    
    var name: String = "TaskTracker" // move to settings file later
    var timer: Timer?
    
    var isRunning: Bool = false
    
    var segmentStartTime: Date?
    var windowTitles: [String] = []
    var appNames: [String] = []
    var activeAppName: String?
    var activeWindowTitle: String?
    
    init(){
        if let activityTracker: WindowsActivityTracker = (TrackerManager.shared.getTracker(tracker: WindowsActivitySettings.Name) as! WindowsActivityTracker) {
            activityTracker.registerListener(listener: self)
            start()
        }
        else{
            print("Unable to register TaskTracker with WindowsActivityTracker")
            return
        }
    }
    
    func stop() {
        timer?.invalidate()
        isRunning = false
    }
    
    func start() {
        timer?.invalidate()
        segmentStartTime = Date()
        timer = Timer.scheduledTimer(timeInterval: 60.0, target: self, selector: #selector(captureTaskSegment), userInfo: nil, repeats: true)
        isRunning = true
    }
    
    func createDatabaseTablesIfNotExist() {
        TaskQueries.createDatabaseTablesIfNotExist()
    }
    
    func updateDatabaseTables(version: Int) {
        
    }
    
    @objc func captureTaskSegment(){
        TaskQueries.saveTaskSegment(tsStart: segmentStartTime!, tsEnd: Date(), windowTitles: windowTitles, appNames: appNames)
        segmentStartTime = Date()
        
        if(activeWindowTitle != nil){
            windowTitles = [activeWindowTitle!]
        }
        else{
            windowTitles = []
        }
        
        if(activeAppName != nil){
            appNames = [activeAppName!]
        }
        else{
            appNames = []
        }
    }
    
    func getVisualizationsDay(date: Date) -> [IVisualization]{
        print("getviz")
        return [DayTaskTimeline()]
    }
    
    func notifyWindowTitleChange(windowTitle: String) {
        windowTitles.append(windowTitle)
        activeWindowTitle = windowTitle
    }
    
    func notifyAppChange(appName: String) {
        appNames.append(appName)
        activeAppName = appName
    }
    
}

