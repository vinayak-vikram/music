//
//  TrackIndex.swift
//  music
//
//  Created by Vinayak Vikram on 8/3/26.
//

import Foundation

private struct TrackIndexEntry: Codable {
    var metadata: TrackMetadata
    var fileSize: Int
    var modifiedAt: Double
}

private func tracksIndexURL() -> URL? {
    dataDirectoryURL()?.appendingPathComponent("tracks.json")
}

private func loadIndex() -> [String: TrackIndexEntry] {
    guard let url = tracksIndexURL(),
          let data = try? Data(contentsOf: url),
          let index = try? JSONDecoder().decode([String: TrackIndexEntry].self, from: data)
    else { return [:] }
    return index
}

private func saveIndex(_ index: [String: TrackIndexEntry]) {
    guard let url = tracksIndexURL(), let data = try? JSONEncoder().encode(index) else { return }
    try? data.write(to: url, options: .atomic)
}

private func fingerprint(for track: String) -> (size: Int, modifiedAt: Double)? {
    guard let url = tracksDirectoryURL()?.appendingPathComponent(track),
          let attributes = try? FileManager.default.attributesOfItem(atPath: url.path())
    else { return nil }
    let size = (attributes[.size] as? Int) ?? 0
    let modifiedAt = (attributes[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
    return (size, modifiedAt)
}

@discardableResult
func updateIndex(for track: String, metadata: TrackMetadata) -> Bool {
    guard let fingerprint = fingerprint(for: track) else { return false }
    var index = loadIndex()
    index[track] = TrackIndexEntry(metadata: metadata, fileSize: fingerprint.size, modifiedAt: fingerprint.modifiedAt)
    saveIndex(index)
    return true
}

func removeFromIndex(_ track: String) {
    var index = loadIndex()
    index.removeValue(forKey: track)
    saveIndex(index)
}

@discardableResult
func verifyIndex(for track: String) -> TrackMetadata {
    guard let currentFingerprint = fingerprint(for: track) else { return TrackMetadata() }

    var index = loadIndex()
    if let entry = index[track], entry.fileSize == currentFingerprint.size, entry.modifiedAt == currentFingerprint.modifiedAt {
        return entry.metadata
    }

    let metadata = loadMetadata(for: track)
    index[track] = TrackIndexEntry(metadata: metadata, fileSize: currentFingerprint.size, modifiedAt: currentFingerprint.modifiedAt)
    saveIndex(index)
    return metadata
}
