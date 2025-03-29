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
    @State private var running = true {
        didSet {
            UIApplication.shared.isIdleTimerDisabled = running
        }
    }
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
    @State private var swipeOffset: CGFloat = 0 // Tracks the swipe position
        
        
    
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
        Timer.publish(every: immichService.timeinterval, on: .main, in: .common).autoconnect()
    }
    
    var albumTitle: some View {
        VStack(alignment: .center) {
            if let a = album, showAlbumName {
                Spacer()
                HStack(alignment: .center) {
                    Text(a.albumName).font(.title3).foregroundColor(.white.opacity(0.8))
                }.padding().background(.black.opacity(0.5))
                    .cornerRadius(15)
                    .transition(.move(edge: .bottom).combined(with: .opacity)) // Slide and fade
                    .zIndex(1) // Ensure bar is above image
                    .padding(.bottom, 100)
            }
        }
    }
    
    var location: String? {
        var result: String?
        if let city = assetItems[currentIndex].exifInfo?.city {
            result = city
        }
        if let country = assetItems[currentIndex].exifInfo?.country {
            result = result == nil ? country : "\(result!), \(country)"
        }
        return result
    }
    
    var exifInfo: some View {
        VStack(alignment: .trailing) {
            if let result = location {
                Text("\(result)").font(.caption).foregroundColor(.white.opacity(0.8))
            }
            if assetItems[currentIndex].exifInfo?.latitude != nil && assetItems[currentIndex].exifInfo?.longitude != nil {
                Text("GPS: \(assetItems[currentIndex].exifInfo!.latitude!): \(assetItems[currentIndex].exifInfo!.longitude!)").font(.caption).foregroundColor(.white.opacity(0.8))
            }
            if assetItems[currentIndex].exifInfo?.dateTimeOriginal != nil {
                Text("created: \(assetItems[currentIndex].exifInfo!.dateTimeOriginal!)").font(.caption).foregroundColor(.white.opacity(0.8))
            }
        }
    }
    
    var toolBar: some View {
        VStack(alignment: .center, spacing: 40) {
            HStack(alignment: .top) {
#if os(tvOS)
#else
                HStack {
                    Button(action: {
                        UIApplication.shared.isIdleTimerDisabled = false
                        dismiss()
                    }) {
                        Image(systemName: "x.square").padding(.horizontal, 30)
                    }.buttonStyle(ImmichTVSlideShowButtonStyle(isFocused: focusedButton == "close"))
                        .focused($focusedButton, equals: "close")
                }.padding()
                    .background(Color.black.opacity(0.5)) // Transparent background
                    .cornerRadius(15)
                    .transition(.move(edge: .bottom).combined(with: .opacity)) // Slide and fade
                    .zIndex(1) // Ensure bar is above image
                    .padding(.top, 20)
#endif
                Spacer()
                HStack {
                    VStack(alignment: .trailing) {
                        if !immichService.demo {
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
                                Image(systemName: isFavorite ? "heart.fill" : "heart").padding(.horizontal, 30)
                            }.buttonStyle(ImmichTVSlideShowButtonStyle(isFocused: focusedButton == "favorite"))
                                .focused($focusedButton, equals: "favorite")
                        }
                        if immichService.slideShowOfThumbnails || (assetItems[currentIndex].type == .video && !immichService.playVideo && !immichService.slideShowOfThumbnails) {
                            Button(action: {
                                showToolbar()
                                running = false
                                thumbnail = false
                            }) {
                                Image(systemName: assetItems[currentIndex].type == .video ? "video" : "photo").padding(.horizontal, 30)
                            }.buttonStyle(ImmichTVSlideShowButtonStyle(isFocused: focusedButton == "original"))
                                .focused($focusedButton, equals: "original")
                        }
                        if assetItems[currentIndex].exifInfo != nil {
                            exifInfo
                        }
                    }
                }.padding()
                    .background(Color.black.opacity(0.5)) // Transparent background
                    .cornerRadius(15)
                    .transition(.move(edge: .bottom).combined(with: .opacity)) // Slide and fade
                    .zIndex(1) // Ensure bar is above image
                    .padding(.top, 20)
            }
            Spacer()
            HStack(alignment: .bottom){
                Button(action: {
                    showToolbar()
                    self.goToPreviousItem()
                }) {
                    Image(systemName: "backward.frame").padding(.horizontal, 30)
                }.buttonStyle(ImmichTVSlideShowButtonStyle(isFocused: focusedButton == "privious"))
                .focused($focusedButton, equals: "privious")
                Button(action: {
                    showToolbar()
                    running.toggle()
                    if running {
                        showAlbumName = true
                    }
                }) {
                    Image(systemName: (!running ? "play" : "pause")).padding(.horizontal, 30)
                }.buttonStyle(ImmichTVSlideShowButtonStyle(isFocused: focusedButton == "playpause"))
                .focused($focusedButton, equals: "playpause")
                Button(action: {
                    showToolbar()
                    self.goToNextItem()
                }) {
                    Image(systemName: "forward.frame").padding(.horizontal, 30)
                }.buttonStyle(ImmichTVSlideShowButtonStyle(isFocused: focusedButton == "next"))
                .focused($focusedButton, equals: "next")
            }.padding()
                .background(Color.black.opacity(0.5)) // Transparent background
                .cornerRadius(15)
                .transition(.move(edge: .bottom).combined(with: .opacity)) // Slide and fade
                .zIndex(1) // Ensure bar is above image
                .padding(.bottom, 10)
        }.onAppear {
            focusedButton = "playpause"
        }
    }
    
    var isVideoAndPlayable: Bool {
        return ((assetItems[currentIndex].type == .video && !thumbnail) ||
               (assetItems[currentIndex].type == .video && !immichService.slideShowOfThumbnails && immichService.playVideo))
    }
     
     var body: some View {
         ZStack(alignment: .center) {
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
                 if !isVideoAndPlayable {
                     AsyncImage(url: immichService.getImageUrl(id: assetItems[currentIndex].id, thumbnail: immichService.slideShowOfThumbnails && thumbnail, video: assetItems[currentIndex].type == .video), content: { image in
                         image.resizable().scaledToFit().edgesIgnoringSafeArea(.all).cornerRadius(15)
                             .background(.black)
                             .focusable(isBarVisible ? false : true) // Only focus image when bar is hidden
                             .focused($focusedButton, equals: "image")
                     }, placeholder: {
                         ProgressView()
                     }).frame(maxWidth: .infinity, maxHeight: .infinity)
                         .overlay() {
                             albumTitle
                         }
                         .onAppear {
                             isFavorite = assetItems[currentIndex].isFavorite
                         }
                 } else {
                     VideoPlayer(player: playerViewModel.player).frame(maxWidth: .infinity, maxHeight: .infinity)
                         .aspectRatio(contentMode: .fit) // Maintain video's aspect ratio, fitting within bounds
                         .edgesIgnoringSafeArea(.all) // Extend to edges for iPad
                         .overlay() {
                             albumTitle
                         }
                         .onAppear {
                             isFavorite = assetItems[currentIndex].isFavorite
                             setupPlayer()
                         }
                 }
                 // Transparent bar
                 if isBarVisible {
                     toolBar
                 }
             }
         }
         .clipped()
         .ignoresSafeArea()
         .edgesIgnoringSafeArea(.all)
         .navigationBarBackButtonHidden(!self.isBarVisible) // Hides the back button
         .task {
             if !search {
                 await loadAssets()
             } else {
                 self.isLoading = false
             }
         }
        #if os(tvOS)
         .onMoveCommand { direction in // Handle arrow key/remote input
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
                 if isBarVisible {
                     focusedButton = "favorite"
                 } else {
                     focusedButton = "playpause"
                 }
                 showToolbar()
             case .down:
                 withAnimation(.easeInOut(duration: 0.3)) {
                     if isBarVisible && (focusedButton != "privious" || focusedButton != "next" || focusedButton != "playpause") {
                         focusedButton = "playpause"
                         showToolbar()
                     } else {
                         isBarVisible = false
                     }
                 }
             default:
                 break
             }
           }
         #else
         .offset(x: swipeOffset) // Moves the text based on swipe
         .gesture(
             DragGesture()
                 .onChanged { value in
                     // Update offset while dragging
                     swipeOffset = value.translation.width
                 }
                .onEnded { value in
                    withAnimation(.easeInOut(duration: 0.3)) {
                        // Determine swipe direction based on final position
                        if value.translation.width > 50 {
                            self.goToPreviousItem()
                            withAnimation {
                                swipeOffset = 100 // Move right
                            }
                        } else if value.translation.width < -50 {
                            self.goToNextItem()
                            withAnimation {
                                swipeOffset = -100 // Move left
                            }
                        }
                        swipeOffset = 0
                    }
                }
         )
         .onTapGesture(count: 1) {
             withAnimation {
                 if isBarVisible {
                     isBarVisible = false
                     timerSubscription?.cancel()
                     timerSubscription = nil
                 } else {
                     showToolbar()
                 }
             }
         }
         .onTapGesture(count: 2) {
             withAnimation {
                 UIApplication.shared.isIdleTimerDisabled = false
                 dismiss()
             }
         }
         .onTapGesture(count: 3) {
             withAnimation {
                 running = false
                 thumbnail = false
                 focusedButton = "playpause"
                 if isBarVisible {
                     showToolbar()
                 }
             }
         }
         #endif
         .background(Color.black)
         .onAppear {
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
        if !isVideoAndPlayable { return } else {
            playerViewModel.setupPlayer(with: immichService.getVideoUrl(id: assetItems[currentIndex].id)!)
            
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
        // Check player status before playing

        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1) {
            if self.player?.status == .readyToPlay {
                self.player?.play()
            } else if self.player?.status == .failed {
                print("Error: \(String(describing: self.player?.error))")
            } else if self.player?.status == .unknown {
                print("Unreliable for AVPlayer due to incomplete AVFoundation support.")
            } else {
                print("not ready")
            }
        }
    }
}


