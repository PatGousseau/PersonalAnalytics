//
//  ResourceActivityTracker.swift
//  PersonalAnalytics
//
//  Created by Roy Rutishauser on 04.02.20.
//

import Foundation
import CoreGraphics
import Quartz

// USEFUL URLS
// https://fluffy.es/how-auto-layout-calculates-view-position-and-size/
// https://github.com/eonil/FSEvents
// https://jordansmith.io/cancelling-background-tasks/
// https://www.appcoda.com/macos-programming-tableview/
// https://stackoverflow.com/questions/54575962/why-does-nstextfield-with-usessinglelinemode-set-to-yes-has-intrinsic-content-si


fileprivate enum ResourceFileError: Error {
    case embeddings(String)
    case intervention(String)
}

fileprivate struct CachedSimScore {
    var similarity: Float
    var lastUpdate: Date
    
    init(similarity: Float) {
        self.lastUpdate = Date()
        self.similarity = similarity
    }
    
    func isOutdated() -> Bool {
        // 5 mins
        let d = self.lastUpdate.addingTimeInterval(60*5)
        return d < Date()
    }
}

enum Intervention: Equatable {
    case similar
    case dissimilar
}

enum Interaction: Equatable {
    case setSimilar
    case setDissimilar
    case switchToSimilar
    case switchToDissimilar
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
    private var simCache = [Set<Int>: CachedSimScore]()
    
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
                
