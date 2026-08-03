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

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(trackStore)
        }
        MenuBarExtra("music", systemImage: "music.note.list") {
            PlayerView()
                .environmentObject(trackStore)
        }
    }
}
