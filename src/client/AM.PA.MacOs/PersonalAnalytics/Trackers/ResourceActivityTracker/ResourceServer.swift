//
//  ResourceServer.swift
//  PersonalAnalytics
//
//  Created by Roy Rutishauser on 12.10.20.
//

import Foundation
import Swifter

protocol ResourceServerDelegate: AnyObject {
    func getRecentlyUsedResources() -> [String]
    func getContextResources(path: String) -> [AssociatedResource]
}

fileprivate struct Group: Codable {
    let id: String
    let name: String
    let type: String
    let created: Date
    let artefacts: [Artefact]
}

fileprivate struct Artefact: Codable {
    let id: String
    let path: String
    let created: Date
}

fileprivate struct Context: Codable {
    let id: String
    let path: String
    let created: Date
    let similarity: Float
}

class ResourceServer {

    var delegate: ResourceServerDelegate?
    let server = HttpServer()
    
    @objc func getState() {
        print(server.state)
    }
    
    init() {
        
//        var applicationTimer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(getState), userInfo: nil, repeats: true)

        server["/hello"] = { .ok(.htmlBody("You asked for \($0)")) }
        
        server["/groups"] = { request in
            do {
                let g = try self.groups()
                
                return HttpResponse.raw(200, "OK", ["Content-Type": "application/json", "Access-Control-Allow-Origin": "*"], { try $0.write([UInt8](g.utf8)) })
            } catch {
                print(error)
                return HttpResponse.internalServerError
            }
        }
        
        struct Body: Codable {
            let path: String
        }
      
        server["/contexts"] = { request in
            do {
                let jsonDecoder = JSONDecoder()
                let body = try jsonDecoder.decode(Body.self, from: Data(bytes: request.body))
                
                let c = try self.contexts(path: body.path)
                 return HttpResponse.raw(200, "OK", ["Content-Type": "application/json", "Access-Control-Allow-Origin": "*"], { try $0.write([UInt8] (c.utf8)) })
            } catch {
                print(error)
                return HttpResponse.internalServerError
            }
        }
        
        do {
            try server.start(3456, forceIPv4: true)
            print("Server has started (port = \(try server.port())). Try to connect now...")
        } catch {
            print(error)
        }
    }
    
    func contexts(path: String) throws -> String {
        let contexts = delegate?.getContextResources(path: path).map { Context(id: "asdf", path: $0.path, created: Date(), similarity: $0.similarity) } ?? []
        
        let jsonEncoder = JSONEncoder()
        let data = try jsonEncoder.encode(contexts)
        return String(data: data, encoding: .utf8)!
    }

    private func groups() throws -> String {
        let recentlyAddedArtefacts = delegate?.getRecentlyUsedResources().map { Artefact(id: "-", path: $0, created: Date()) }
        let recentlyAddedGroup = Group(id: "", name: "Recently Used", type: "smart", created: Date(), artefacts: recentlyAddedArtefacts ?? [])

        let jsonEncoder = JSONEncoder()
        let data = try jsonEncoder.encode([recentlyAddedGroup])
        return String(data: data, encoding: .utf8)!
    }
}
