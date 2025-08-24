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
    @ObservedObject var playlistModel: PlaylistViewModel // Binding to control visibility of playback controls
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = playlistModel.showVideoControls // Set initial control visibility
        controller.videoGravity = .resizeAspectFill
        return controller
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        // Update control visibility when showControls changes
        uiViewController.showsPlaybackControls = playlistModel.showVideoControls
    }
}

// ViewModel to manage playlist logic
class PlaylistViewModel: ObservableObject {
    @Published var currentIndex = 0
    private var observerMusic: Any?
    private var observerVideo: Any?
    let player = AVPlayer()
    var playerMusic = AVPlayer()
    private var timer: Timer?
    private var isVideoPlaying = false
    private var timeRemaining = 0 // Initial timer duration in seconds
    private var timeToolbar: Timer?
    private var hasVideoContronls = false
    @Published var showVideoControls = false // Controls video buttons visibilty
    @Published var isBarVisible: Bool = false // Controls bar visibility
    @Published var showAlbumName = true
    @Published var running = true {
        didSet {
            UIApplication.shared.isIdleTimerDisabled = running
        }
    }
    
    // Play video
    func playVideo(url: URL, count: Int) {
        playerMusic.pause()
        timer?.invalidate()
        let playerItem = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: playerItem)
        isVideoPlaying = true
        player.play()
        print("play video")
        
        //remove the observer from the last video
        if let observer = self.observerVideo {
            NotificationCenter.default.removeObserver(observer)
        }
        // Observe when video ends to move to next item
        observerVideo = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            if self?.running ?? false {
                self?.nextItem(count: count)
            } else {
                self?.player.seek(to: .zero)
                self?.player.play()
            }
        }
    }
    
    // Play Music
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
        observerMusic = NotificationCenter.default.addObserver(
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
    func startImageTimer(duration: TimeInterval, count: Int) {
        playerMusic.play()
        print("play music")
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            self?.nextItem(count: count)
        }
    }
    
    // Move to next item in playlist
    func nextItem(count: Int) {
        player.pause()
        isVideoPlaying = false
        timer?.invalidate()
        currentIndex = (currentIndex + 1) % count
    }
    
    // Move to previous item in playlist
    func previousItem(count: Int) {
        player.pause()
        isVideoPlaying = false
        timer?.invalidate()
        currentIndex = (currentIndex - 1 + count) % count
    }
    
    // Pause Playlist
    func pausePlaylist() {
        running = false
        player.pause()
        isVideoPlaying = false
        timer?.invalidate()
        playerMusic.pause()
        print("pause music")
    }
    
    func deinitPlaylist() {
        pausePlaylist()
        if let observer = self.observerVideo {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = self.observerMusic {
            NotificationCenter.default.removeObserver(observer)
        }
        NotificationCenter.default.removeObserver(self)
        timeToolbar?.invalidate()
    }
    
    deinit {
        deinitPlaylist()
    }
    
    // Start the timer
    func showToolbar() {
        if isBarVisible {
            self.timeRemaining += 10
        } else {
            self.timeRemaining = 10
            if isVideoPlaying && hasVideoContronls {
                showVideoControls = true
            } else {
                isBarVisible = true
            }
        }
        if timeToolbar == nil || !(timeToolbar?.isValid ?? true) {
            // Create a timer that fires every second
            timeToolbar = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                if self.timeRemaining > 0 {
                    self.timeRemaining = self.timeRemaining - 1
                } else {
                    self.hideToolbar()
                }
            }
        }
    }
    
    func hideToolbar() {
        self.isBarVisible = false
        self.showAlbumName = false
        self.hasVideoContronls.toggle()
        self.showVideoControls = false
        self.timeToolbar?.invalidate()
        self.timeToolbar = nil
        self.timeRemaining = 0
    }
}

