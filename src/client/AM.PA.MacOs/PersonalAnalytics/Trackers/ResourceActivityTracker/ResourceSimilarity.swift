//
//  ResourceSimilarity.swift
//  PersonalAnalytics
//
//  Created by Roy Rutishauser on 21.07.20.
//

import Foundation

class Similarity {
    
    static func calc(vector a: [Float], other b: [Float]) -> Float {
        return dotProduct(vector: a, other: b) / (vecMagnitude(vector: a) * vecMagnitude(vector: b))
    }
    
    static private func dotProduct(vector a: [Float], other b: [Float]) -> Float {
        if a.count != b.count {
            //TODO: should we throw here?
            return 0
        }
        var sum = Float(0)
        for i in 0...a.count-1 {
            sum += a[i] * b[i]
        }
        return sum
    }
    
    static private func vecMagnitude(vector a: [Float]) -> Float {
        var sum = Float(0)
        for elem in a {
            sum += pow(elem, 2)
        }
        return sqrt(sum)
    }
}
