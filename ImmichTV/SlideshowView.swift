//
//  SlideshowView.swift
//  ImmichTV
//
//  Created by David Lüthi on 17.03.2025.
//

import SwiftUI
import Combine
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
    @State private var timerSubscription: Cancellable?
    @FocusState private var focusedButton: String?
    @StateObject private var playerViewModel = PlayerViewModel()
    @State private var isFavorite = false
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
    
    private var timer: Publishers.Autoconnect<Timer.TimerPublisher> {
        Timer.publish(every: (Double(immichService.timeinterval) ?? 5.0), on: .main, in: .common).autoconnect()
    }
    
    var toolBar: some View {
        VStack(alignment: .center) {
            if let a = album, showAlbumName {
                Text(a.albumName).font(.title3).background(.black.opacity(0.5)).foregroundColor(.white.opacity(0.8)).padding()
            }
            HStack {
                HStack(alignment: .center, spacing: 40){
                    Button(action: {
                        showToolbar()
                        self.goToPreviousItem()
                    }) {
                        Image(systemName: "backward.frame").scaleEffect(focusedButton == "privious" ? 1.1 : 1.0)
                            .background(focusedButton == "privious" ? Color.white.opacity(0.3) : Color.black.opacity(0.3)).foregroundColor(focusedButton == "privious" ? .black : .white).padding(.horizontal, 30)
                    }
                    .focused($focusedButton, equals: "privious")
                    .buttonStyle(PlainButtonStyle()) // Ensure no default styling interferes
                    Button(action: {
                        showToolbar()
                        running.toggle()
                        if running {
                            showAlbumName = true
                        }
                    }) {
                        Image(systemName: (!running ? "play" : "pause")).scaleEffect(focusedButton == "playpause" ? 1.1 : 1.0)
                            .background(focusedButton == "playpause" ? Color.white.opacity(0.3) : Color.black.opacity(0.3)).foregroundColor(focusedButton == "playpause" ? .black : .white).padding(.horizontal, 30)
                    }
                    .focused($focusedButton, equals: "playpause")
                    .buttonStyle(PlainButtonStyle()) // Ensure no default styling interferes
                    Button(action: {
                        showToolbar()
                        self.goToNextItem()
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
                if !immichService.demo {
                    HStack {
                        Button(action: {
                            showToolbar()
                            Task {@MainActor in
                                do {
                                    let updatedAssetItem = try await immichService.updateAssets(id: assetItems[currentIndex].id, favorite: !assetItems[currentIndex].isFavorite)
                                    guard !assetItems.isEmpty, currentIndex < assetItems.count else { return }
                                    isFavorite = updatedAssetItem.isFavorite
                                    assetItems.remove(at: currentIndex)
                                    assetItems.insert(updatedAssetItem, at: currentIndex)
                                } catch {
                                    print(error.localizedDescription)
                                }
                            }
                        }) {
                            Image(systemName: isFavorite ? "heart.fill" : "heart").background(Color.gray.opacity(0.8))
                        }
                        .focused($focusedButton, equals: "favorite")
                        .buttonStyle(PlainButtonStyle())
                    }.padding()
                        .background(Color.black.opacity(0.5)) // Transparent background
                        .cornerRadius(15)
                        .transition(.move(edge: .bottom).combined(with: .opacity)) // Slide and fade
                        .zIndex(1) // Ensure bar is above image
                }
                if immichService.slideShowOfThumbnails {
                    HStack {
                        Button(action: {
                            showToolbar()
                            running = false
                            thumbnail = false
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
                             isFavorite = assetItems[currentIndex].isFavorite
                         }
                 } else {
                     VideoPlayer(player: playerViewModel.player).frame(maxWidth: .infinity, maxHeight: .infinity)
                         .onAppear {
                             isFavorite = assetItems[currentIndex].isFavorite
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
                 } else {
                     if focusedButton == nil {
                         focusedButton = "privious"
                     }
                     if isBarVisible {
                         showToolbar()
                     }
                 }
             case .right:
                 if !isBarVisible {
                     self.goToNextItem()
                 } else {
                     if focusedButton == nil {
                         focusedButton = "next"
                     }
                     if isBarVisible {
                         showToolbar()
                     }
                 }
             case .up:
                 running = false
                 thumbnail = false
                 focusedButton = "playpause"
                 if isBarVisible {
                     showToolbar()
                 }
             case .down:
                 withAnimation(.easeInOut(duration: 0.3)) {
                     isBarVisible.toggle()
                     focusedButton = "playpause"
                     if isBarVisible {
                         showToolbar()
                     }
                 }
             default:
                 break
             }
           }.onAppear {
               showToolbar()
           }.animation(.easeInOut(duration: 1.0), value: isBarVisible)
         .onReceive(timer) { _ in
             if running { goToNextItem() }
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
        if !assetItems.isEmpty {
            currentIndex = (currentIndex + 1) % assetItems.count
            isFavorite = assetItems[currentIndex].isFavorite
            thumbnail = true
            setupPlayer()
        }
        UIApplication.shared.sendAction(#selector(UIResponder.becomeFirstResponder), to: nil, from: nil, for: nil)
    }
    
    private func goToPreviousItem() {
        playerViewModel.player?.pause()
        NotificationCenter.default.removeObserver(self)
        if !assetItems.isEmpty {
            currentIndex = (currentIndex - 1 + assetItems.count) % assetItems.count
            isFavorite = assetItems[currentIndex].isFavorite
            thumbnail = true
            setupPlayer()
        }
        UIApplication.shared.sendAction(#selector(UIResponder.becomeFirstResponder), to: nil, from: nil, for: nil)
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
    
    // Start the timer
      private func showToolbar() {
          timerSubscription?.cancel()
          timerSubscription = nil
          isBarVisible = true
          timerSubscription = Timer.publish(every: 10.0, on: .main, in: .common)
              .autoconnect()
              .sink { _ in
                  self.isBarVisible = false
                  showAlbumName = false
                  timerSubscription?.cancel()
                  timerSubscription = nil
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


