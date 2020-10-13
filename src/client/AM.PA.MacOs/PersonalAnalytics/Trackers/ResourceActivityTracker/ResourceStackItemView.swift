//
//  ResourceStackItemView.swift
//  PersonalAnalytics
//
//  Created by Roy Rutishauser on 07.09.20.
//

import Foundation
import Cocoa

protocol RecentlyUsedDelegate: AnyObject {
    func forwardKeepIntervention(forResource: String)
}
//
//// A collection item displays an image.
//class ResourceStackItemView: NSView {
//
//    var resourcePath = ""
//    var delegate: RecentlyUsedDelegate?
//    
//    // MARK: - IBOutlets
//    @IBOutlet weak var label: NSTextField!
//    @IBOutlet weak var button: NSButton!
//    
//    
//    // MARK: - IBAction
//    
//    // https://developer.apple.com/forums/thread/105137
//    
//    @IBAction func onKeepResource(_ sender: NSButton) {
//        print("afsdfads")
//        delegate?.forwardKeepIntervention(forResource: resourcePath)
//    }
//    
//    override func viewWillDraw() {
//        print(label, "label")
//    }
//    
//    func setMyLabel(_ l: String) {
//        label?.stringValue = l
//        print("test")
//    }
//}
