//
//  TaskSettings.swift
//  PersonalAnalytics
//
//  Created by Chris Satterfield on 2020-06-01.
//

import Foundation

enum TaskSettings{
    static let Name = "TaskTracker"
    static let DbTable = "task_segment_activity"
    static let MinDuration: Double = 5
    static let TaskSegmentSimilarityThreshold = 0.5
}
