//
//  ResourceViewController.swift
//  PersonalAnalytics
//
//  Created by Roy Rutishauser on 29.06.20.
//

import Foundation
import Cocoa

fileprivate extension URL {
    var domain: String {
        var path = self.absoluteString.replacingOccurrences(of: "http://www.", with: "")
        path = path.replacingOccurrences(of: "https://www.", with: "")
        path = path.replacingOccurrences(of: "http://", with: "")
        path = path.replacingOccurrences(of: "https://", with: "")
        var domain = ""
        for char in path {
            if char == "/" || char == "?" {
                return domain
            }
            domain += String(char)
        }
        return domain
    }
    
    var shortened: String {
        
        if self.isFileURL {
            return self.relativePath.replacingOccurrences(of: NSHomeDirectory(), with: "")
        }
        
        var path = self.absoluteString.replacingOccurrences(of: "http://www.", with: "")
        path = path.replacingOccurrences(of: "https://www.", with: "")
        path = path.replacingOccurrences(of: "http://", with: "")
        path = path.replacingOccurrences(of: "https://", with: "")
        return path
    }
}

class InterventionButton: NSButton {
    var activeResourcePath: String?
    fileprivate var associatedResource: AssociatedResource?
    var intervention: Intervention?
}

enum InterventionStatus: Int, Comparable {
    case confirmedDissimilar = -1
    case open = 0
    case confirmedSimilar = 1
    
    static func < (lhs: InterventionStatus, rhs: InterventionStatus) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

class AssociatedResource {
    let path: String // resource file path or web url
    var status: InterventionStatus // user-manipulated status
    var similarity: Float // sim score [0,1]
    var count: Int // total freq count over the whole token sequence
    var embedding: [Float] // the embedding vector representing this resource
    var cooccurrenceCount: Int // co-occurrence count (sliding-window) with the active resource
    var windowName: String // window name or website title
    
    init(path: String, win: String, sim: Float, emb: [Float], count: Int, cocount: Int) {
        self.path = path
        self.status = .open
        self.similarity = sim
        self.count = count
        self.embedding = emb
        self.windowName = win
        self.cooccurrenceCount = cocount
    }
    
    func updateStatus(intervention i: Intervention) {
        if status == .confirmedSimilar && i == .similar {
            status = .open
        } else if status == .confirmedSimilar && i == .dissimilar {
            status = .confirmedDissimilar
        } else if status == .open && i == .similar {
            status = .confirmedSimilar
        } else if status == .open && i == .dissimilar {
            status = .confirmedDissimilar
        } else if status == .confirmedDissimilar && i == .dissimilar {
            status = .open
        } else if status == .confirmedDissimilar && i == .similar {
            status = .confirmedSimilar
        }
    }
}
    
class InterventionCellView: NSTableCellView {
    
    weak var delegate: ResourceInterventionDelegate?
    
    @IBOutlet weak var button: InterventionButton?
    @IBAction func onClick(_ sender: InterventionButton) {
        sender.associatedResource!.updateStatus(intervention: sender.intervention!)
        self.delegate?.forwardIntervention(activeResource: sender.activeResourcePath!, associatedResource: sender.associatedResource!.path, type: sender.intervention!)
    }
}

protocol ResourceInterventionDelegate: AnyObject {
    func forwardIntervention(activeResource: String, associatedResource: String, type: Intervention)
}

protocol ResourceDebugWriterDelegate: AnyObject {
    func writeDebugInformation(forResource: String)
}

protocol ResourceActionDelegate: AnyObject {
    func handleIntervention(activeResource: String, associatedResource: String, type: Intervention)
    func handleResourceOpened(activeResource: String, associatedResource: String, type: Interaction)
    func handleWindowInteraction(type:Interaction)
}

extension ResourceWindowController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return associatedResources?.count ?? 0
    }
}

extension ResourceWindowController: NSTableViewDelegate, ResourceInterventionDelegate {
    
