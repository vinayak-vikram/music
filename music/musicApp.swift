//
//  musicApp.swift
//  music
//
//  Created by Vinayak Vikram on 8/2/26.
//

import SwiftUI

@main
struct musicApp: App {
    @StateObject private var trackStore = TrackStore()
    @StateObject private var playerManager = PlayerManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(trackStore)
                .environmentObject(playerManager)
        }
        MenuBarExtra("music", systemImage: "music.note.list") {
            PlayerView()
                .environmentObject(playerManager)
        }
        .menuBarExtraStyle(.window)
    }
}
