//
//  ContentView.swift
//  music
//
//  Created by Vinayak Vikram on 8/2/26.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var trackStore: TrackStore
    @EnvironmentObject private var playerManager: PlayerManager

    var body: some View {
        VStack {
            HStack {
                Spacer()
                Button {
                    trackStore.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
            List(trackStore.tracks, id: \.self) { track in
                Button {
                    playerManager.play(track)
                } label: {
                    HStack {
                        Text(track)
                        if track == playerManager.currentTrack {
                            Spacer()
                            Image(systemName: playerManager.isPlaying ? "speaker.wave.2.fill" : "pause.fill")
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .onAppear {
            trackStore.refresh()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(TrackStore())
        .environmentObject(PlayerManager())
}
