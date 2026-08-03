//
//  PlayerView.swift
//  music
//
//  Created by Vinayak Vikram on 8/2/26.
//

import SwiftUI

private let playerWidth: CGFloat = 220
private let contentPadding: CGFloat = 6
private let visibleTitleCharacters = 20

struct PlayerView: View {
    @EnvironmentObject private var playerManager: PlayerManager

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollingText(text: playerManager.displayTitle)

            HStack(spacing: 16) {
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
        .padding(contentPadding)
        .frame(width: playerWidth, alignment: .leading)
    }
}

private struct ScrollingText: View {
    let text: String

    @State private var offset: CGFloat = 0

    private var width: CGFloat { playerWidth - contentPadding * 2 }

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .regular, design: .monospaced))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .fixedSize()
            .offset(x: offset)
            .frame(width: width, alignment: .leading)
            .clipped()
            .onAppear(perform: startScrolling)
            .onChange(of: text) { _, _ in startScrolling() }
    }

    private func startScrolling() {
        offset = 0
        let overflowCharacters = text.count - visibleTitleCharacters
        guard overflowCharacters > 0 else { return }
        let distance = CGFloat(overflowCharacters) * (width / CGFloat(visibleTitleCharacters))
        withAnimation(.linear(duration: Double(overflowCharacters) * 0.3).repeatForever(autoreverses: false)) {
            offset = -distance
        }
    }
}

#Preview {
    PlayerView()
        .environmentObject(PlayerManager())
}
