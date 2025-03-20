//
//  SlideshowView.swift
//  ImmichTV
//
//  Created by David Lüthi on 17.03.2025.
//

import SwiftUI
import AVKit

struct SlideshowView: View {
    let album: Album?
    let search: Bool
    @State private var startSlideShow: Bool
    @State private var assetItems: [AssetItem] = []
    @StateObject private var immichService = ImmichService()
    @State private var currentIndex = 0
    @State private var isLoading = true
    @State private var timer: Timer?
    @State private var showAlbumName = false
    @State private var thumbnail = true
    @State private var isBarVisible: Bool = true // Controls bar visibility
    @FocusState private var focusedButton: String?
    @State private var player: AVPlayer?
    @State private var isVideoFinished = false
    @State private var remoting = false
    @Environment(\.dismiss) private var dismiss // For dismissing the full-screen view
        
    
    init(album: Album) {
        self.album = album
        self.search = false
        self.assetItems = []
        self.startSlideShow = true
    }
    
    init(searchResults: [AssetItem], id: String? = nil, start: Bool = true) {
        self.album = nil
        self.search = true
        self._assetItems = State(initialValue: searchResults)
        if id != nil {
            if let index = searchResults.firstIndex(where: { $0.id == id }) {
                self._currentIndex = State(initialValue: index)
            }
        }
        self._startSlideShow = State(initialValue: start)
    }
    
    var toolBar: some View {
        VStack(alignment: .center) {
            if let a = album, showAlbumName {
                Text(a.albumName).font(.title3).foregroundColor(.white).padding()
            }
            HStack {
                HStack(alignment: .center, spacing: 40){
                    Button(action: {
                        currentIndex = (currentIndex - 1 + assetItems.count) % assetItems.count
                        thumbnail = true
                        remoting = false
                        hideToolbarAfterDelay()
                    }) {
                        Image(systemName: "backward.frame").scaleEffect(focusedButton == "privious" ? 1.1 : 1.0)
                            .background(focusedButton == "privious" ? Color.white.opacity(0.3) : Color.black.opacity(0.3)).foregroundColor(focusedButton == "privious" ? .black : .white).padding(.horizontal, 30)
                    }
                    .focused($focusedButton, equals: "privious")
                    .buttonStyle(PlainButtonStyle()) // Ensure no default styling interferes
                    Button(action: {
                        if timer == nil && !assetItems.isEmpty {
                            thumbnail = true
                            remoting = false
                            hideToolbarAfterDelay()
                            startSlideShow = true
                            startSlideshow()
                        } else if timer != nil {
                            stopSlideshow()
                        }
                    }) {
                        Image(systemName: (timer == nil ? "play" : "pause")).scaleEffect(focusedButton == "playpause" ? 1.1 : 1.0)
                            .background(focusedButton == "playpause" ? Color.white.opacity(0.3) : Color.black.opacity(0.3)).foregroundColor(focusedButton == "playpause" ? .black : .white).padding(.horizontal, 30)
                    }
                    .focused($focusedButton, equals: "playpause")
                    .buttonStyle(PlainButtonStyle()) // Ensure no default styling interferes
                    Button(action: {
                        currentIndex = (currentIndex + 1) % assetItems.count
                        thumbnail = true
                        remoting = false
                        hideToolbarAfterDelay()
                    }) {
                        Image(systemName: "forward.frame").scaleEffect(focusedButton == "next" ? 1.1 : 1.0)
                            .background(focusedButton == "next" ? Color.white.opacity(0.3) : Color.black.opacity(0.3)).foregroundColor(focusedButton == "next" ? .black : .white).padding(.horizontal, 30)
                    }
                    .focused($focusedButton, equals: "next")
                    .buttonStyle(PlainButtonStyle()) // Ensure no default styling interferes
                }.padding()
                    .background(Color.black.opacity(0.5)) // Transparent background
                    .cornerRadius(15)
                    .transition(.move(edge: .bottom).combined(with: .opacity)) // Slide and fade
                    .zIndex(1) // Ensure bar is above image
                Spacer()
                if immichService.slideShowOfThumbnails {
                    HStack {
                        Button(action: {
                            stopSlideshow()
                            thumbnail = false
                            remoting = false
                            hideToolbarAfterDelay()
                        }) {
                            Image(systemName: assetItems[currentIndex].type == .video ? "video" : "photo").background(Color.gray.opacity(0.8))
                        }
                        .focused($focusedButton, equals: "original")
                        .buttonStyle(PlainButtonStyle())
                    }.padding()
                        .background(Color.black.opacity(0.5)) // Transparent background
                        .cornerRadius(15)
                        .transition(.move(edge: .bottom).combined(with: .opacity)) // Slide and fade
                        .zIndex(1) // Ensure bar is above image
                }
            }
        }
    }
     
