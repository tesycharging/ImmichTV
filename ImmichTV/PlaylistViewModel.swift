//
//  PlaylistViewModel.swift
//  ImmichTV
//
//  Created by David Lüthi on 21.08.2025.
//

import SwiftUI
import Foundation
import Combine
import AVKit
import AVFoundation

// AVPlayer UIViewControllerRepresentable for video playback
struct AVPlayerView: UIViewControllerRepresentable {
    let player: AVPlayer
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = false // Full-screen, no controls
        controller.videoGravity = .resizeAspectFill
        return controller
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {}
}

// ViewModel to manage playlist logic
class PlaylistViewModel: ObservableObject {
    @Published var currentIndex = 0
    let player = AVPlayer()
    private var playerMusic = AVPlayer()
    private var timer: Timer?
    private var isVideoPlaying = false
    private var timeToolbar: Timer?
    @Published var isBarVisible: Bool = true // Controls bar visibility
    @Published var showAlbumName = true
    @Published var running = true {
        didSet {
            UIApplication.shared.isIdleTimerDisabled = running
        }
    }
    
    // Play video
    func playVideo(url: URL, count: Int) {
        playerMusic.pause()
        let playerItem = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: playerItem)
        player.play()
        
        // Observe when video ends to move to next item
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            self?.playerMusic.play()
            print("play msuic after video is finished")
            self?.nextItem(count: count)
        }
    }
    
    // Play Musci
    func playMusicSetup(url: URL, autoplay: Bool = false) {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set up audio session: \(error)")
        }
        // Security-scoped resource access
        let shouldStopAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if shouldStopAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        let playerItem = AVPlayerItem(url: url)
        playerMusic = AVPlayer(playerItem: playerItem)
        // Configure audio session
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().setActive(true)
            print("music player ready to play")
        } catch {
            print("Failed to set up audio session: \(error)")
        }
        
        if autoplay {
            playerMusic.play()
            print("Auto-play music on appear")
        }
        
        // Observe when video ends to move to next item
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            self?.playerMusic.seek(to: .zero)
            self?.playerMusic.play()
            print("play music again")
        }
    }
    
    // Start timer for image display
    private func startImageTimer(duration: TimeInterval, count: Int) {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            self?.nextItem(count: count)
        }
    }
    
    // Move to next item in playlist
    func nextItem(count: Int) {
        currentIndex = (currentIndex + 1) % count
        timer?.invalidate()
        player.pause()
    }
    
    // Move to previous item in playlist
    func previousItem(count: Int) {
        currentIndex = (currentIndex - 1 + count) % count
        timer?.invalidate()
        player.pause()
    }
    
    // Pause Playlist
    func pause() {
        timer?.invalidate()
        player.pause()
        playerMusic.pause()
        print("pause music")
    }
    
    // Play Playlist
    func play(duration: TimeInterval, count: Int) {
        startImageTimer(duration: duration, count: count)
        playerMusic.play()
        print("play music")
    }
    
    deinit {
        timer?.invalidate()
        NotificationCenter.default.removeObserver(self)
        timeToolbar?.invalidate()
    }
    
    private var timeRemaining = 0 // Initial timer duration in seconds
    // Start the timer
    func showToolbar() {
        if isBarVisible {
            self.timeRemaining += 10
        } else {
            self.timeRemaining = 10
            isBarVisible = true
        }
        if timeToolbar == nil || !(timeToolbar?.isValid ?? true) {
            // Create a timer that fires every second
            timeToolbar = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                if self.timeRemaining > 0 {
                    self.timeRemaining = self.timeRemaining - 1
                } else {
                    self.isBarVisible = false
                    self.showAlbumName = false
                    self.timeToolbar?.invalidate()
                    self.timeToolbar = nil
                }
            }
        }
    }
    
    func hideToolbar() {
        timeToolbar?.invalidate()
        timeToolbar = nil
        isBarVisible = false
        self.showAlbumName = false
        self.timeRemaining = 0
    }
}

