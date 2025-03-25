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
    @State private var running = true
    @State private var assetItems: [AssetItem] = []
    @StateObject private var immichService = ImmichService()
    @State private var currentIndex = 0
    @State private var isLoading = true
    @State private var showAlbumName = true
    @State private var thumbnail = true
    @State private var isBarVisible: Bool = true // Controls bar visibility
    @FocusState private var focusedButton: String?
    @StateObject private var playerViewModel = PlayerViewModel()
    @Environment(\.dismiss) private var dismiss // For dismissing the full-screen view
        
    
    init(album: Album) {
        self.album = album
        self.search = false
        self.assetItems = []
        self.running = true
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
        self._running = State(initialValue: start)
    }
    
    var toolBar: some View {
        VStack(alignment: .center) {
            if let a = album, showAlbumName {
                Text(a.albumName).font(.title3).background(.black.opacity(0.5)).foregroundColor(.white.opacity(0.8)).padding()
            }
            HStack {
                HStack(alignment: .center, spacing: 40){
                    Button(action: {
                        isBarVisible = true
                        self.goToPreviousItem()
                        hideToolbarAfterDelay()
                    }) {
                        Image(systemName: "backward.frame").scaleEffect(focusedButton == "privious" ? 1.1 : 1.0)
                            .background(focusedButton == "privious" ? Color.white.opacity(0.3) : Color.black.opacity(0.3)).foregroundColor(focusedButton == "privious" ? .black : .white).padding(.horizontal, 30)
                    }
                    .focused($focusedButton, equals: "privious")
                    .buttonStyle(PlainButtonStyle()) // Ensure no default styling interferes
                    Button(action: {
                        isBarVisible = true
                        running.toggle()
                        if running {
                            showAlbumName = true
                            if assetItems[currentIndex].type == .image || (thumbnail && immichService.slideShowOfThumbnails) {
                                DispatchQueue.main.asyncAfter(deadline: .now() + (Double(immichService.timeinterval) ?? 5.0)) {
                                    goToNextItem()
                                }
                            } else {
                                goToNextItem()
                            }
                        }
                        hideToolbarAfterDelay()
                    }) {
                        Image(systemName: (!running ? "play" : "pause")).scaleEffect(focusedButton == "playpause" ? 1.1 : 1.0)
                            .background(focusedButton == "playpause" ? Color.white.opacity(0.3) : Color.black.opacity(0.3)).foregroundColor(focusedButton == "playpause" ? .black : .white).padding(.horizontal, 30)
                    }
                    .focused($focusedButton, equals: "playpause")
                    .buttonStyle(PlainButtonStyle()) // Ensure no default styling interferes
                    Button(action: {
                        isBarVisible = true
                        self.goToNextItem()
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
                            isBarVisible = true
                            running = false
                            thumbnail = false
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
            }.onAppear {
                focusedButton = "playpause"
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
                         .onAppear {
                             // Show image for 5 seconds then move to next
                             if running {
                                 DispatchQueue.main.asyncAfter(deadline: .now() + (Double(immichService.timeinterval) ?? 5.0)) {
                                     goToNextItem()
                                 }
                             }
                         }
                 } else {
                     VideoPlayer(player: playerViewModel.player).frame(maxWidth: .infinity, maxHeight: .infinity)
                         .onAppear {
                             setupPlayer()
                         }
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
                     self.goToPreviousItem()
                 } else if focusedButton == nil {
                     focusedButton = "privious"
                 }
             case .right:
                 if !isBarVisible {
                     self.goToNextItem()
                 } else if focusedButton == nil {
                     focusedButton = "next"
                 }
             case .up:
                 running = false
                 thumbnail = false
                 focusedButton = "playpause"
             case .down:
                 withAnimation(.easeInOut(duration: 0.3)) {
                     isBarVisible.toggle()
                     focusedButton = "playpause"
                 }
             default:
                 break
             }
           }.onAppear {
            // Hide toolbar after 4 seconds on initial appear
            hideToolbarAfterDelay()
           }.animation(.easeInOut(duration: 1.0), value: isBarVisible)
         .onChange(of: assetItems) { newAssets in
             if !newAssets.isEmpty {
                 if running {
                     DispatchQueue.main.asyncAfter(deadline: .now() + (Double(immichService.timeinterval) ?? 5.0)) {
                         goToNextItem()
                     }
                 }
             }
         }
     }
    
    private func hideToolbarAfterDelay() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 7) {
            withAnimation(.easeInOut(duration: 0.7)) {
                isBarVisible = false
                showAlbumName = false
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
    
    private func goToNextItem() {
        playerViewModel.player?.pause()
        NotificationCenter.default.removeObserver(self)
        currentIndex = (currentIndex + 1) % assetItems.count
        thumbnail = true
        setupPlayer()
        UIApplication.shared.sendAction(#selector(UIResponder.becomeFirstResponder), to: nil, from: nil, for: nil)
    }
    
    private func goToPreviousItem() {
        playerViewModel.player?.pause()
        NotificationCenter.default.removeObserver(self)
        currentIndex = (currentIndex - 1 + assetItems.count) % assetItems.count
        thumbnail = true
        setupPlayer()
    }
    
    private func setupPlayer() {
        if assetItems[currentIndex].type == .image || (thumbnail && immichService.slideShowOfThumbnails) { return } else {
            playerViewModel.setupPlayer(with: immichService.getImageUrl(id: assetItems[currentIndex].id, thumbnail: immichService.slideShowOfThumbnails && thumbnail, video: assetItems[currentIndex].type == .video)!)
            
            // Add observer for when video ends
            NotificationCenter.default.addObserver(
                forName: AVPlayerItem.didPlayToEndTimeNotification,
                object: playerViewModel.player?.currentItem,
                queue: .main
            ) { _ in
                self.playerViewModel.player?.seek(to: .zero)
                if running {
                    goToNextItem()
                }
            }
        }
    }
}

class PlayerViewModel: ObservableObject {
    @Published var player: AVPlayer?
    
    func setupPlayer(with url: URL) {
        player = AVPlayer(url: url)
        player?.play()
    }
}


