//
//  musicApp.swift
//  music
//
//  Created by Vinayak Vikram on 8/2/26.
//

import SwiftUI

@main
struct musicApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        MenuBarExtra("music", systemImage: "music.note.list") {
            PlayerView()
        }
    }
}
