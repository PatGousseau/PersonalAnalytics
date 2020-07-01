//
//  Vector.swift
//  PersonalAnalytics
//
//  Created by Chris Satterfield on 2020-06-02.
//

import Foundation

class Vector {
    
    var labels: [String]?
    private var entries: [Double]
    
    init(_ entries: [Double], labels: [String]? = nil){
        self.entries = entries
        if(labels != nil){
            assert(entries.count == labels!.count, "Error: vector dimensions do not match label dimensions")
        }
        self.labels = labels
    }
    
    func size() -> Int {
        return entries.count
    }
    
    func get(_ index: Int) -> Double {
        assert(index < entries.count && index >= 0, "Error: Index out of bounds")
        return entries[index]
    }
    
    func magnitude() -> Double {
        var sum: Double = 0
        for i in 0..<self.size() {
            let x = self.get(i)
            sum += x * x
        }
        return sum.squareRoot()
    }
    
    func print(){
        
    }
    
    static func + (_ left: Vector, _ right: Vector) -> Vector {
        var result : [Double] = []
        assert(left.size() == right.size(), "Error: vector dimensions must match")
        for i in 0..<left.size() {
            result.append(left.get(i) + right.get(i))
        }
        return Vector(result, labels: left.labels)
    }
    
    static func / (_ left: Vector, _ right: Double) -> Vector {
        var result: [Double] = []
        for i in 0..<left.size() {
            result.append(left.get(i) / right)
        }
        return Vector(result, labels: left.labels)
    }

    static func zeros(size: Int, labels: [String]? = nil) -> Vector {
        if(labels != nil){
            assert(size == labels!.count, "Error: vector dimensions do not match label dimensions")
        }
        return Vector(Array(repeating: 0, count: size), labels: labels)
    }
    
    static func dot(_ left: Vector, _ right: Vector) -> Double {
        var product: Double = 0
        assert(left.size() == right.size(), "Error: vector dimensions must match")
        for i in 0..<left.size() {
            product += left.get(i) * right.get(i)
        }
        return product
    }
    
    static func cosine(_ left: Vector, _ right: Vector) -> Double {
        assert(left.size() == right.size(), "Error: vector dimensions must match")
        let cos = dot(left, right)/(left.magnitude() * right.magnitude())
        if(cos.isNaN){
            return 0
        }
        else{
            return cos
        }
    }
    
    static func average(_ vectors: [Vector]) -> Vector {
        assert(vectors.count > 0, "Error: cannot average empty array")
        var sum = zeros(size: vectors[0].size(), labels: vectors[0].labels)
        for v in vectors {
            sum = sum + v
        }
        return sum/Double(vectors.count)
    }
}
