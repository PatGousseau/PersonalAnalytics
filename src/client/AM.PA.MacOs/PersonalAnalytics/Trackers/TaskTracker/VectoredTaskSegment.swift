//
//  VectoredTaskSegment.swift
//  PersonalAnalytics
//
//  Created by Chris Satterfield on 2020-06-15.
//

import Foundation

class VectoredTaskSegment: TaskSegment {
    var vector: Vector
    
    init(taskSegment: TaskSegment, vector: Vector){
        self.vector = vector
        super.init(start: taskSegment.startTime, end: taskSegment.endTime, windowTitles: taskSegment.windowTitles)
    }
    
    init(start: TimeInterval, end: TimeInterval, windowTitles: String, vector: Vector){
        self.vector = vector
        super.init(start: start, end: end, windowTitles: windowTitles)
    }
}
