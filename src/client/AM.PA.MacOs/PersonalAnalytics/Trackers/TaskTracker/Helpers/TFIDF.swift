//
//  TFIDF.swift
//  PersonalAnalytics
//
//  Created by Chris Satterfield on 2020-06-02.
//

import Foundation
import PythonKit

// Takes a list of documents
// Produces TFIDF vectors based on documents
class TFIDF{
    
    let model: PythonObject?
    let TfIdf: PythonObject
    
    init(documents: [String]){
        
        let pathToPythonHome = Bundle.main.path(forResource: "Python", ofType: "")!
        let pathToPythonLib = Bundle.main.path(forResource: "Python/lib/libpython3.8", ofType: "dylib")!
        let pathToScriptsFolder = Bundle.main.path(forResource: "Python/scripts", ofType: "")!
        
        setenv("PYTHON_LIBRARY", pathToPythonLib, 1)
        setenv("PYTHONHOME", pathToPythonHome, 1)
        
        let sys = Python.import("sys")
        sys.path.append(pathToScriptsFolder)
        
        TfIdf = Python.import("TFIDF")
        model = TfIdf.fit(documents)
    }
    
    func vectorize(document: String) -> Vector {
            return Vector(TfIdf.transform(model!, document))
    }
    
}
