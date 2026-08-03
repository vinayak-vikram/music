//
//  TrackGrouping.swift
//  music
//
//  Created by Vinayak Vikram on 8/3/26.
//

import Foundation

struct AlbumGroup: Identifiable {
    let id: String
    let tracks: [String]
}

struct LibraryGroup: Identifiable {
    let id: String
    let albums: [AlbumGroup]
    let singles: [String]
}

enum GroupingField {
    case composer
    case artist
}

func groupedLibrary(tracks: [String], by field: GroupingField) -> [LibraryGroup] {
    let index = loadTrackMetadataIndex()
    let unknownGroupName = field == .composer ? "Unknown Composer" : "Unknown Artist"

    var albumBuckets: [String: [String: [String]]] = [:]
    var singleBuckets: [String: [String]] = [:]

    for track in tracks {
        let metadata = index[track] ?? TrackMetadata()
        let groupKey = normalizedKey(field == .composer ? metadata.composer : metadata.artist, fallback: unknownGroupName)
        if let album = metadata.album, !album.trimmingCharacters(in: .whitespaces).isEmpty {
            albumBuckets[groupKey, default: [:]][album, default: []].append(track)
        } else {
            singleBuckets[groupKey, default: []].append(track)
        }
    }

    let groupNames = Set(albumBuckets.keys).union(singleBuckets.keys)

    return groupNames.map { groupName in
        let albums = (albumBuckets[groupName] ?? [:])
            .map { albumName, tracks in
                AlbumGroup(id: albumName, tracks: sortedByTrackNumber(tracks, index: index))
            }
            .sorted { $0.id.localizedStandardCompare($1.id) == .orderedAscending }

        let singles = (singleBuckets[groupName] ?? [])
            .sorted { resolvedTitle(for: $0).localizedStandardCompare(resolvedTitle(for: $1)) == .orderedAscending }

        return LibraryGroup(id: groupName, albums: albums, singles: singles)
    }
    .sorted { $0.id.localizedStandardCompare($1.id) == .orderedAscending }
}

private func normalizedKey(_ value: String?, fallback: String) -> String {
    guard let value, !value.trimmingCharacters(in: .whitespaces).isEmpty else { return fallback }
    return value
}

private func sortedByTrackNumber(_ tracks: [String], index: [String: TrackMetadata]) -> [String] {
    tracks.sorted { a, b in
        let numberA = index[a]?.trackNumber
        let numberB = index[b]?.trackNumber
        if let numberA, let numberB, numberA != numberB {
            return numberA < numberB
        }
        if (numberA == nil) != (numberB == nil) {
            return numberA != nil
        }
        return resolvedTitle(for: a).localizedStandardCompare(resolvedTitle(for: b)) == .orderedAscending
    }
}
