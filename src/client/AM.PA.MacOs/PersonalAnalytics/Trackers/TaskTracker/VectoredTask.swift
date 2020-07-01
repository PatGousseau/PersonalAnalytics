//
//  VectoredTask.swift
//  PersonalAnalytics
//
//  Created by Chris Satterfield on 2020-06-16.
//

import Foundation

class VectoredTask {
    
    var vector: Vector
    var segments: [TaskSegment] = []
    
    init(_ taskSegment: VectoredTaskSegment){
        vector = taskSegment.vector
        segments.append(taskSegment)
    }
    
    func addSegment(_ taskSegment: VectoredTaskSegment){
        vector = vector + taskSegment.vector
        segments.append(taskSegment)
    }
}
