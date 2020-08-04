//
//  ResourceActivityTracker.swift
//  PersonalAnalytics
//
//  Created by Roy Rutishauser on 04.02.20.
//

import Foundation
import CoreGraphics
import Quartz

// USEFUL
// https://stackoverflow.com/questions/54575962/why-does-nstextfield-with-usessinglelinemode-set-to-yes-has-intrinsic-content-si
// https://fluffy.es/how-auto-layout-calculates-view-position-and-size/

// TODO
// website preview tile
// caching of calculated similarities
// better design of window and buttons
// error handling --> CSVError
// let users change their voting
// onAppChange, filter dissimilar resources, stick📍 similar resources


enum CSVError: Error {
    case parseError(String)
}

enum Intervention: Equatable {
    case similar
    case dissimilar
}

enum Interaction: Equatable {
    case setSimilar
    case setDissimilar
    case openedResource
    case openedRecommenderWindow
    case closedRecommenderWindow
}

class ResourceActivityTracker: ITracker, ResourceControllerDelegate {
    
    var name = ResourceActivitySettings.Name
    var isRunning = true
    var windowContoller = ResourceWindowController(windowNibName: NSNib.Name(rawValue: "ResourceWindow"))
    private var tokenMap = [String: Int]() // www.google.com : 2
    private var invTokenMap = [Int: String]() // 2 : www.google.com
    private var chunkMap = [String: String]() // pathChunk : randomStr
    private var interventionMap = [Set<Int>: Intervention]()  // {token1, token2}: 0 (dissimilar)
    private var embeddings: [[Float]]? // embeddings learned with resource2vec or from co-occurrence matrix
    private var sequence = [Int]() // sequence of tokens
    private var freqCounts = [Int]() // #occurences of a token in the sequence
    private var cooccurrences = [[Int]]() // co-occurrence matrix
    
    private var browserIcon: NSImage? // TODO: this is a hack here, can we get the default browser app icon?
    
    private lazy var supportDir: URL = {
        let urls = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appSupportURL = urls[urls.count - 1]
        return appSupportURL.appendingPathComponent(Environment.appSupportDir)
    }()
    
    init() {
        NotificationCenter.default.addObserver(self, selector: #selector(self.onActiveApplicationChange(_:)), name: NSNotification.Name(rawValue: "activeApplicationChange"), object: nil)
        
        // trackFSEvents()
        windowContoller.delegate = self
        windowContoller.show()
        
        // when the app is started, hurry up and get the data
        refreshData(qos: .userInitiated)
        
        // periodically update the data in the background with low priority
        Timer.scheduledTimer(withTimeInterval: ResourceActivitySettings.RefreshRate, repeats: true) { _ in
            self.refreshData(qos: .utility)
        }
    }
    
    // this happens off the main queue
    private func refreshData(qos: DispatchQoS.QoSClass) {
        DispatchQueue.global(qos: qos).async { [weak self] in
            guard let self = self else {
                return
            }
            
            do {
                self.interventionMap = try self.readManualInterventions()
                (self.tokenMap, self.invTokenMap, self.sequence, self.freqCounts) = try self.writeTokenMapsFromSQLite()
                self.cooccurrences = self.buildCooccurrenceMatrix(sequence: self.sequence, frequencyCounts: self.freqCounts)
                
                self.embeddings = self.cooccurrences.map { $0.map { Float($0) } }
                // self.embeddings = try self.readEmbeddingsFromDisk()
            }
            catch CSVError.parseError(let msg) {
                print("Error:", msg)
            }
            catch let error as NSError {
                print("Failed to read file")
                print(error)
            }
            
            print("resource tracker metadata is refreshed.")
        }
    }

    private func buildCooccurrenceMatrix(sequence seq: [Int], frequencyCounts freq: [Int]) -> [[Int]] {
        var C = Array(repeating: Array(repeating: 0, count: freq.count), count: freq.count)
        
        for (i, token) in seq.enumerated() {
            let ws = ResourceActivitySettings.WindowSize
            let window_start = max(0, i-ws)
            let window_end = min(seq.count-1, i+ws+1)
            
            for j in window_start...window_end {
                C[token][seq[j]] += 1
                C[seq[j]][token] += 1
            }
        }
        
        return C
    }
        
    private func readManualInterventions() throws -> [Set<Int>: Intervention] {
        let fileURL = supportDir.appendingPathComponent(ResourceActivitySettings.ManualInterventionFile)
        var map = [Set<Int>: Intervention]()  // {token1, token2}: 0 (dissim)
        
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
                if i == "d" {
                    intervention = .dissimilar
                } else if i == "s" {
                    intervention = .similar
                } else {
                    throw CSVError.parseError("unknown intervention")
                }
                map[set] = intervention
            }
        }
        
