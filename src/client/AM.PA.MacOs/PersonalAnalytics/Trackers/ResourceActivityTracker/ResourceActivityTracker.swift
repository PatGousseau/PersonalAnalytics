//
//  ResourceActivityTracker.swift
//  PersonalAnalytics
//
//  Created by Roy Rutishauser on 04.02.20.
//

import Foundation
import CoreGraphics
import Quartz


// TODO:
// better design of window and buttons
// extract mathy stuff
// filenames (embeddings.txt, anonymous-tokens.txt, ... in settings)
// error handling --> CSVError
// loading new website should trigger app or resource change
// design for when no resource is available
// how to open window
// onAppChange, filter dissimilar resources, stick📍 similar resources


enum CSVError: Error {
    case parseError(String)
}

enum Intervention: Equatable {
    case similar
    case dissimilar
}

class ResourceActivityTracker: ITracker, ResourceControllerDelegate {
    
    var name = ResourceActivitySettings.Name
    var isRunning = true
    var windowContoller = ResourceWindowController(windowNibName: NSNib.Name(rawValue: "ResourceWindow"))
    var tokenMap = [String: Int]() // www.google.com : 2
    var invTokenMap = [Int: String]() // 2 : www.google.com
    var chunkMap = [String: String]() // pathChunk : randomStr
    var interventionMap = [Set<Int>: Intervention]()  // {token1, token2}: 0 (dissim)
    var embeddings: [[Float]]?
    
    
    lazy var supportDir: URL = {
        let urls = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appSupportURL = urls[urls.count - 1]
        return appSupportURL.appendingPathComponent(Environment.appSupportDir)
    }()
    
