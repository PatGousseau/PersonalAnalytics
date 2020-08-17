//
//  ResourcePopover.swift
//  PersonalAnalytics
//
//  Created by Roy Rutishauser on 13.08.20.
//

import Cocoa
import WebKit

class WebResourcePopoverController: NSViewController {
    
    @IBOutlet weak var webView: WKWebView!
    
    let popover = NSPopover()
    var urlstr: String?

    func showURL(_ url: String, fromView: NSView) {
        self.urlstr = url
        popover.contentViewController = self
        popover.behavior = .transient
        popover.show(relativeTo: fromView.bounds, of: fromView, preferredEdge: .maxX)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let url = URL(string: urlstr!) {
            webView.load(URLRequest(url: url))
        }
    }
}
