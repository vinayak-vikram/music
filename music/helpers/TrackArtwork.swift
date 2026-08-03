//
//  TrackArtwork.swift
//  music
//
//  Created by Vinayak Vikram on 8/3/26.
//

import Foundation

func extractArtwork(for track: String) -> Data? {
    guard let url = tracksDirectoryURL()?.appendingPathComponent(track) else { return nil }
    let tempURL = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension("jpg")
    defer { try? FileManager.default.removeItem(at: tempURL) }

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/zsh")
    process.arguments = [
        "-lc", "exec ffmpeg \"$@\"", "ffmpeg",
        "-y", "-i", url.path,
        "-an", "-codec:v", "copy", "-update", "1", "-frames:v", "1",
        tempURL.path,
    ]
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice

    do {
        try process.run()
        process.waitUntilExit()
    } catch {
        return nil
    }
    guard process.terminationStatus == 0 else { return nil }
    return try? Data(contentsOf: tempURL)
}
