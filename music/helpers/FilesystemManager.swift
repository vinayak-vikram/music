//
//  FilesystemManager.swift
//  music
//
//  Created by Vinayak Vikram on 8/2/26.
//

import Foundation

func initFs() -> Int8 {
    guard let dataDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
        return 1
    }
    
    debugPrint(dataDirectory.path())

    let fileManager = FileManager.default
    let tracksURL = dataDirectory.appendingPathComponent("tracks")
    let listsURL = dataDirectory.appendingPathComponent("lists.json")
    let confURL = dataDirectory.appendingPathComponent("conf.json")

    do {
        if !fileManager.fileExists(atPath: tracksURL.path()) {
            try fileManager.createDirectory(at: tracksURL, withIntermediateDirectories: true)
        }
        if !fileManager.fileExists(atPath: listsURL.path()) {
            try "[]".write(to: listsURL, atomically: true, encoding: .utf8)
        }
        if !fileManager.fileExists(atPath: confURL.path()) {
            try "{}".write(to: confURL, atomically: true, encoding: .utf8)
        }
    } catch {
        return 1
    }

    if let tracks = try? fileManager.contentsOfDirectory(atPath: tracksURL.path()) {
        debugPrint(tracks)
    }
    if let lists = try? String(contentsOf: listsURL, encoding: .utf8) {
        debugPrint(lists)
    }
    if let conf = try? String(contentsOf: confURL, encoding: .utf8) {
        debugPrint(conf)
    }

    return 0
}

func listTracks() -> [String] {
    guard let dataDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
        return []
    }
    let tracksURL = dataDirectory.appendingPathComponent("tracks")
    return (try? FileManager.default.contentsOfDirectory(atPath: tracksURL.path())) ?? []
}
