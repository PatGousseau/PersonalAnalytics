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
        return generateRandomTasks(date: date, number: 10)
    }
    
    static func generateRandomTasks(date: Date, number: Int) -> [Task]{
        let taskIds = ["1", "2", "3", "4", "5"]
        var last: String = ""
        var tasks: [Task] = []
        var start = date.getStartHour() + (3600 * 8)
        let end = date.getStartHour() + (3600 * 16)
        let duration = (end - start)/Double(number)
        for _ in 1...number {
            var taskId = taskIds.randomElement()!
            while(taskId == last){
                taskId = taskIds.randomElement()!
            }
            last = taskId
            tasks.append(Task(start:start, end: start + duration, taskId: taskId, name: ""))
            start = start + duration
        }
        return tasks
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
            let windowTitlesString = windowTitles.map { "\"" + $0 + "\"" }.joined(separator: ", ")
            let appNamesString = appNames.map { "\"" + $0 + "\"" }.joined(separator: ", ")
            let args: StatementArguments = [
                tsStart,
                tsEnd,
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
