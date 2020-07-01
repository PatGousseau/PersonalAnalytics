//
//  IListener.swift
//  PersonalAnalytics
//
//  Created by Chris Satterfield on 2020-06-01.
//

import Foundation

protocol IWindowsActivityListener {
    func notifyWindowTitleChange(windowTitle: String)
    func notifyAppChange(appName: String)
    func notifyIdle()
    func notifyResumed()
}
