//
//  TaskQueries.swift
//  PersonalAnalytics
//
//  Created by Chris Satterfield on 2020-05-25.
//

import Foundation
import GRDB


class TaskQueries{
        
    static func GetDayTimelineData(date: Date) -> [Task]{
        let taskSegments = generateVectoredTaskSegments(date: date)
        print(taskSegments.count)
        let mergedSegments = mergeTaskSegments(taskSegments)
        print(mergedSegments.count)
        return mapToRandomTask(taskSegments: mergedSegments)
    }
    
    static func formWordCloudWordList(_ v: Vector) -> [String:Double]{
        return v.scores
    }
    
    static func mapToRandomTask(taskSegments: [VectoredTaskSegment]) -> [Task] {
        let taskIds = ["1", "2", "3", "4", "5"]
        
        var tasks: [Task] = []
        var lastElement = ""
        
        for segment in taskSegments {
            let choice = taskIds.randomElement()!
            if(choice == lastElement){
                continue
            }
            tasks.append(Task(start: segment.startTime, end: segment.endTime, taskId: choice, name: "", words:formWordCloudWordList(segment.vector)))
            lastElement = choice
        }
        
        
        return tasks
    }
    
    static func generateVectoredTaskSegments(date: Date) -> [VectoredTaskSegment] {
        let taskSegments = TaskQueries.getTaskSegmentsForDay(date: date) //later add in date parameter
        let tfidf = TFIDF(documents: taskSegments.map({$0.windowTitles}))
        return taskSegments.map{VectoredTaskSegment(taskSegment: $0, vector: tfidf.vectorize(document: $0.windowTitles))}
    }
    
    static func areAdjacent(_ ts1: TaskSegment, _ ts2: TaskSegment) -> Bool {
        return ts1.endTime - ts2.startTime < 60
    }
    
    static func mergeTaskSegments(_ taskSegments: [VectoredTaskSegment]) -> [VectoredTaskSegment] {
        print(taskSegments.count)
        if(taskSegments.count <= 1){
            return taskSegments
        }
        var start = taskSegments[0].startTime
        var vectors: [Vector] = []
        var windowTitles: [String] = []
        var results: [VectoredTaskSegment] = []
        for i in 0..<(taskSegments.count - 1) {
            let ts1 = taskSegments[i]
            let ts2 = taskSegments[i+1]
            
            vectors.append(ts1.vector)
            windowTitles.append(ts1.windowTitles)
            if(Vector.cosine(ts1.vector, ts2.vector) > TaskSettings.TaskSegmentSimilarityThreshold && areAdjacent(ts1,ts2)){
                continue
            }
            else{
                let avgVector = Vector.average(vectors)
                results.append(VectoredTaskSegment(start: start, end: ts1.endTime, windowTitles: windowTitles.joined(separator: " "), vector: avgVector))
                vectors = []
                windowTitles = []
                start = ts2.startTime
            }
        }
        return results
    }
    
    /*static func formTasksFromSegments(_ taskSegments: [VectoredTaskSegment]) -> [Task] {
        
        for i in 1..<taskSegments.count{
            
        }
    }*/
    
    static func getTaskSegmentsForDay(date: Date) -> [TaskSegment] {
        
            let dbController = DatabaseController.getDatabaseController()
        
            let startStr = DateFormatConverter.interval1970ToDateStr(interval: date.getStartHour() + 3600*7)
            let endStr = DateFormatConverter.interval1970ToDateStr(interval: date.getEndHour() + 3600*7)
                    
            var results:[TaskSegment] =  []
            do{
                let query = """
                            SELECT *
                            FROM \(TaskSettings.DbTable)
                            WHERE tsStart >= '\(startStr)' AND tsEnd <= '\(endStr)'
                            """
                    let rows = try dbController.executeFetchAll(query: query)
                    
                    for row in rows{
                        let start = DateFormatConverter.dateStrToInterval1970(str: row["tsStart"])
                        let end = DateFormatConverter.dateStrToInterval1970(str: row["tsEnd"])
                        let windowTitles: String = row["windowTitles"]
                        results.append(TaskSegment(start: start, end: end, windowTitles: windowTitles))
                    }
                }
            catch{
                print(error)
                print("error accessing database for pie chart")
            }
        
        return results
    }
    
    static func createDatabaseTablesIfNotExist() {
        let dbController = DatabaseController.getDatabaseController()
        let query: String = "CREATE TABLE IF NOT EXISTS \(TaskSettings.DbTable) (id INTEGER PRIMARY KEY, tsStart TEXT, tsEnd TEXT, windowTitles TEXT, appList TEXT);"
        do{
            try dbController.executeUpdate(query: query)
        }
        catch{
            print(error)
        }
    }
    
    static func saveTaskSegment(tsStart: Date, tsEnd: Date, windowTitles: [String], appNames: [String]){
        let dbController = DatabaseController.getDatabaseController()
        
        do {
            let windowTitlesString = windowTitles.joined(separator: " ")
            let appNamesString = appNames.joined(separator: " ")
            let args: StatementArguments = [
                DateFormatConverter.dateToStr(date: tsStart),
                DateFormatConverter.dateToStr(date: tsEnd),
                windowTitlesString,
                appNamesString
            ]
            
            let q = """
                    INSERT INTO \(TaskSettings.DbTable) (tsStart, tsEnd, windowTitles, appList)
                    VALUES (?, ?, ?, ?)
                    """
                   
            try dbController.executeUpdate(query: q, arguments:args)
                   
        } catch {
            print(error)
        }
    }
}

extension String {
    func split(usingRegex pattern: String) -> [String] {
        //### Crashes when you pass invalid `pattern`
        let regex = try! NSRegularExpression(pattern: pattern)
        let matches = regex.matches(in: self, range: NSRange(0..<utf16.count))
        let ranges = matches.map{Range($0.range, in: self)!}
        return (0..<matches.count).map {String(self[ranges[$0].lowerBound..<ranges[$0].upperBound])}
    }
}
