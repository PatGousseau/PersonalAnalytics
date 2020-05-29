//
//  Vector.swift
//  PersonalAnalytics
//
//  Created by Chris Satterfield on 2020-06-02.
//

import Foundation

class Vector {
    
    private var entries: [Double]
    
    init(_ entries: [Double]){
        self.entries = entries
    }
    
    func size() -> Int {
        return entries.count
    }
    
    func get(_ index: Int) -> Double {
        assert(index < entries.count && index >= 0, "Error: Index out of bounds")
        return entries[index]
    }
    
    static func + (left: Vector, right: Vector) -> Vector {
        var result : [Double] = []
        assert(left.size() == right.size(), "Error: vector dimensions must match")
        for i in 0...left.size() {
            result.append(left.get(i) + right.get(i))
        }
        return Vector(result)
    }
    
}