    init() {
        NotificationCenter.default.addObserver(self, selector: #selector(self.onActiveApplicationChange(_:)), name: NSNotification.Name(rawValue: "activeApplicationChange"), object: nil)
        
        trackFSEvents()
        
        windowContoller.showWindow(self)
        windowContoller.delegate = self
        
        do {
            try readManualInterventions()
            embeddings = try readEmbeddingsFromDisk()
            // try readTokenMaps() TODO there's a bug
            try writeTokenMapsFromSQLite()
        }
        catch CSVError.parseError(let msg) {
            print("Error:", msg)
        }
        catch let error as NSError {
            print("Failed to read file")
            print(error)
        }
    }
        
    private func readManualInterventions() throws {
        let fileURL = supportDir.appendingPathComponent("manual-interventions").appendingPathExtension("txt")
        
        if FileManager.default.fileExists(atPath: fileURL.path) {
            
            let data = try String(contentsOf: fileURL)
            let rows = data.components(separatedBy: "\n")
            for row in rows {
                if row.isEmpty {
                    continue;
                }
                let splitted = row.split(separator: ",")
                let i = splitted[0].trimmingCharacters(in: .whitespaces)
                let t1 = Int(splitted[1].trimmingCharacters(in: .whitespaces))!
                let t2 = Int(splitted[2].trimmingCharacters(in: .whitespaces))!
                let set:Set = [t1, t2]
                var intervention: Intervention
                if i == "dissim" {
                    intervention = .dissimilar
                } else if i == "sim" {
                    intervention = .similar
                } else {
                    throw CSVError.parseError("unknown intervention")
                }
                interventionMap[set] = intervention
            }
        }
    }

    internal func handleIntervention(activeResource: String, associatedResource: String, type: Intervention) {
        
        do {
            let activeToken = tokenMap[activeResource]!
            let associatedToken = tokenMap[associatedResource]!
            let set: Set = [activeToken, associatedToken]
            
            if let interventionType = interventionMap[set] {
                if type == interventionType {
                    throw CSVError.parseError("intervention already exists")
                }
                else {
                    throw CSVError.parseError("conflicting interventions")
                }
            } else {
                interventionMap[set] = type
                try writeManualInterventions()
            }
        }  catch CSVError.parseError(let msg) {
            print(msg)
        }
        catch let error as NSError {
            print("Failed to read file")
            print(error)
        }
        
    }
    
    private func writeManualInterventions() throws {
        let fileURL = supportDir.appendingPathComponent("manual-interventions").appendingPathExtension("txt")
        
        var str = ""
        for (resourceSet, type) in interventionMap {
            // produces ",/test.txt,google.com"
            let resources = resourceSet.reduce("", { s, r in s + "," + String(r) })
            
            switch type {
                case .similar:
                    str += "sim" + resources + "\n"
                case .dissimilar:
                    str += "dissim" + resources + "\n"
            }
        }
                           
        try str.write(to: fileURL, atomically: true, encoding: String.Encoding.utf8)
    }

    private func writeTokenMapsFromSQLite() throws {
        let dbController = DatabaseController.getDatabaseController()
        let rows = try dbController.executeFetchAll(query: "SELECT path FROM resource_application")
        
        var anonTokenMap = [String:Int]()
        var seq = ""
        
        for row in rows {
            let path = String(row["path"]!)
            
            if path == "" { continue }
            
            if let token = tokenMap[path] {
                seq += String(token) + ","
            } else {
                let token = tokenMap.count
                invTokenMap[token] = path
                tokenMap[path] = token
                seq += String(token) + ","
            }
        }
        
        for (path, token) in tokenMap {
            let anonPath = anonymizePath(path: path)
            anonTokenMap[anonPath] = token
        }
        
        do {
            let sequenceURL = supportDir.appendingPathComponent("tokensequence").appendingPathExtension("txt")
            let tokensURL = supportDir.appendingPathComponent("tokens").appendingPathExtension("txt")
            let anonTokensURL = supportDir.appendingPathComponent("anonymous-tokens").appendingPathExtension("txt")
            
            let tokens = [String](tokenMap.map { return String($1) + "," + $0 })
            let anonTokens = [String](anonTokenMap.map { return String($1) + "," + $0 })
            try seq.write(to: sequenceURL, atomically: true, encoding: String.Encoding.utf8)
            try tokens.joined(separator: "\n").write(to: tokensURL, atomically: true, encoding: String.Encoding.utf8)
            try anonTokens.joined(separator: "\n").write(to: anonTokensURL, atomically: true, encoding: String.Encoding.utf8)
        } catch let error as NSError {
            print(error)
        }
    }

    private func anonymizePath(path: String) -> String {
        let chunks = path.components(separatedBy: CharacterSet(charactersIn: "/:.-_&?"))
        var anonymousPath = ""

        for chunk in chunks {
            if chunkMap[chunk] == nil {
                chunkMap[chunk] = randomString(length: 4)
            }
            anonymousPath += chunkMap[chunk]!
        }
        return anonymousPath
    }
      
    private func randomString(length: Int) -> String {
      let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
      return String((0..<length).map{ _ in letters.randomElement()! })
    }

    private func readTokenMaps() throws  {
        let fileURL = supportDir.appendingPathComponent("tokens").appendingPathExtension("txt")
        let fileManager = FileManager.default
        
        if fileManager.fileExists(atPath: fileURL.path) {
           
            let data = try String(contentsOf: fileURL)
            let rows = data.components(separatedBy: "\n")
            for row in rows {
                let splitted = row.split(separator: ",")
                let token = Int(splitted[0].trimmingCharacters(in: .whitespaces))!
                let path = splitted[1].trimmingCharacters(in: .whitespaces)
                tokenMap[path] = token
                invTokenMap[token] = path
            }
            
            print(tokenMap.count, invTokenMap.count)
        }
    }
    
    private func readEmbeddingsFromDisk() throws -> [[Float]]? {
        let fileURL = supportDir.appendingPathComponent("embeddings").appendingPathExtension("txt")
        
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            print("embeddings.txt is missing")
            return nil
        }
                
        let data = try String(contentsOf: fileURL)
        var embeddings: [[Float]] = []
        let rows = data.components(separatedBy: "\n")
        for row in rows {
            if row.isEmpty { continue }
            let columns = row.components(separatedBy: ",")
            var floatColumns: [Float] = []
            for cell in columns {
                if let float = Float(cell.trimmingCharacters(in: .whitespaces)) {
                    floatColumns.append(float)
                } else {
                    throw CSVError.parseError("cannot cast embedding to float")
                }
            }
            embeddings.append(floatColumns)
        }
        
        return embeddings
    }
    
