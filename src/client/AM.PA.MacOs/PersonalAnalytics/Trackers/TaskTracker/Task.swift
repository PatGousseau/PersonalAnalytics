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
    var words: [String:Double]
    var name: String
    var taskId: String
    
    init(start: TimeInterval, end: TimeInterval, taskId: String, name: String, words: [String:Double]){
        self.startTime = start
        self.endTime = end
        self.duration = end - start
        self.name = name
        self.taskId = taskId
        self.words = words
    }
    
}
