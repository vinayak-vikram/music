//
//  PlayerManager.swift
//  music
//
//  Created by Vinayak Vikram on 8/3/26.
//

import AVFoundation
import Combine
import MediaPlayer

@MainActor
final class PlayerManager: NSObject, ObservableObject {
    private static let maxRecentTracks = 6

    @Published private(set) var currentTrack: String?
    @Published private(set) var isPlaying = false
    @Published private(set) var recentTracks: [String] = []

    private var player: AVPlayer?
    private var endObserver: NSObjectProtocol?

    var displayTitle: String {
        guard let currentTrack else { return "Nothing playing" }
        return resolvedTitle(for: currentTrack)
    }

    override init() {
        super.init()
        configureRemoteCommands()
    }

    func play(_ track: String) {
        guard let url = tracksDirectoryURL()?.appendingPathComponent(track) else { return }

        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }

        let player = AVPlayer(url: url)
        self.player = player
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.isPlaying = false
                self?.updateNowPlayingInfo()
            }
        }

        player.play()
        currentTrack = track
        isPlaying = true
        recordRecentlyPlayed(track)
        verifyIndex(for: track)
        updateNowPlayingInfo()
    }

    private func recordRecentlyPlayed(_ track: String) {
        recentTracks.removeAll { $0 == track }
        recentTracks.insert(track, at: 0)
        recentTracks = Array(recentTracks.prefix(Self.maxRecentTracks))
    }

    func togglePlayPause() {
        guard let player else { return }
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
        isPlaying.toggle()
        updateNowPlayingInfo()
    }

    func stop() {
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
        player?.pause()
        player = nil
        currentTrack = nil
        isPlaying = false
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    private func configureRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()

        center.playCommand.addTarget { [weak self] _ in
            guard let self, let player = self.player else { return .noSuchContent }
            player.play()
            self.isPlaying = true
            self.updateNowPlayingInfo()
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            guard let self, let player = self.player else { return .noSuchContent }
            player.pause()
            self.isPlaying = false
            self.updateNowPlayingInfo()
            return .success
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            guard let self, self.player != nil else { return .noSuchContent }
            self.togglePlayPause()
            return .success
        }
        center.stopCommand.addTarget { [weak self] _ in
            guard let self, self.player != nil else { return .noSuchContent }
            self.stop()
            return .success
        }
    }

    // for control center, notif screen, etc
    private func updateNowPlayingInfo() {
        guard let currentTrack, let player else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }

        var info: [String: Any] = [
            MPMediaItemPropertyTitle: displayTitle,
            MPNowPlayingInfoPropertyPlaybackRate: player.rate,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: player.currentTime().seconds,
        ]
        if let duration = player.currentItem?.duration.seconds, duration.isFinite {
            info[MPMediaItemPropertyPlaybackDuration] = duration
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}