    fileprivate enum CellIdentifiers {
        static let SimCell = "SimCellID"
        static let SimInterventionCell = "SimInterventionCellID"
        static let DissimInterventionCell = "DissimInterventionCellID"
        static let PathCell = "PathCellID"
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        
        // anything to show?
        guard let resource = associatedResources?[row] else {
            return nil
        }
        
        
        // populate data
        if tableColumn == tableView.tableColumns[0] {
                if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: CellIdentifiers.SimCell), owner: nil) as? NSTableCellView {
                    cell.textField?.stringValue = String(format: "%.2f", resource.similarity)
                    return cell
                }
        } else if tableColumn == tableView.tableColumns[1] {
            if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: CellIdentifiers.SimInterventionCell), owner: nil) as? InterventionCellView {
                cell.button?.activeResourcePath = activeResource!
                cell.button?.associatedResource = resource
                cell.button?.intervention = .similar
                cell.button?.title = resource.status == .confirmedSimilar ? "📍" : "👍"
                cell.delegate = self
                return cell
            }
        } else if tableColumn == tableView.tableColumns[2] {
            if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: CellIdentifiers.DissimInterventionCell), owner: nil) as? InterventionCellView {
                cell.button?.activeResourcePath = activeResource!
                cell.button?.associatedResource = resource
                cell.button?.intervention = .dissimilar
                cell.button?.title = resource.status == .confirmedDissimilar ? "📍" : "👎"
                cell.delegate = self
                return cell
            }
        } else if tableColumn == tableView.tableColumns[3] {
            if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: CellIdentifiers.PathCell), owner: nil) as? NSTableCellView {
                cell.textField?.attributedStringValue = getResourceDescription(resource: resource)
                cell.imageView?.image = getFileIcon(resourcePath: resource.path)
                return cell
            }
        }
        return nil
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        if let tableRow = tableView.rowView(atRow: tableView.selectedRow, makeIfNecessary: false) {
            let path = associatedResources![tableView.selectedRow].path
            if path.starts(with: "http") {
                let controller = WebResourcePopoverController(nibName: NSNib.Name(rawValue: "WebResourcePopoverView"), bundle: nil)
                controller.showURL(path, fromView: tableRow)
            }
        }
    }
}

class ResourceWindowController: NSWindowController, NSWindowDelegate {
    
    // MARK: IBOutlets
    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var activeResourceTextField: NSTextFieldCell!
    @IBOutlet weak var activeAppIcon: NSImageView!
    @IBOutlet weak var toggleOnOffCheckbox: NSButton!
    @IBOutlet weak var toggleFilterCheckbox: NSButton!
    
    @IBAction func onToggleOnOffCheck(_ sender: NSButton) {
        if toggleOnOffCheckbox.state == .on {
            turnRecommendationsOn()
        } else {
            turnRecommendationsOff()
        }
    }
    
    @IBAction func onToggleFilter(_ sender: Any) {
        if toggleFilterCheckbox.state == .on {
            toggleFilterCheckbox.title = "hide blocked"
            associatedResources = allAssociatedResources
        } else {
            toggleFilterCheckbox.title = "show all"
            associatedResources = allAssociatedResources?.filter { $0.status != .confirmedDissimilar }
        }
        
        tableView.reloadData()
    }
    
    private var associatedResources: [AssociatedResource]?
    private var allAssociatedResources: [AssociatedResource]?
    private var activeResource: String?
    private var currentActiveTableRow: Int = 0
    private(set) var isRecommendationEnabled = false
    private var browserIcon: NSImage?
    
    var actionDelegate: ResourceActionDelegate?
    var debugDelegate: ResourceDebugWriterDelegate?
    
    override func windowDidLoad() {
        super.windowDidLoad()
        
        tableView.delegate = self
        tableView.dataSource = self
        
        tableView.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        tableView.doubleAction = #selector(handleTableDoubleClick)
        
        if UserDefaults.standard.bool(forKey: "resourceRecommendationsEnabled") {
            toggleOnOffCheckbox.state = .on
            turnRecommendationsOn()
        } else {
            toggleOnOffCheckbox.state = .off
            turnRecommendationsOff()
        }
        
        actionDelegate?.handleWindowInteraction(type: .openedRecommenderWindow)
    }
    
    func windowWillClose(_ notification: Notification) {
        actionDelegate?.handleWindowInteraction(type: .closedRecommenderWindow)
    }
    
    func forwardIntervention(activeResource: String, associatedResource: String, type: Intervention) {
        actionDelegate?.handleIntervention(activeResource: activeResource, associatedResource: associatedResource, type: type)
        tableView.reloadData()
        // programmatically set the selected row index to not jump back up to 0
        tableView.selectRowIndexes(NSIndexSet(index: currentActiveTableRow) as IndexSet, byExtendingSelection: false)
    }
        
