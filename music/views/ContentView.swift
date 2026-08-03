//
//  ContentView.swift
//  music
//
//  Created by Vinayak Vikram on 8/2/26.
//

import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var trackStore: TrackStore
    @EnvironmentObject private var playerManager: PlayerManager

    @State private var isShowingAddSourceSheet = false
    @State private var isShowingFileImporter = false

    var body: some View {
        VStack {
            HStack {
                Button {
                    isShowingAddSourceSheet = true
                } label: {
                    Image(systemName: "plus")
                }
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
        .sheet(isPresented: $isShowingAddSourceSheet) {
            AddTrackSourceView {
                isShowingAddSourceSheet = false
                isShowingFileImporter = true
            }
        }
        .fileImporter(
            isPresented: $isShowingFileImporter,
            allowedContentTypes: [.mp3],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                importTrack(from: url)
                trackStore.refresh()
            }
        }
    }
}

private struct AddTrackSourceView: View {
    let onSelectDisk: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Add Track From")
                .font(.headline)
            Button("Disk") {
                onSelectDisk()
            }
        }
        .padding()
        .frame(width: 240)
    }
}

#Preview {
    ContentView()
        .environmentObject(TrackStore())
        .environmentObject(PlayerManager())
}
