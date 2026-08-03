//
//  TrackStore.swift
//  music
//
//  Created by Vinayak Vikram on 8/2/26.
//

import Combine
import Foundation

@MainActor
final class TrackStore: ObservableObject {
    // TODO: smth smth memory efficiency+blah
    @Published private(set) var tracks: [String] = []

    func refresh() {
        _ = initFs()
        tracks = listTracks()
    }
}
