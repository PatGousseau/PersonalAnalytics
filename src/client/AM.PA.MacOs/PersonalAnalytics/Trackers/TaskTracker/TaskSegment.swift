//
//  TaskSegment.swift
//  PersonalAnalytics
//
//  Created by Chris Satterfield on 2020-06-15.
//

import Foundation

class TaskSegment{
    var startTime: TimeInterval
    var endTime: TimeInterval
    var duration: TimeInterval
    var windowTitles: String
    
    init(start: TimeInterval, end: TimeInterval, windowTitles: String){
        self.startTime = start
        self.endTime = end
        self.windowTitles = windowTitles
        self.duration = endTime - startTime
    }
}
