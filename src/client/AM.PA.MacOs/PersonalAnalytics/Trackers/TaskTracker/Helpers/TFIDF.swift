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
    
    
    init(documents: [String]){
        let tokenizer = NLTokenizer(unit: NLTokenUnit.word)
        for document in documents{
            tokenizer.string = document
            var tokenCounts = [String:Int]()
            tokenizer.enumerateTokens(in: document.startIndex..<document.endIndex) { tokenRange, _ in
                let token = String(document[tokenRange])
                tokenCounts[token, default: 0] += 1
                return true
            }
            documentTokenCounts.append(tokenCounts)
        }
        calculateInverseDocumentFrequency()
        print(documentTokenCounts)
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

    
    func vectorize(document: String){
        
    }
    
}