     var body: some View {
         ZStack(alignment: .bottom) {
             Color.black.edgesIgnoringSafeArea(.all) // Full-screen background
             if !assetItems.isEmpty {
                 Text("No pictures found").font(.title) .foregroundColor(.white)
             }
             Color.black.edgesIgnoringSafeArea(.all)
             if isLoading {
                 Spacer()
                 ProgressView().progressViewStyle(CircularProgressViewStyle()).scaleEffect(1)
                 Spacer()
             } else if assetItems.isEmpty {
                 Spacer()
                 Text("No pictures found").font(.title) .foregroundColor(.white)
                 Spacer()
             } else {
                 if assetItems[currentIndex].type == .image || (thumbnail && immichService.slideShowOfThumbnails) {
                     AsyncImage(url: immichService.getImageUrl(id: assetItems[currentIndex].id, thumbnail: immichService.slideShowOfThumbnails && thumbnail, video: assetItems[currentIndex].type == .video), content: { image in
                         image.resizable().scaledToFit().edgesIgnoringSafeArea(.all).cornerRadius(15)
                             .background(.black)
                             .focusable(isBarVisible ? false : true) // Only focus image when bar is hidden
                             .focused($focusedButton, equals: "image")
                     }, placeholder: {
                         ProgressView()
                     }).frame(maxWidth: .infinity, maxHeight: .infinity)
                 } else {
                     // Use VideoPlayer (SwiftUI's built-in view) if targeting iOS 14+ or tvOS
                     VideoPlayerView(videoURL: immichService.getImageUrl(id: assetItems[currentIndex].id, thumbnail: immichService.slideShowOfThumbnails && thumbnail, video: assetItems[currentIndex].type == .video)!, isVideoFinished: $isVideoFinished)
                 }
                 // Transparent bar at the bottom
                 if isBarVisible {
                     toolBar
                 }
             }
         }.task {
             if !search {
                 await loadAssets()
             } else {
                 self.isLoading = false
             }
         }.onMoveCommand { direction in // Handle arrow key/remote input
             switch direction {
             case .left:
                 if !isBarVisible {
                     currentIndex = (currentIndex - 1 + assetItems.count) % assetItems.count
                     thumbnail = true
                 } else {
                     remoting = true
                 }
             case .right:
                 if !isBarVisible {
                     currentIndex = (currentIndex + 1) % assetItems.count
                     thumbnail = true
                 } else {
                     remoting = true
                 }
             case .up:
                 stopSlideshow()
                 thumbnail = false
             case .down:
                 withAnimation(.easeInOut(duration: 0.3)) {
                     isBarVisible.toggle()
                     focusedButton = "playpause"
                 }
             default:
                 break
             }
           }.onAppear {
               if !assetItems.isEmpty {
                 startSlideshow()
             }
             // Hide the bar after 3 seconds when the view loads
             DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                 withAnimation(.easeInOut(duration: 0.3)) {
                     isBarVisible = true
                     focusedButton = "playpause"
                 }
             }
            // Hide toolbar after 4 seconds on initial appear
            hideToolbarAfterDelay()
           }.animation(.easeInOut(duration: 1.0), value: isBarVisible)
         .onDisappear {
             stopSlideshow()
         }
         .onChange(of: assetItems) { newAssets in
             if !newAssets.isEmpty {
                 startSlideshow()
             }
         }
         .onChange(of: isVideoFinished) { finished in
             if self.isVideoFinished && !immichService.slideShowOfThumbnails {
                 self.isVideoFinished = false
                 startSlideshow()
             }
         }
     }
    
    private func hideToolbarAfterDelay() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 7) {
            withAnimation(.easeInOut(duration: 0.7)) {
                if !remoting {
                    isBarVisible = false
                }
            }
        }
    }
     
     private func loadAssets() async {
         do {
             isLoading = true
             let fetchedAssetItems = try await immichService.fetchAssets(for: album?.id ?? "")
             assetItems = fetchedAssetItems
             isLoading = false
         } catch {
             print("Failed to fetch pictures: \(error)")
             isLoading = false
         }
     }
     
     private func startSlideshow() {
         stopSlideshow() // Ensure no existing timer
         showAlbumName = true
         if !assetItems.isEmpty && startSlideShow {
             timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
                 withAnimation {
                     currentIndex = (currentIndex + 1) % assetItems.count
                     showAlbumName = false
                     if assetItems[currentIndex].type == .video && !immichService.slideShowOfThumbnails {
                         stopSlideshow()
                     } else {
                         UIApplication.shared.sendAction(#selector(UIResponder.becomeFirstResponder), to: nil, from: nil, for: nil)
                     }
                 }
             }
         }
     }
     
     private func stopSlideshow() {
         timer?.invalidate()
         timer = nil
         showAlbumName = false
     }
}


struct VideoPlayerView: View {
    // The URL of the video to play
    let videoURL:URL
    @Binding var isVideoFinished: Bool
    // State to control playback
    @State private var player: AVPlayer?
    
    
    var body: some View {
        ZStack {
            // Use VideoPlayer (SwiftUI's built-in view) if targeting iOS 14+ or tvOS
            if let player = player {
                VideoPlayer(player: player)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .edgesIgnoringSafeArea(.all)
            } else {
                Text("Loading video...")
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            // Initialize the player when the view appears
            setupPlayer()
            setupNotification()
        }
        .onDisappear {
            // Clean up when the view disappears
            player?.pause()
            player = nil
            NotificationCenter.default.removeObserver(self) // Clean up observer
        }
    }
    
    private func setupPlayer() {
        // Create AVPlayer with the video URL
        player = AVPlayer(url: videoURL)
        
        // Optionally auto-play the video
        player?.play()
    }
    
    private func setupNotification() {
        // Add observer for when the video finishes
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player?.currentItem,
            queue: .main
        ) { _ in
            isVideoFinished = true
            print("Video playback finished!")
            // Optional: Restart or perform another action
            // player?.seek(to: .zero)
            // player?.play()
        }
    }
}