    func show() {
        guard let w = self.window else {
            return
        }
        // NSApp.activate(ignoringOtherApps: true)
        // w.orderFrontRegardless()
        w.level = .floating // keeps the window on top at all times
        w.makeKeyAndOrderFront(self)
        
        // w.styleMask.remove(.titled)
        // w.styleMask.remove(.miniaturizable)
        // w.styleMask.remove(.resizable)
        // if let view = w.contentView {}
        
        showWindow(self)
    }
    
    private func getFileIcon(resourcePath: String) -> NSImage? {
        guard let url = URL(string: resourcePath) else {
            return NSWorkspace.shared.icon(forFile: "") // this will show the empty page icon
        }
        
        if url.isFileURL {
            return NSWorkspace.shared.icon(forFile: url.relativePath)
        }
        
        return browserIcon
    }
    
    private func getResourceDescription(resource r: AssociatedResource) -> NSMutableAttributedString {
        guard let url = URL(string: r.path) else {
            return NSMutableAttributedString(string: r.path)
        }
        
        var description: NSMutableAttributedString
        
        if r.windowName.isEmpty || url.isFileURL {
            description = NSMutableAttributedString(string: url.shortened)
        } else {
            description = NSMutableAttributedString(string: url.domain + " " + r.windowName)
            description.addAttribute(.backgroundColor, value: NSColor.systemBlue, range: NSMakeRange(0, url.domain.count))
        }
        
        // strikethrough text if file doesn't exists anymore
        if url.isFileURL && !FileManager.default.fileExists(atPath: url.relativePath) {
            description.addAttribute(.strikethroughStyle, value: 1, range: NSMakeRange(0, description.length))
        }
        
        return description
    }
    
    private func turnRecommendationsOff() {
        isRecommendationEnabled = false
        activeAppIcon.image = nil
        tableView.isHidden = true
        activeResourceTextField.stringValue = ""
        toggleOnOffCheckbox.title = "enable"
        
        UserDefaults.standard.set(false, forKey: "resourceRecommendationsEnabled")
        
        // removes old table entries which otherwise would show up
        // once the recommandations are turned on again.
        associatedResources?.removeAll()
        tableView.reloadData()
    }
    
    private func turnRecommendationsOn() {
        isRecommendationEnabled = true
        activeResourceTextField.stringValue = "unknown"
        tableView.isHidden = false
        toggleOnOffCheckbox.title = "disable"
        
        UserDefaults.standard.set(true, forKey: "resourceRecommendationsEnabled")
    }
            
    func setActiveResource(activeResourcePath: String, activeAppIcon icon: NSImage?, associatedResources: [AssociatedResource], browserIcon: NSImage?) {
                
        activeAppIcon.image = icon
        
        if activeResourcePath == "" {
            tableView.isHidden = true
            activeResourceTextField.stringValue = "unknown"
            return
        }
        
        tableView.isHidden = false
        activeResourceTextField.stringValue = URL(string: activeResourcePath)?.shortened ?? activeResourcePath
        
        self.associatedResources = associatedResources.filter { $0.status != .confirmedDissimilar }
        self.allAssociatedResources = associatedResources
        self.activeResource = activeResourcePath
        self.browserIcon = browserIcon
        self.tableView.reloadData()
    }
    
    func setLoadingResource(activeAppIcon icon: NSImage?) {
        activeAppIcon.image = icon
        
        activeResourceTextField.stringValue = "Loading..."
        
        associatedResources?.removeAll()
        tableView.reloadData()
    }
    
    
    // MARK: - Event Handling
    
    @objc func handleTableDoubleClick() {
        let row = tableView.clickedRow
        let resource = associatedResources![row]
        if let url = URL(string: resource.path) {
            if !NSWorkspace.shared.open(url) {
                print("could not open file", url.absoluteString)
            }
        }
        
        actionDelegate?.handleResourceOpened(activeResource: activeResource!, associatedResource: resource.path, type: .openedResource)
    }
    
    override func keyDown(with event: NSEvent) {
        if let resource = associatedResources?[tableView.selectedRow] {
            
            if (event.characters == "n") {
                resource.status = .confirmedDissimilar
                currentActiveTableRow = tableView.selectedRow
                forwardIntervention(activeResource: activeResource!, associatedResource: resource.path, type: .dissimilar)
            }
            
            if (event.characters == "y") {
                resource.status = .confirmedSimilar
                currentActiveTableRow = tableView.selectedRow
                forwardIntervention(activeResource: activeResource!, associatedResource: resource.path, type: .similar)
            }
            
            if (event.characters == "i") {
                debugDelegate?.writeDebugInformation(forResource: activeResource!)
            }
        }
    }
}
