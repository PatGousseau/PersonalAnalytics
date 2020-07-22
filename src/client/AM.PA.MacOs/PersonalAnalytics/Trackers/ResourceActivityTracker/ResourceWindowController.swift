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
    
    init(path: String) {
        self.path = path
        self.status = .open
    }
    
    init(path: String, status: InterventionStatus) {
        self.path = path
        self.status = status
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
}

extension ResourceWindowController: NSTableViewDataSource {
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return associatedResources?.count ?? 0
    }
}

extension ResourceWindowController: NSTableViewDelegate, InterventionDelegate {
    
    fileprivate enum CellIdentifiers {
        static let SimCell = "SimCellID"
        static let DissimCell = "DissimCellID"
        static let PathCell = "PathCellID"
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        
        // anything to show?
        guard let resource = associatedResources?[row] else {
            return nil
        }
        
        // populate data
        if tableColumn == tableView.tableColumns[0] {
            if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: CellIdentifiers.SimCell), owner: nil) as? InterventionCellView {
                cell.button?.activeResourcePath = activeResource!
                cell.button?.associatedResource = resource
                cell.button?.intervention = .similar
                cell.button?.isEnabled = resource.status == .open
                cell.button?.isHidden = resource.status == .confirmedDissimilar
                cell.delegate = self
                return cell
            }
        } else if tableColumn == tableView.tableColumns[1] {
            if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: CellIdentifiers.DissimCell), owner: nil) as? InterventionCellView {
                cell.button?.activeResourcePath = activeResource!
                cell.button?.associatedResource = resource
                cell.button?.intervention = .dissimilar
                cell.button?.isEnabled = resource.status == .open
                cell.button?.isHidden = resource.status == .confirmedSimilar
                cell.delegate = self
                return cell
            }
        } else if tableColumn == tableView.tableColumns[2] {
            if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: CellIdentifiers.PathCell), owner: nil) as? NSTableCellView {
                cell.textField?.stringValue = resource.path
                return cell
            }
        }
        return nil
    }
}

class ResourceWindowController: NSWindowController {
    
    // MARK: IBOutlets
    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var activeResourceTextField: NSTextFieldCell!
    @IBOutlet weak var associatedResourcesCountTextField: NSTextFieldCell!
    @IBOutlet weak var activeAppTextField: NSTextField!
    @IBOutlet weak var activeAppIcon: NSImageView!
    @IBOutlet weak var toggleOnOffCheckbox: NSButton!
    
    @IBAction func onToggleOnOffCheck(_ sender: NSButton) {
        if toggleOnOffCheckbox.state == .on {
            turnRecommendationsOn()
        } else {
            turnRecommendationsOff()
        }
    }
    
    private var associatedResources: [AssociatedResource]?
    private var activeResource: String?
    private var currentActiveTableRow: Int = 0
    private(set) var isRecommendationEnabled = false
    
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
    
    private func turnRecommendationsOff() {
        isRecommendationEnabled = false
        activeAppTextField.stringValue = ""
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
            
    func setActiveResource(activeResourcePath: String, activeAppName: String, activeAppIcon icon: NSImage?, associatedResources: [AssociatedResource]) {
                
        activeAppTextField.stringValue = activeAppName
        activeAppIcon.image = icon
        
        if activeResourcePath == "" {
            tableView.isHidden = true
            activeResourceTextField.stringValue = "unknown"
            return
        }
        
        tableView.isHidden = false
        activeResourceTextField.stringValue = activeResourcePath
        
        
        self.associatedResources = associatedResources
        self.activeResource = activeResourcePath
        self.tableView.reloadData()
    }
    
    func setLoadingResource(activeAppName: String, activeAppIcon icon: NSImage?) {
        activeAppTextField.stringValue = activeAppName
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
