//
//  TaskTracker.swift
//  PersonalAnalytics
//
//  Created by Chris Satterfield on 2020-05-25.
//

import Foundation

class TaskTracker: ITracker, IWindowsActivityListener {
    var name: String = TaskSettings.Name
    
    
    var timer: Timer?
    
    var isRunning: Bool = false
    
    var segmentStartTime: Date?
    var windowTitles: [String] = []
    var appNames: [String] = []
    var times: [Double] = []
    var activeAppName: String?
    var activeWindowTitle: String?
    var isIdle = false
        
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
        timer = Timer.scheduledTimer(timeInterval: 180.0, target: self, selector: #selector(captureTaskSegment), userInfo: nil, repeats: true)
        isRunning = true
    }
    
    func createDatabaseTablesIfNotExist() {
        TaskQueries.createDatabaseTablesIfNotExist()
    }
    
    func updateDatabaseTables(version: Int) {
        
    }
    
    func calculateWindowTitleDurations(times: [Double]) -> [Double] {
        var durations: [Double] = []
        var d : Double = 0
        times.forEach({
            durations.append($0 - d)
            d = $0
        })
        return durations
    }
    
    func filterCurrentTaskSegment() -> [String] {
        let durations = calculateWindowTitleDurations(times: times)
        var filteredTitles: [String] = []
        for (title, duration) in zip(windowTitles, durations){
            if(duration >= 5){
                filteredTitles.append(title)
            }
        }
        return filteredTitles
    }
    
    @objc func captureTaskSegment(){
        if(!isIdle){
            if activeWindowTitle != nil{
                self.notifyWindowTitleChange(windowTitle: activeWindowTitle!)
            }
            if(activeAppName != nil){
                self.notifyAppChange(appName: activeAppName!)
            }
            
            let titles = filterCurrentTaskSegment()
            TaskQueries.saveTaskSegment(tsStart: segmentStartTime!, tsEnd: Date(), windowTitles: titles, appNames: appNames)
        }
        segmentStartTime = Date()
        windowTitles = []
        times = []
    }
    
    func getVisualizationsDay(date: Date) -> [IVisualization]{
        return [DayTaskTimeline()]
    }
    
    func notifyWindowTitleChange(windowTitle: String) {
        if activeWindowTitle != nil {
            windowTitles.append(activeWindowTitle!)
            times.append(Date().timeIntervalSinceReferenceDate - segmentStartTime!.timeIntervalSinceReferenceDate)
        }
        else{
            windowTitles.append("")
            times.append(Date().timeIntervalSinceReferenceDate - segmentStartTime!.timeIntervalSinceReferenceDate)
        }
        activeWindowTitle = windowTitle
    }
    
    func notifyAppChange(appName: String) {
        if(activeAppName != nil){
            appNames.append(activeAppName!)
        }
        else{
            appNames.append("")
            times.append(Date().timeIntervalSinceReferenceDate - segmentStartTime!.timeIntervalSinceReferenceDate)
        }
        activeAppName = appName
    }
    
    func notifyIdle(){
        isIdle = true
    }
    
    func notifyResumed(){
        isIdle = false
    }
}