    private func getSimilarResourcePaths(to path: String) -> [String]? {
        if let token = tokenMap[path] {
            if let embeddings = self.embeddings {
                if token >= embeddings.count {
                    // no embedding learnt for recently indexed resource
                    return nil
                }
                let activeEmbedding = embeddings[token]
                var similarResources = [String]()
                for (i, embedding) in embeddings.enumerated() {
                    if i == token { continue }                  
                    let thresh = ResourceActivitySettings.SimilarityTreshold
                    if getSim(vector: embedding, other: activeEmbedding) > thresh {
                        if let path = invTokenMap[i] {
                            similarResources.append(path)
                        }
                        else {
                            print("no path for token", i)
                            print(tokenMap.values.filter { $0 == i } )
                            // TODO
                            assert(false)
                        }
                    }
                }
                return similarResources
            }
        }
        
        return nil
    }
    
    private func getSim(vector a: [Float], other b: [Float]) -> Float {
        return dotProduct(vector: a, other: b) / (vecMagnitude(vector: a) * vecMagnitude(vector: b))
    }
    
    private func dotProduct(vector a: [Float], other b: [Float]) -> Float {
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
    
    private func vecMagnitude(vector a: [Float]) -> Float {
        var sum = Float(0)
        for elem in a {
            sum += pow(elem, 2)
        }
        return sqrt(sum)
    }
    
    func stop() {
        isRunning = false
        EonilFSEvents.stopWatching(for: ObjectIdentifier(self))
    }
    
    func start() {
        isRunning = true
        trackFSEvents()
    }
    
    func createDatabaseTablesIfNotExist() {
        ResourceActivityQueries.createDatabaseTablesIfNotExist()
    }
    
    func updateDatabaseTables(version: Int) {}
    
    private func trackFSEvents() {
        
        // https://github.com/eonil/FSEvents
        try? EonilFSEvents.startWatching(
            paths: [NSHomeDirectory()],
            for: ObjectIdentifier(self),
            with: { event in
                
                let flags = event.flag!
                                
                // not interested in caches, logs and other system related stuff
                if event.path.contains("Library/") {
                    return
                }
                
                // only interested in files, not in symlinks or directories
                if !flags.contains(EonilFSEventsEventFlags.itemIsFile) {
                    return
                }
                
                // not quite sure if we need to filter this
                if flags.contains(EonilFSEventsEventFlags.itemChangeOwner) {
                    return
                }
            
                // 27.4.2020 - this is only for debugging
                // if event.path.contains("roy/Desktop") {
                //    let attr = try? FileManager.default.attributesOfItem(atPath: event.path)
                //    print(event.path)
                //    print(attr)
                //    print(flags)
                //    print("###")
                // }
                                
                do {
                    // this throws if the file still no longer exists at this point.
                    // It might have already been deleted by the system...
                    let attr = try FileManager.default.attributesOfItem(atPath: event.path)
                    ResourceActivityQueries.saveResourceActivity(date: attr[FileAttributeKey.modificationDate] as! Date, path: event.path, flags: flags)

                } catch {
                    //print(error)
                }
        })
    }
    
    @objc func onActiveApplicationChange(_ notification: NSNotification) {
        
        if let activeApp = notification.userInfo?["activeApplication"] as? NSRunningApplication {
            let appName = activeApp.localizedName ?? ""
            var resourcePath: String
            if appName == "Google Chrome" || appName == "Safari" {
                resourcePath = getWebsiteOfActiveBrowser(appName)
            } else {
                resourcePath = getResourceOfActiveApplication(activeApp: activeApp)
            }
            
            ResourceActivityQueries.saveResourceOfApplication(date: Date(), path: resourcePath, process: appName)
            
            // "PersonalAnalytics" or "PersonalAnalytics Dev"
            let thisAppName = Bundle.main.infoDictionary![kCFBundleNameKey as String] as! String
            
            if appName == thisAppName {
                return // when navigating to the ResourceWindow, the last active resource should remain.
            }
            
            let associatedResourcePaths = getSimilarResourcePaths(to: resourcePath) ?? []
            let associatedResources = toAssociatedResources(associatedResourcePaths: associatedResourcePaths, activeResourcePath: resourcePath)
            windowContoller.setActiveResource(activeResourcePath: resourcePath, activeAppName: appName, activeAppIcon: activeApp.icon, associatedResources: associatedResources)
        }
    }
    
    private func toAssociatedResources(associatedResourcePaths: [String], activeResourcePath: String) -> [AssociatedResource] {
        return associatedResourcePaths.map({ (r: String) -> AssociatedResource in
            let set: Set<Int> = [(tokenMap[r] ?? -1), tokenMap[activeResourcePath] ?? -1]
            if let intervention = interventionMap[set] {
                if intervention == .similar {
                    return AssociatedResource(path: r, status: .confirmedSimilar)
                }
                else if intervention == .dissimilar {
                    return AssociatedResource(path: r, status: .confirmedDissimilar)
                }
                
            }
            return AssociatedResource(path: r)
        })
    }
    
//    private func filterConflictingInterventions(activeResource: String, simResources: [String]) -> [String] {
//        print("filtering for active resource", activeResource)
//        return simResources.filter({ (r: String) -> Bool in
//            let set: Set<Int> = [(tokenMap[r] ?? -1), tokenMap[activeResource] ?? -1]
//            print("token set", set)
//            if let intervention = interventionMap[set] {
//                print("intervention found", intervention)
//                return intervention != .dissimilar
//            }
//            return true
//        })
//    }
    
    private func getResourceOfActiveApplication(activeApp: NSRunningApplication) -> String {
        
        // get resouce associated with active application
        var filePath: String?
        var result = [AXUIElement]()
        var windowList: AnyObject? // [AXUIElement]
        let appRef = AXUIElementCreateApplication(activeApp.processIdentifier)
        if AXUIElementCopyAttributeValue(appRef, "AXWindows" as CFString, &windowList) == .success {
            result = windowList as! [AXUIElement]
        }

        if !result.isEmpty {
            var docRef: AnyObject?
            if AXUIElementCopyAttributeValue(result.first!, "AXDocument" as CFString, &docRef) == .success {
                filePath = docRef as? String
            }
        }
        
        return filePath ?? ""
    }
    
    // works with "Google Chrome" and "Safari"
    private func getWebsiteOfActiveBrowser(_ browser: String) -> String {
        
        // helper function
        func runApplescript(_ script: String) -> String?{
            var error: NSDictionary?
            if let scriptObject = NSAppleScript(source: script) {
                if let output: NSAppleEventDescriptor = scriptObject.executeAndReturnError(
                    &error) {
                        if let URL = output.stringValue {
                            return URL // This is the important outcome, the rest don't matter
                        }
                } else if (error != nil) {
                    print("error: \(error)")
                }
            }
            return nil
        }
        
        switch browser {
            case "Google Chrome":
                // let titleReturn = runApplescript("tell application \"Google Chrome\" to return title of active tab of front window")
                let url = runApplescript("tell application \"Google Chrome\" to return URL of active tab of front window")
                return url ?? ""
                
            case "Safari":
                //  let titleReturn = runApplescript("tell application \"Safari\" to return name of front document")
                let url = runApplescript("tell application \"Safari\" to return URL of front document")
                return url ?? ""
            default:
                break
        }
        return ""
    }
}