                self.embeddings = try self.readEmbeddingsFromDisk()
            }
            catch ResourceFileError.embeddings(let msg) {
                print(msg, "- using co-occurrence matrix instead")
                self.embeddings = self.cooccurrences.map { $0.map { Float($0) } }
            }
            catch {
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
            for (i, row) in rows.enumerated() {
                if row.isEmpty {
                    continue;
                }
                
                let splitted = row.split(separator: ",")
                guard splitted.count == 3 else {
                    throw ResourceFileError.intervention("\(fileURL.path) has \(splitted.count) columns. Should have 3.")
                }
                
                guard let t1 = Int(splitted[1].trimmingCharacters(in: .whitespaces)) else {
                    throw ResourceFileError.intervention("\(fileURL.path): cannot parse \"\(splitted[1])\" as Int on line \(i).")
                }
                guard let t2 = Int(splitted[2].trimmingCharacters(in: .whitespaces)) else {
                    throw ResourceFileError.intervention("\(fileURL.path): cannot parse \"\(splitted[2])\" as Int on line \(i).")
                }
        
                let set:Set = [t1, t2]
                let itype = splitted[0].trimmingCharacters(in: .whitespaces)
                var intervention: Intervention
                
                if itype == "d" {
                    intervention = .dissimilar
                } else if itype == "s" {
                    intervention = .similar
                } else {
                    throw ResourceFileError.intervention("cannot parse \(fileURL.path). Unknown intervention type \"\(itype)\" on line \(i)")
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
                    throw ResourceFileError.intervention("intervention for tokens \(set) already exists")
                }
                // user switches intervention to the opposite
                else {
                    if type == .dissimilar {
                        try writeInteractionToLog(activeToken: activeToken, associatedToken: associatedToken, type: .switchToDissimilar)
                    } else {
                        try writeInteractionToLog(activeToken: activeToken, associatedToken: associatedToken, type: .switchToSimilar)
                    }
                    
                    interventionMap[set] = type // switches the type
                    try rewriteManualInterventions()
                }
            }
            // user sets a new intervention
            else {
                interventionMap[set] = type
                try appendManualIntervention(tokenSet: set, type: type)
                if type == .dissimilar {
                    try writeInteractionToLog(activeToken: activeToken, associatedToken: associatedToken, type: .setDissimilar)
                } else {
                    try writeInteractionToLog(activeToken: activeToken, associatedToken: associatedToken, type: .setSimilar)
                }
            }
        }  catch {
            print(error)
        }
    }
    
    private func rewriteManualInterventions() throws {
        let fileURL = supportDir.appendingPathComponent(ResourceActivitySettings.ManualInterventionFile)
        var fileStr = ""

        for (set, type) in interventionMap {
            fileStr += getManualInterventionLine(tokenSet: set, type: type)
        }
        
        try fileStr.write(to: fileURL, atomically: true, encoding: String.Encoding.utf8)
    }
    
    private func getManualInterventionLine(tokenSet: Set<Int>, type: Intervention) -> String {
        var str = ""
        // produces ",1,8"
        let resources = tokenSet.reduce("", { s, r in s + "," + String(r) })
        
        switch type {
        case .similar:
            str += "s" + resources + "\n"
        case .dissimilar:
            str += "d" + resources + "\n"
        }
        
        return str
    }
    
    private func appendManualIntervention(tokenSet: Set<Int>, type: Intervention) throws {
        let fileURL = supportDir.appendingPathComponent(ResourceActivitySettings.ManualInterventionFile)
        let str = getManualInterventionLine(tokenSet: tokenSet, type: type)
        try appendToFile(fileUrl: fileURL, string: str)
    }
    
    private func appendToFile(fileUrl: URL, string: String) throws {
        let data = string.data(using: .utf8, allowLossyConversion: false)!
        
        if !FileManager.default.fileExists(atPath: fileUrl.path) {
            // creates an empty file to append to
            try "".write(to: fileUrl, atomically: true, encoding: String.Encoding.utf8)
        }
        
        let fileHandle = try FileHandle(forUpdating: fileUrl)
        fileHandle.seekToEndOfFile()
        fileHandle.write(data)
        fileHandle.closeFile()
    }
    
    internal func handleResourceOpened(activeResource: String, associatedResource: String, type: Interaction) {
        assert(type == .openedResource)
        
        let act = tokenMap[activeResource]
        let ast = tokenMap[associatedResource]
        
        do {
            try writeInteractionToLog(activeToken: act, associatedToken: ast, type: .openedResource)
        } catch  {
            print(error)
        }
    }
    
    internal func handleWindowInteraction(type: Interaction) {
        assert(type == .closedRecommenderWindow || type == .openedRecommenderWindow)
        do {
            try writeInteractionToLog(activeToken: nil, associatedToken: nil, type: type)
        } catch {
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
            str += "set similarity for \(String(associatedToken!))"
        case .setDissimilar:
            str += "set dissimilarity for \(String(associatedToken!))"
        case .switchToSimilar:
            str += "switch to similarity for \(String(associatedToken!))"
        case .switchToDissimilar:
            str += "switch to dissimilarity for \(String(associatedToken!))"
        case .openedResource:
            str += "opened resource \(String(associatedToken!))"
        }
        
        str += "\n"
        
        try appendToFile(fileUrl: fileURL, string: str)
    }
    
    /// precondition: the sql table needs no manipulation. Token indexes are enumerated in order of first appearance in the database.
    /// If the order of first appearance changes, anonymous tokens, interventions and the sequence get corrupted.
    private func writeTokenMapsFromSQLite() throws -> ([String: Int], [Int: String], [Int], [Int]) {
        let dbController = DatabaseController.getDatabaseController()
        let rows = try dbController.executeFetchAll(query: "SELECT path FROM \(ResourceActivitySettings.DbTableApplicationResource) ORDER BY time")
        
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
            
        } catch {
            print(error)
        }
        
        return (tokenMap, invTokenMap, intseq, freqCounts)
    }

    private func anonymizePath(path: String) -> String {
        let chunks = path.components(separatedBy: CharacterSet(charactersIn: "/:.-_&?"))
        var anonymousPath = ""

        for chunk in chunks {
             if chunkMap[chunk] == nil {
                // we are not randomizing the chunk "http(s)" or "file" to make sure we
                // retain the origin (web or fs) of the resources
                if path.starts(with: "http") && chunk.starts(with: "http") {
                    chunkMap[chunk] = chunk
                } else if path.starts(with: "file") && chunk == "file" {
                    chunkMap[chunk] = chunk
                } else {
                    chunkMap[chunk] = randomString(length: 4)
                }
            }
            anonymousPath += chunkMap[chunk]!
        }
        return anonymousPath
    }
      
    private func randomString(length: Int) -> String {
      let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
      return String((0..<length).map{ _ in letters.randomElement()! })
    }
    
    private func readEmbeddingsFromDisk() throws -> [[Float]]? {
        let fileURL = supportDir.appendingPathComponent(ResourceActivitySettings.EmbeddingsFile)
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw ResourceFileError.embeddings(ResourceActivitySettings.EmbeddingsFile + " is missing")
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
                    throw ResourceFileError.embeddings("cannot cast to float")
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
                    var similarity:Float
                    let set: Set<Int> = [token, i]
                    
                    if let cachedSim = simCache[set] {
                        if !cachedSim.isOutdated() {
                            similarity = cachedSim.similarity
                        } else {
                            similarity = Similarity.calc(vector: embedding, other: activeEmbedding)
                            simCache[set] = CachedSimScore(similarity: similarity)
                        }
                    } else {
                        similarity = Similarity.calc(vector: embedding, other: activeEmbedding)
                        simCache[set] = CachedSimScore(similarity: similarity)
                    }
                    
                    if similarity > thresh {
                        if let path = invTokenMap[i] {
                            similarResources.append( AssociatedResource(path: path, similarity: similarity))
                        }
                        else {
                            // this should never happen
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
                    r.similarity += 1
                }
                else if intervention == .dissimilar {
                    r.status = .confirmedDissimilar
                    r.similarity -= 1
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
