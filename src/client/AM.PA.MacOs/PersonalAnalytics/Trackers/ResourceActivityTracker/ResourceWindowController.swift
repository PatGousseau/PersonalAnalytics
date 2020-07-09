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
    fileprivate var associatedResource: SimilarResource?
    var intervention: Intervention?
}

fileprivate enum InterventionStatus {
    case confirmedDissimilar
    case confirmedSimilar
    case open
}

fileprivate class SimilarResource {
    let path: String
    var status: InterventionStatus
    
    init(path: String) {
        self.path = path
        self.status = .open
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
        return similarResources?.count ?? 0
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
        guard let resource = similarResources?[row] else {
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
    
    private var similarResources: [SimilarResource]?
    private var activeResource: String?
        
    var delegate: ResourceControllerDelegate?
    
    override func windowDidLoad() {
        super.windowDidLoad()
        
        // if let window = window {
        //     window.styleMask.remove(.titled)
        //     window.styleMask.remove(.miniaturizable)
        //     window.styleMask.remove(.resizable)
        //     if let view = window.contentView {}
        // }
        
        tableView.delegate = self
        tableView.dataSource = self
        
        tableView.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        tableView.doubleAction = #selector(handleTableDoubleClick)
    }
    
    func forwardIntervention(activeResource: String, associatedResource: String, type: Intervention) {
        
        delegate?.handleIntervention(activeResource: activeResource, associatedResource: associatedResource, type: type)
        
        // if (type == .DissimilarityIntervention) {
        //     // filtering the dissimilar resource from the table view
        //     similarResources = similarResources!.filter { $0 != associatedResource }
        //     tableView.reloadData()
        // }
        
    
        tableView.reloadData()
    }
        
    @objc func show(_ sender: AnyObject) {
        NSApp.activate(ignoringOtherApps: true)
        showWindow(self)
        // self.window?.makeKeyAndOrderFront(self)
    }
    
    func setActiveResource(name: String, simResources: [String]) {
        if name == "" {
            tableView.isHidden = true
            activeResourceTextField.stringValue = "no resource active"
        } else {
            tableView.isHidden = false
            activeResourceTextField.stringValue = name
        }
        
        
        similarResources = simResources.map { SimilarResource(path: $0)}
        activeResource = name
        tableView.reloadData()
    }
    
    @objc func handleTableDoubleClick() {
        let row = tableView.clickedRow
        let resource = similarResources![row]
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
        print("TODO: check which row is selected and listen to Y (sim) and N (dissim) keystrokes. Handle accordingly")
    }
}