        return map
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
                try writeManualInterventions(set: set, type: type)
                if type == .dissimilar {
                    try writeInteractionToLog(activeToken: activeToken, associatedToken: associatedToken, type: .setDissimilar)
                } else {
                    try writeInteractionToLog(activeToken: activeToken, associatedToken: associatedToken, type: .setSimilar)
                }
            }
        }  catch CSVError.parseError(let msg) {
            print(msg)
        }
        catch let error as NSError {
            print("Failed to read file")
            print(error)
        }
    }
    
    private func writeManualInterventions(set: Set<Int>, type: Intervention) throws {
        let fileURL = supportDir.appendingPathComponent(ResourceActivitySettings.ManualInterventionFile)
        
        var str = ""
        // produces ",1,8"
        let resources = set.reduce("", { s, r in s + "," + String(r) })
        
        switch type {
        case .similar:
            str += "s" + resources + "\n"
        case .dissimilar:
            str += "d" + resources + "\n"
        }
                
        try appendToFile(fileUrl: fileURL, string: str)
    }
    
    private func appendToFile(fileUrl: URL, string: String) throws{
        let data = string.data(using: .utf8, allowLossyConversion: false)!
            
        if FileManager.default.fileExists(atPath: fileUrl.path) {
            if let fileHandle = try? FileHandle(forUpdating: fileUrl) {
                fileHandle.seekToEndOfFile()
                fileHandle.write(data)
                fileHandle.closeFile()
            } else {
                print("failed to append to file")
                assert(false)
            }
        }
    }
    
    internal func handleResourceOpened(activeResource: String, associatedResource: String, type: Interaction) {
        assert(type == .openedResource)
        
        let act = tokenMap[activeResource]
        let ast = tokenMap[associatedResource]
        
        do {
            try writeInteractionToLog(activeToken: act, associatedToken: ast, type: .openedResource)
        } catch let error as NSError {
            print("Failed to read file")
            print(error)
        }
    }
    
    internal func handleWindowInteraction(type: Interaction) {
        assert(type == .closedRecommenderWindow || type == .openedRecommenderWindow)
        do {
            try writeInteractionToLog(activeToken: nil, associatedToken: nil, type: type)
        } catch let error as NSError {
            print("Failed to read file")
            print(error)
        }
    }
    
    private func writeInteractionToLog(activeToken: Int?, associatedToken: Int?, type: Interaction) throws {
        let fileURL = supportDir.appendingPathComponent(ResourceActivitySettings.InteractionLog)
        let d = DateFormatConverter.dateToStr(date: Date())
        
        var str = "[\(d)] "
        
        if let atoken = activeToken {
            str += "active \(String(atoken)) - "
        }
        
        switch type {
        case .openedRecommenderWindow:
            str += "opened recommender window"
        case .closedRecommenderWindow:
            str += "closed recommender window"
        case .setSimilar:
            str += "set similarity to \(String(associatedToken!))"
        case .setDissimilar:
            str += "set dissimilarity to \(String(associatedToken!))"
        case .openedResource:
            str += "opened resource \(String(associatedToken!))"
        }
        
        str += "\n"
        
        try appendToFile(fileUrl: fileURL, string: str)
    }
    
    private func writeTokenMapsFromSQLite() throws -> ([String: Int], [Int: String], [Int], [Int]) {
        let dbController = DatabaseController.getDatabaseController()
        let rows = try dbController.executeFetchAll(query: "SELECT path FROM resource_application ORDER BY time")
        
        var anonTokenMap = [String:Int]()
        var seq = ""
        var intseq = [Int]()
        var freqCounts = [Int]()
        var invTokenMap = [Int:String]()
        var tokenMap = [String: Int]()
        
        for row in rows {
            let path = String(row["path"]!)
            
            if path == "" { continue }
            
            if let token = tokenMap[path] {
                seq += String(token) + ","
                intseq.append(token)
                freqCounts[token] += 1
            } else {
                let token = tokenMap.count
                invTokenMap[token] = path
                tokenMap[path] = token
                seq += String(token) + ","
                intseq.append(token)
                freqCounts.append(1)
            }
        }
        
        for (path, token) in tokenMap {
            let anonPath = anonymizePath(path: path)
            anonTokenMap[anonPath] = token
        }
        
        do {
            let sequenceURL = supportDir.appendingPathComponent(ResourceActivitySettings.TokenSequenceFile)
            let anonTokensURL = supportDir.appendingPathComponent(ResourceActivitySettings.AnonTokenFile)
            
            let anonTokens = [String](anonTokenMap.map { return String($1) + "," + $0 })
            try anonTokens.joined(separator: "\n").write(to: anonTokensURL, atomically: true, encoding: String.Encoding.utf8)
            
            // let tokens = [String](tokenMap.map { return String($1) + "," + $0 })
            // try tokens.joined(separator: "\n").write(to: tokensURL, atomically: true, encoding: String.Encoding.utf8)
            
            try seq.write(to: sequenceURL, atomically: true, encoding: String.Encoding.utf8)
            
        } catch let error as NSError {
            print(error)
        }
        
        return (tokenMap, invTokenMap, intseq, freqCounts)
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

//    private func readTokenMaps() throws  {
//        let fileURL = supportDir.appendingPathComponent("tokens").appendingPathExtension("txt")
//        let fileManager = FileManager.default
//
//        if fileManager.fileExists(atPath: fileURL.path) {
//
//            let data = try String(contentsOf: fileURL)
//            let rows = data.components(separatedBy: "\n")
//            for row in rows {
//                let splitted = row.split(separator: ",")
//                let token = Int(splitted[0].trimmingCharacters(in: .whitespaces))!
//                let path = splitted[1].trimmingCharacters(in: .whitespaces)
//                tokenMap[path] = token
//                invTokenMap[token] = path
//            }
//
//            print(tokenMap.count, invTokenMap.count)
//        }
//    }
    
    private func readEmbeddingsFromDisk() throws -> [[Float]]? {
        let fileURL = supportDir.appendingPathComponent(ResourceActivitySettings.EmbeddingsFile)
        
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            print(ResourceActivitySettings.EmbeddingsFile + " is missing")
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
    
    private func getSimilarResources(to path: String) -> [AssociatedResource]? {
        
        if let token = tokenMap[path] {
            if let embeddings = self.embeddings {
                if token >= embeddings.count {
                    // no embedding learnt for recently indexed resource
                    return nil
                }
                let activeEmbedding = embeddings[token]
                var similarResources = [AssociatedResource]()
                for (i, embedding) in embeddings.enumerated() {
                    if i == token { continue }                  
                    let thresh = ResourceActivitySettings.SimilarityTreshold
                    let similarity = Similarity.calc(vector: embedding, other: activeEmbedding)
                    if similarity > thresh {
                        if let path = invTokenMap[i] {
                            similarResources.append( AssociatedResource(path: path, similarity: similarity))
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
    
    func stop() {
        isRunning = false
        // EonilFSEvents.stopWatching(for: ObjectIdentifier(self))
    }
    
    func start() {
        isRunning = true
        // trackFSEvents()
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
                browserIcon = activeApp.icon
                resourcePath = getWebsiteOfActiveBrowser(appName)
            } else {
                resourcePath = getResourceOfActiveApplication(activeApp: activeApp)
            }
            
            // "PersonalAnalytics" or "PersonalAnalytics Dev"
            let thisAppName = Bundle.main.infoDictionary![kCFBundleNameKey as String] as! String
            
            if appName == thisAppName {
                // when navigating to the ResourceWindow, the last active resource should remain.
                return 
            }
            
            ResourceActivityQueries.saveResourceOfApplication(date: Date(), path: resourcePath, process: appName)
            
            if !windowContoller.isRecommendationEnabled {
                return
            }
            
            // indicate loading while similarities are processed
            windowContoller.setLoadingResource(activeAppIcon: activeApp.icon)
            
            // maybe something for the future if the user switches apps very quickly
            // https://jordansmith.io/cancelling-background-tasks/
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else {
                    return
                }
                
                var associatedResources = self.getSimilarResources(to: resourcePath) ?? []
                associatedResources = self.augmentInterventionStatus(activeResourcePath: resourcePath, associatedResources: associatedResources)
                associatedResources = associatedResources.sorted(by: { $0.similarity > $1.similarity })
                
                // do the UI stuff on the queue as advised
                DispatchQueue.main.async { [weak self] in
                    self?.windowContoller.setActiveResource(activeResourcePath: resourcePath, activeAppIcon: activeApp.icon, associatedResources: associatedResources, browserIcon: self?.browserIcon)
                }
            }
        }
    }
    
    private func augmentInterventionStatus(activeResourcePath: String, associatedResources: [AssociatedResource]) -> [AssociatedResource] {
        return associatedResources.map({ (r: AssociatedResource) -> AssociatedResource in
            let set: Set<Int> = [(tokenMap[r.path] ?? -1), tokenMap[activeResourcePath] ?? -1]
            if let intervention = interventionMap[set] {
                if intervention == .similar {
                    r.status = .confirmedSimilar
                }
                else if intervention == .dissimilar {
                    r.status = .confirmedDissimilar
                }
            }
            return r
        })
    }
    
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
