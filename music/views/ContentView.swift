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
    @State private var isShowingImportError = false
    @State private var isShowingMetadataEditor = false
    @State private var trackBeingEdited = ""

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
                .contextMenu {
                    Button("Edit Metadata…") {
                        trackBeingEdited = track
                        isShowingMetadataEditor = true
                    }
                }
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
            allowedContentTypes: [.audio, .movie],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                if importTrack(from: url) {
                    trackStore.refresh()
                } else {
                    isShowingImportError = true
                }
            }
        }
        .alert("Couldn't Add Track", isPresented: $isShowingImportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("install ffmpeg (via brew, etc.)")
        }
        .sheet(isPresented: $isShowingMetadataEditor) {
            MetadataEditView(track: trackBeingEdited)
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
