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
    
    static func getEnvFileName(_ name: String) -> String {
        if Environment.env == "development" {
            return "dev-" + name
        }
        return name
    }
    
    static var ManualInterventionFile:String = getEnvFileName("manual-interventions.txt")
    static var InteractionLog:String = getEnvFileName("interaction-log.txt")
    static var AnonTokenFile:String = getEnvFileName("token-anonymous.txt")
    static var TokenSequenceFile:String = getEnvFileName("token-sequence.txt")
    static var EmbeddingsFile:String = getEnvFileName("embeddings.txt")
}
