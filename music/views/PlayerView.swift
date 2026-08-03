//
//  PlayerView.swift
//  music
//
//  Created by Vinayak Vikram on 8/2/26.
//

import AppKit
import SwiftUI

private let playerWidth: CGFloat = 260
private let contentPadding: CGFloat = 12

struct PlayerView: View {
    @EnvironmentObject private var playerManager: PlayerManager

    private var artworkSize: CGFloat { playerWidth - contentPadding * 2 }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollingText(text: playerManager.displayTitle)

            if let artworkData = playerManager.artworkData, let image = NSImage(data: artworkData) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: artworkSize, height: artworkSize)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            VStack(spacing: 6) {
                Slider(
                    value: Binding(
                        get: { playerManager.currentTime },
                        set: { playerManager.seek(to: $0) }
                    ),
                    in: 0...max(playerManager.duration, 1)
                )
                .disabled(playerManager.currentTrack == nil)

                HStack(spacing: 12) {
                    Button {
                        playerManager.playPrevious()
                    } label: {
                        Image(systemName: "backward.fill")
                    }
                    .disabled(!playerManager.hasPrevious)

                    Button {
                        playerManager.togglePlayPause()
                    } label: {
                        Image(systemName: playerManager.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 18))
                            .frame(width: 40, height: 28)
                    }
                    .buttonStyle(.bordered)
                    .disabled(playerManager.currentTrack == nil)

                    Button {
                        playerManager.playNext()
                    } label: {
                        Image(systemName: "forward.fill")
                    }
                    .disabled(!playerManager.hasNext)
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }

            if let activePlaylist = playerManager.activePlaylist {
                Divider()

                Text(activePlaylist.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 4) {
                    ForEach(activePlaylist.tracks, id: \.self) { track in
                        Button {
                            playerManager.play(track, playlist: activePlaylist)
                        } label: {
                            HStack {
                                Text(resolvedTitle(for: track))
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                if track == playerManager.currentTrack {
                                    Spacer()
                                    Image(systemName: playerManager.isPlaying ? "speaker.wave.2.fill" : "pause.fill")
                                }
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else if !playerManager.recentTracks.isEmpty {
                Divider()

                Text("Recents")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 4) {
                    ForEach(playerManager.recentTracks, id: \.self) { track in
                        Button {
                            playerManager.play(track)
                        } label: {
                            Text(resolvedTitle(for: track))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(contentPadding)
        .frame(width: playerWidth, alignment: .leading)
    }
}

private struct ScrollingText: View {
    let text: String

    // repeatForever is gee so we have to use TimelineView
    @State private var startDate = Date()
    @State private var measuredTextWidth: CGFloat = 0 //measure manually later

    private var width: CGFloat { playerWidth - contentPadding * 2 }
    private let gap: CGFloat = 24
    private let scrollSpeed: CGFloat = 24 // points per second

    var body: some View {
        Group {
            if measuredTextWidth > width {
                TimelineView(.animation) { context in
                    let cycleDistance = measuredTextWidth + gap
                    let cycleDuration = Double(cycleDistance / scrollSpeed)
                    let elapsed = context.date.timeIntervalSince(startDate)
                    let progress = elapsed.truncatingRemainder(dividingBy: cycleDuration) / cycleDuration

                    HStack(spacing: gap) {
                        Text(text)
                        Text(text)
                    }
                    .fixedSize()
                    .offset(x: -CGFloat(progress) * cycleDistance)
                    .animation(nil, value: progress)
                }
            } else {
                Text(text)
            }
        }
        .font(.system(size: 11, weight: .regular, design: .monospaced))
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .background(
            Text(text)
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .fixedSize()
                .hidden()
                .background(
                    GeometryReader { proxy in
                        Color.clear
                            .onAppear { measuredTextWidth = proxy.size.width }
                            .onChange(of: proxy.size.width) { _, newValue in measuredTextWidth = newValue }
                    }
                )
        )
        .frame(width: width, alignment: .leading)
        .clipped()
        .onChange(of: text) { _, _ in startDate = Date() }
    }
}

#Preview {
    PlayerView()
        .environmentObject(PlayerManager())
}
