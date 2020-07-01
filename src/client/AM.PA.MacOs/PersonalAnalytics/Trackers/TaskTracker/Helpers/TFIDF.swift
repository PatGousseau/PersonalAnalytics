//
//  TFIDF.swift
//  PersonalAnalytics
//
//  Created by Chris Satterfield on 2020-06-02.
//

import Foundation
import NaturalLanguage

// Takes a list of documents
// Produces TFIDF vectors based on documents
@available(OSX 10.14, *)
class TFIDF{
    
    private var documentTokenCounts : [[String : Int]] = []
    private var documentFrequency = [String:Int]()
    private var inverseDocumentFrequency = [String:Double]()
    private var wordList: [String] = []
    
    
    init(documents: [String]){
        for document in documents{
            documentTokenCounts.append(calculateTermFrequency(document))
        }
        calculateInverseDocumentFrequency()
        wordList = documentFrequency.keys.sorted()
    }
    
    private func calculateTermFrequency(_ document: String) -> [String:Int] {
        let tokenizer = NLTokenizer(unit: NLTokenUnit.word)
        tokenizer.string = document
        var tokenCounts = [String:Int]()
        tokenizer.enumerateTokens(in: document.startIndex..<document.endIndex) { tokenRange, _ in
            let token = String(document[tokenRange])
            tokenCounts[token, default: 0] += 1
            return true
        }
        return tokenCounts
    }
        
    private func calculateInverseDocumentFrequency(){
        for document in documentTokenCounts {
            for token in document.keys {
                documentFrequency[token, default: 0] += 1
            }
        }
        for token in documentFrequency.keys{
            inverseDocumentFrequency[token] = log2(Double(documentTokenCounts.count)/Double(documentFrequency[token]!))
        }
    }

    
    func vectorize(document: String) -> Vector {
        let termFrequency = calculateTermFrequency(document)
        var v: [Double] = []
        for token in wordList {
            if termFrequency[token] != nil {
                v.append(Double(termFrequency[token]!) * inverseDocumentFrequency[token]!)
            }
            else{
                v.append(0)
            }
        }
        return Vector(v, labels: wordList)
    }
    
}
