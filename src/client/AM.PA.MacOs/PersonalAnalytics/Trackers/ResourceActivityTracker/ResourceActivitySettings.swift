//
//  ResourceActivitySettings.swift
//  PersonalAnalytics
//
//  Created by Roy Rutishauser on 04.02.20.
//

import Foundation


enum ResourceActivitySettings {
    static let DbTableActivity = "resource_activity"
    static let DbTableApplicationResource = "resource_application"
    static let Name = "ResourceActivityTracker"
    static let SimilarityTreshold:Float = 0.6
    static let WindowSize = 3
    static let RefreshRate = 5.0 * 60.0 // 5min
    
    static let ManualInterventionFile = "manual-interventions.txt"
    static let InteractionLog = "interaction-log.txt"
    static let TokenFile = "token.txt"
    static let AnonTokenFile = "token-anonymous.txt"
    static let TokenSequenceFile = "token-sequence.txt"
    static let EmbeddingsFile = "embeddings.txt"
}
