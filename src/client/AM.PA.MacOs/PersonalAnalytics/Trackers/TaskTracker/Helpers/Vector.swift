//
//  Vector.swift
//  PersonalAnalytics
//
//  Created by Chris Satterfield on 2020-06-02.
//

import Foundation
import PythonKit

class Vector {
    
    let scores: [String:Double]
    let pyScores: PythonObject
    static let Utility = Python.import("Utility")
    
    init(_ pyScores: PythonObject){
        self.pyScores = pyScores
        scores = Dictionary(pyScores)!
    }
    
    func size() -> Int {
        return scores.count
    }
    
    static func + (_ left: Vector, _ right: Vector) -> Vector {
        return Vector(Utility.add(left.pyScores, right.pyScores))
    }
        
    
    static func cosine(_ left: Vector, _ right: Vector) -> Double {
        if(left.size() == 0 || right.size() == 0){
            return 0
        }
        return Double(Utility.cosineSimilarity(left.pyScores.values(), right.pyScores.values()))!
    }
    
    static func average(_ vectors: [Vector]) -> Vector {
        let pyScoresList = vectors.map{$0.pyScores}
        return Vector(Utility.average(pyScoresList))
    }
}
