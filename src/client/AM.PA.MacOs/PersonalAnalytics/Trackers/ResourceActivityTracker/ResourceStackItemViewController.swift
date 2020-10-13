//
//  ResourceStackItemViewController.swift
//  PersonalAnalytics
//
//  Created by Roy Rutishauser on 28.08.20.
//

import Cocoa

protocol RecentlyUsedDelegate {
    func forwardKeepIntervention(forResource: String)
}

// A collection item displays an image.
class ResourceStackItemViewController: NSViewController {

    var resourcePath = ""
    var delegate: RecentlyUsedDelegate?
    
    // MARK: - IBOutlets
    @IBOutlet weak var label: NSTextField!
    @IBOutlet weak var button: NSButton!

    
    // MARK: - View Controller Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.wantsLayer = true
        
        label?.stringValue = URL(string: resourcePath)?.shortened ?? resourcePath
    }
    
    @IBAction func onKeepResource(_ sender: NSButton) {
        delegate?.forwardKeepIntervention(forResource: resourcePath)
    }
    
    
//    override var isSelected: Bool {
//        didSet {
//            if isSelected {
//                // Create visual feedback for the selected collection view item.
//                view.layer?.borderColor = NSColor.lightGray.cgColor
//                view.layer?.borderWidth = 4
//            } else {
//                view.layer?.borderWidth = 0
//            }
//        }
//    }
    
}

