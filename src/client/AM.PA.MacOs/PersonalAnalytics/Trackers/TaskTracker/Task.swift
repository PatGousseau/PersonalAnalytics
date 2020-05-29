//
//  Task.swift
//  PersonalAnalytics
//
//  Created by Chris Satterfield on 2020-05-25.
//

import Foundation

class Task{
    
    var startTime: TimeInterval
    var endTime: TimeInterval
    var duration: TimeInterval
    var name: String
    var taskId: String
    var URL: String?
    
    init(start: TimeInterval, end: TimeInterval, taskId: String, name: String, url: String? = nil){
        self.startTime = start
        self.endTime = end
        self.name = name
        self.taskId = taskId
        self.duration = endTime - startTime
        self.URL = url
    }
    
}
