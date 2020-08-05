//
//  ResourceViewController.swift
//  PersonalAnalytics
//
//  Created by Roy Rutishauser on 29.06.20.
//

import Foundation
import Cocoa

class InterventionButton: NSButton {
    var activeResourcePath: String?
    fileprivate var associatedResource: AssociatedResource?
    var intervention: Intervention?
}

enum InterventionStatus {
    case confirmedDissimilar
    case confirmedSimilar
    case open
}

class AssociatedResource {
    let path: String
    var status: InterventionStatus
    var similarity: Float
    
    init(path: String, similarity: Float) {
        self.path = path
        self.status = .open
        self.similarity = similarity
    }
}
    
// https://www.appcoda.com/macos-programming-tableview/
class InterventionCellView: NSTableCellView {
    
    weak var delegate: InterventionDelegate?
    
    @IBOutlet weak var button: InterventionButton?
    @IBAction func onClick(_ sender: InterventionButton) {
        
        if sender.intervention! == .dissimilar {
            sender.associatedResource!.status = .confirmedDissimilar
        } else {
            sender.associatedResource!.status = .confirmedSimilar
        }
        
        self.delegate?.forwardIntervention(activeResource: sender.activeResourcePath!, associatedResource: sender.associatedResource!.path, type: sender.intervention!)
    }
}

protocol InterventionDelegate: AnyObject {
    func forwardIntervention(activeResource: String, associatedResource: String, type: Intervention)
}

protocol ResourceControllerDelegate: AnyObject {
    func handleIntervention(activeResource: String, associatedResource: String, type: Intervention)
    func handleResourceOpened(activeResource: String, associatedResource: String, type: Interaction)
    func handleWindowInteraction(type:Interaction)
}

extension ResourceWindowController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return associatedResources?.count ?? 0
    }
}

extension ResourceWindowController: NSTableViewDelegate, InterventionDelegate {
    
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
                    if resource.status == .confirmedDissimilar {
                        cell.textField?.stringValue = "-"
                    } else if resource.status == .confirmedSimilar {
                        cell.textField?.stringValue = "+"
                    } else if resource.status == .open {
                        cell.textField?.stringValue = String(format: "%.2f", resource.similarity)
                    }
                    return cell
                }
        } else if tableColumn == tableView.tableColumns[1] {
            if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: CellIdentifiers.SimInterventionCell), owner: nil) as? InterventionCellView {
                cell.button?.activeResourcePath = activeResource!
                cell.button?.associatedResource = resource
                cell.button?.intervention = .similar
                // cell.button?.isEnabled = resource.status == .open
                // cell.button?.isHidden = resource.status == .confirmedDissimilar
                cell.delegate = self
                return cell
            }
        } else if tableColumn == tableView.tableColumns[2] {
            if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: CellIdentifiers.DissimInterventionCell), owner: nil) as? InterventionCellView {
                cell.button?.activeResourcePath = activeResource!
                cell.button?.associatedResource = resource
                cell.button?.intervention = .dissimilar
                // cell.button?.isEnabled = resource.status == .open
                // cell.button?.isHidden = resource.status == .confirmedSimilar
                cell.delegate = self
                return cell
            }
        } else if tableColumn == tableView.tableColumns[3] {
            if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: CellIdentifiers.PathCell), owner: nil) as? NSTableCellView {
                cell.textField?.stringValue = getShortPath(resourcePath: resource.path)
                cell.imageView?.image = getFileIcon(resourcePath: resource.path)
                return cell
            }
        }
        return nil
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
    
    var delegate: ResourceControllerDelegate?
    
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
        
        delegate?.handleWindowInteraction(type: .openedRecommenderWindow)
    }
    
    func windowWillClose(_ notification: Notification) {
        delegate?.handleWindowInteraction(type: .closedRecommenderWindow)
    }
    
    func forwardIntervention(activeResource: String, associatedResource: String, type: Intervention) {
        delegate?.handleIntervention(activeResource: activeResource, associatedResource: associatedResource, type: type)
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
    
    private func getShortPath(resourcePath: String) -> String {
        guard let url = URL(string: resourcePath) else {
            return resourcePath
        }
        
        if url.isFileURL {
            return url.relativePath.replacingOccurrences(of: NSHomeDirectory(), with: "")
        }
        
        var path = url.absoluteString.replacingOccurrences(of: "http://www.", with: "")
        path = path.replacingOccurrences(of: "https://www.", with: "")
        path = path.replacingOccurrences(of: "http://", with: "")
        path = path.replacingOccurrences(of: "https://", with: "")
        return path
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
        activeResourceTextField.stringValue = getShortPath(resourcePath: activeResourcePath)
        
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
    
    @objc func handleTableDoubleClick() {
        let row = tableView.clickedRow
        let resource = associatedResources![row]
        if resource.path.starts(with: "file:///") {
            NSWorkspace.shared.openFile(resource.path)
        } else {
            // url
            if let url = URL(string: resource.path) {
                NSWorkspace.shared.open(url)
            }
        }
        
        delegate?.handleResourceOpened(activeResource: activeResource!, associatedResource: resource.path, type: .openedResource)
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
        }
    }
}
