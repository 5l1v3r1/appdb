//
//  IPAFileManager.swift
//  appdb
//
//  Created by ned on 28/04/2019.
//  Copyright © 2019 ned. All rights reserved.
//

import Foundation
import UIKit
import Swifter
import ZIPFoundation

struct LocalIPAFile: Equatable, Hashable {
    var filename: String = ""
    var size: String = ""
}

class IPAFileManager: NSObject {
    
    static var shared = IPAFileManager()
    private override init() { }
    
    fileprivate var localServer: HttpServer!
    fileprivate var backgroundTask: BackgroundTaskUtil? = nil
    
    func documentsDirectoryURL() -> URL {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    func inboxDirectoryURL() -> URL {
        return documentsDirectoryURL().appendingPathComponent("Inbox")
    }
    
    func url(for ipa: LocalIPAFile) -> URL {
        return documentsDirectoryURL().appendingPathComponent(ipa.filename)
    }
    
    func rename(file: LocalIPAFile, to: String) {
        // todo handle error
        guard FileManager.default.fileExists(atPath: documentsDirectoryURL().appendingPathComponent(file.filename).path) else { return }
        let startURL = documentsDirectoryURL().appendingPathComponent(file.filename)
        let endURL = documentsDirectoryURL().appendingPathComponent(to)
        try! FileManager.default.moveItem(at: startURL, to: endURL)
    }
    
    func delete(file: LocalIPAFile) {
        // todo handle error
        guard FileManager.default.isDeletableFile(atPath: documentsDirectoryURL().appendingPathComponent(file.filename).path) else { return }
        try! FileManager.default.removeItem(at: documentsDirectoryURL().appendingPathComponent(file.filename))
    }
    
    func getSize(from filename: String) -> String {
        let url = documentsDirectoryURL().appendingPathComponent(filename)
        guard FileManager.default.fileExists(atPath: url.path) else { return "" }
        do {
            let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey])
            guard let fileSize = resourceValues.fileSize else { return "" }
            return Global.humanReadableSize(bytes: Double(fileSize))
        } catch {
            return ""
        }
    }
    
    func base64ToJSONInfoPlist(from file: LocalIPAFile) -> String {
        let ipaUrl = documentsDirectoryURL().appendingPathComponent(file.filename)
        guard FileManager.default.fileExists(atPath: ipaUrl.path) else { debugLog("no ipa"); return "" }
        let randomName = Global.randomString(length: 5)
        let tmp = documentsDirectoryURL().appendingPathComponent(randomName, isDirectory: true)
        if FileManager.default.fileExists(atPath: tmp.path) { try! FileManager.default.removeItem(atPath: tmp.path) }
        try! FileManager.default.createDirectory(atPath: tmp.path, withIntermediateDirectories: true, attributes: nil)
        try! FileManager.default.unzipItem(at: ipaUrl, to: tmp)
        let payload = tmp.appendingPathComponent("Payload", isDirectory: true)
        guard FileManager.default.fileExists(atPath: payload.path) else { debugLog("no payload"); return "" }
        let contents = try! FileManager.default.contentsOfDirectory(at: payload, includingPropertiesForKeys: nil)
        guard let dotApp = contents.filter({ $0.pathExtension == "app" }).first else { debugLog("no .app"); return "" }
        let infoPlist = dotApp.appendingPathComponent("Info.plist", isDirectory: false)
        guard FileManager.default.fileExists(atPath: infoPlist.path) else { debugLog("no info plist"); return "" }
        guard let dict = NSDictionary(contentsOfFile: infoPlist.path) else { debugLog("not a dict"); return "" }
        let jsonData = try! JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted)
        guard let jsonString = String(data: jsonData, encoding: String.Encoding.utf8) else { debugLog("cant encode"); return "" }
        try! FileManager.default.removeItem(atPath: tmp.path)
        return jsonString.toBase64()
    }
    
    func moveEventualIPAFilesToDocumentsDirectory(from directory: URL) {
        guard FileManager.default.fileExists(atPath: directory.path) else { return }
        let inboxContents = try! FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        let ipas = inboxContents.filter{ $0.pathExtension == "ipa" }
        for ipa in ipas {
            let startURL = directory.appendingPathComponent(ipa.lastPathComponent)
            var endURL = documentsDirectoryURL().appendingPathComponent(ipa.lastPathComponent)
            
            if !FileManager.default.fileExists(atPath: endURL.path) {
                try! FileManager.default.moveItem(at: startURL, to: endURL)
            } else {
                var i: Int = 0
                while FileManager.default.fileExists(atPath: endURL.path) {
                    i += 1
                    let newName = ipa.deletingPathExtension().lastPathComponent + "_\(i).ipa"
                    endURL = documentsDirectoryURL().appendingPathComponent(newName)
                }
                try! FileManager.default.moveItem(at: startURL, to: endURL)
            }
        }
    }
    
    func listLocalIpas() -> [LocalIPAFile] {
        var result = [LocalIPAFile]()

        moveEventualIPAFilesToDocumentsDirectory(from: inboxDirectoryURL())
        
        let contents = try! FileManager.default.contentsOfDirectory(at: documentsDirectoryURL(), includingPropertiesForKeys: nil)
        let ipas = contents.filter{ $0.pathExtension == "ipa" }
        for ipa in ipas {
            let filename = ipa.lastPathComponent
            let size = getSize(from: filename)
            let ipa = LocalIPAFile(filename: filename, size: size)
            if !result.contains(ipa) { result.append(ipa) }
        }
        result = result.sorted{ $0.filename.localizedStandardCompare($1.filename) == .orderedAscending }
        return result
    }
}

protocol LocalIPAServer {
    mutating func startServer()
    func stopServer()
}

extension IPAFileManager: LocalIPAServer {
    
    func getIpaLocalUrl(from ipa: LocalIPAFile) -> String {
         return "http://127.0.0.1:8080/\(ipa.filename)"
    }
    
    func startServer() {
        localServer = HttpServer()
        localServer["/:path"] = shareFilesFromDirectory(documentsDirectoryURL().path)
        do {
            try localServer.start(8080)
            backgroundTask = BackgroundTaskUtil()
            backgroundTask?.start()
        } catch {
            stopServer()
        }
    }
    
    func stopServer() {
        localServer.stop()
        backgroundTask = nil
    }
}
