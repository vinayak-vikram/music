//
//  TrackMetadata.swift
//  music
//
//  Created by Vinayak Vikram on 8/3/26.
//

import Foundation

struct TrackMetadata: Equatable, Codable {
    var title: String? = nil
    var artist: String? = nil
    var album: String? = nil
    var trackNumber: Int? = nil
    var year: Int? = nil
    var genre: String? = nil
    var composer: String? = nil
}

private struct FFProbeOutput: Decodable {
    struct Format: Decodable {
        var tags: [String: String]?
    }
    var format: Format
}

func loadMetadata(for track: String) -> TrackMetadata {
    guard let url = tracksDirectoryURL()?.appendingPathComponent(track) else { return TrackMetadata() }

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/zsh")
    process.arguments = [
        "-lc", "exec ffprobe \"$@\"", "ffprobe",
        "-v", "error",
        "-show_entries", "format_tags",
        "-of", "json",
        url.path,
    ]
    let outputPipe = Pipe()
    process.standardOutput = outputPipe
    process.standardError = FileHandle.nullDevice

    do {
        try process.run()
        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return TrackMetadata() }

        let tags = try JSONDecoder().decode(FFProbeOutput.self, from: data).format.tags ?? [:]
        return TrackMetadata(
            title: tagValue("title", in: tags),
            artist: tagValue("artist", in: tags),
            album: tagValue("album", in: tags),
            trackNumber: tagValue("track", in: tags).flatMap { Int($0.split(separator: "/").first.map(String.init) ?? "") },
            year: tagValue("date", in: tags).flatMap { Int($0.prefix(4)) },
            genre: tagValue("genre", in: tags),
            composer: tagValue("composer", in: tags)
        )
    } catch {
        return TrackMetadata()
    }
}

@discardableResult
func saveMetadata(_ metadata: TrackMetadata, for track: String) -> Bool {
    guard let tracksURL = tracksDirectoryURL() else { return false }
    let originalURL = tracksURL.appendingPathComponent(track)
    let tempURL = tracksURL.appendingPathComponent(".\(UUID().uuidString).mp3")

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/zsh")
    process.arguments = ["-lc", "exec ffmpeg \"$@\"", "ffmpeg", "-y", "-i", originalURL.path, "-c", "copy"]
        + metadataArguments(for: metadata)
        + [tempURL.path]
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice

    do {
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            try? FileManager.default.removeItem(at: tempURL)
            return false
        }
        _ = try FileManager.default.replaceItemAt(originalURL, withItemAt: tempURL)
        updateIndex(for: track, metadata: metadata)
        return true
    } catch {
        try? FileManager.default.removeItem(at: tempURL)
        return false
    }
}

private func metadataArguments(for metadata: TrackMetadata) -> [String] {
    let fields: [(String, String?)] = [
        ("title", metadata.title),
        ("artist", metadata.artist),
        ("album", metadata.album),
        ("track", metadata.trackNumber.map(String.init)),
        ("date", metadata.year.map(String.init)),
        ("genre", metadata.genre),
        ("composer", metadata.composer),
    ]
    return fields.flatMap { key, value in ["-metadata", "\(key)=\(value ?? "")"] }
}

private func tagValue(_ key: String, in tags: [String: String]) -> String? {
    guard let value = tags.first(where: { $0.key.caseInsensitiveCompare(key) == .orderedSame })?.value,
          !value.isEmpty else { return nil }
    return value
}
