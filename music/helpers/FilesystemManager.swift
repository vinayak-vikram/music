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

func tracksDirectoryURL() -> URL? {
    FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("tracks")
}

func listTracks() -> [String] {
    guard let tracksURL = tracksDirectoryURL() else { return [] }
    let contents = (try? FileManager.default.contentsOfDirectory(atPath: tracksURL.path())) ?? []
    return contents.filter { $0.lowercased().hasSuffix(".mp3") }
}

@discardableResult
func importTrack(from sourceURL: URL) -> Bool {
    guard let tracksURL = tracksDirectoryURL() else { return false }
    let destinationURL = tracksURL.appendingPathComponent(sourceURL.lastPathComponent)

    let didStartAccessing = sourceURL.startAccessingSecurityScopedResource()
    defer {
        if didStartAccessing {
            sourceURL.stopAccessingSecurityScopedResource()
        }
    }

    do {
        if FileManager.default.fileExists(atPath: destinationURL.path()) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
        return true
    } catch {
        return false
    }
}
