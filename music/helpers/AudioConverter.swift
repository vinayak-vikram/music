//
//  AudioConverter.swift
//  music
//
//  Created by Vinayak Vikram on 8/3/26.
//

import Foundation

func convertToMp3(sourceURL: URL, destinationURL: URL) -> Bool {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/zsh")
    process.arguments = [
        "-lc", "exec ffmpeg \"$@\"", "ffmpeg",
        "-y", "-i", sourceURL.path,
        "-vn", "-codec:a", "libmp3lame", "-q:a", "2",
        destinationURL.path,
    ]
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice

    do {
        try process.run()
        process.waitUntilExit()
        return process.terminationStatus == 0 && FileManager.default.fileExists(atPath: destinationURL.path())
    } catch {
        return false
    }
}
