//
//  PlayerView.swift
//  music
//
//  Created by Vinayak Vikram on 8/2/26.
//

import SwiftUI

struct PlayerView: View {
    @EnvironmentObject private var trackStore: TrackStore
    @EnvironmentObject private var playerManager: PlayerManager

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(playerManager.currentTrack ?? "Nothing playing")
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Button {
                    trackStore.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
            HStack {
                Button {
                    playerManager.togglePlayPause()
                } label: {
                    Image(systemName: playerManager.isPlaying ? "pause.fill" : "play.fill")
                }
                .disabled(playerManager.currentTrack == nil)

                Button {
                    playerManager.stop()
                } label: {
                    Image(systemName: "stop.fill")
                }
                .disabled(playerManager.currentTrack == nil)
            }
        }
        .padding(8)
        .frame(width: 220)
    }
}

#Preview {
    PlayerView()
        .environmentObject(TrackStore())
        .environmentObject(PlayerManager())
}
