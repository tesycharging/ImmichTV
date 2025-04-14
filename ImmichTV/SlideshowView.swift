//
//  SlideshowView.swift
//  ImmichTV
//
//  Created by David Lüthi on 17.03.2025.
//

import SwiftUI
import Combine
import AVKit
import AVFoundation

struct SlideshowView: View {
    @EnvironmentObject private var immichService: ImmichService
    @EnvironmentObject private var entitlementManager: EntitlementManager
    let albumName: String?
    @State private var running = true {
        didSet {
            UIApplication.shared.isIdleTimerDisabled = running
            if running {
                playerMusic?.play()
            } else {
                playerMusic?.pause()
            }
        }
    }
    @State private var query: Query?
    @State private var currentIndex = 0
    @State private var isLoading = false
    @State private var showAlbumName = true
    @State private var thumbnail = true
    @State private var isBarVisible: Bool = true // Controls bar visibility
    @State private var timerSubscription: Cancellable?
    @FocusState private var focusedButton: String?
    @StateObject private var playerViewModel = PlayerViewModel()
    @State private var isFavorite = false
    @Environment(\.dismiss) private var dismiss // For dismissing the full-screen view
    @State private var swipeOffset: CGFloat = 0 // Tracks the swipe position
    @State private var exifInfo: ExifInfo? = nil
    
    @State private var playerMusic: AVPlayer?
      
    
    init(albumName: String? = nil, index: Int? = nil, query: Query? = nil) {
        self.albumName = albumName
        self._query = State(initialValue: query)
        self._currentIndex = State(initialValue: index ?? 0)
        self._running = State(initialValue: index == nil)
    }
    
    private var timer: Publishers.Autoconnect<Timer.TimerPublisher> {
        return Timer.publish(every: entitlementManager.timeinterval, on: .main, in: .common).autoconnect()
    }
    
    var albumTitle: some View {
        VStack(alignment: .center) {
            if let aName = albumName, showAlbumName {
                Spacer()
                HStack(alignment: .center) {
                    Text(aName).font(.title3).foregroundColor(.white.opacity(0.8))
                }.padding().background(.black.opacity(0.5))
                    .cornerRadius(15)
                    .transition(.move(edge: .bottom).combined(with: .opacity)) // Slide and fade
                    .zIndex(1) // Ensure bar is above image
                    .padding(.bottom, 100)
            }
        }
    }
    
    func convertToDate(from dateString: String) -> String? {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date =  isoFormatter.date(from: dateString) else { return nil }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .long    // e.g., "March 15, 2025"
        formatter.timeStyle = .medium  // e.g., "4:45:11 PM"
        formatter.timeZone = TimeZone(identifier: "UTC") // Match the +00:00 offset
        return formatter.string(from: date)
    }
    
    func location(exifInfo: ExifInfo) -> String? {
        var result: String?
        if let city = exifInfo.city {
            result = city
        }
        if let country = exifInfo.country {
            result = result == nil ? country : "\(result!), \(country)"
        }
        return result
    }
    
    func camera(exifInfo: ExifInfo) -> String? {
        var result: String?
        if let make = exifInfo.make {
            result = make
        }
        if let model = exifInfo.model {
            result = result == nil ? model : "\(result!), \(model)"
        }
        return result
    }
    
    func exifInfoView(exifInfo: ExifInfo) -> some View {
        VStack(alignment: .trailing) {
            Text("\(immichService.assetItems[currentIndex].originalFileName) #\(self.currentIndex + 1) of Page \((query?.page ?? 2) - 1)").font(.caption).foregroundColor(.white.opacity(0.8))
            if let result = location(exifInfo: exifInfo) {
                Text("\(result)").font(.caption).foregroundColor(.white.opacity(0.8))
            }
            if exifInfo.latitude != nil && exifInfo.longitude != nil {
                Text("GPS: \(exifInfo.latitude!): \(exifInfo.longitude!)").font(.caption).foregroundColor(.white.opacity(0.8))
            }
            if exifInfo.dateTimeOriginal != nil {
                Text("\(convertToDate(from: exifInfo.dateTimeOriginal!) ?? "")").font(.caption).foregroundColor(.white.opacity(0.8))
            }
            if let cam = camera(exifInfo: exifInfo) {
                Text("\(cam)").font(.caption).foregroundColor(.white.opacity(0.8))
            }
        }
    }
    
    private var showVideoButton: Bool {
        if (immichService.assetItems[currentIndex].type == .video && thumbnail && (entitlementManager.slideShowOfThumbnails || (!entitlementManager.slideShowOfThumbnails && !entitlementManager.playVideo))) {
            focusedButton = "videoButton"
            return true
        } else {
            return false
        }
    }
    
    //if video is not played automatic, this button let it play and/or stops the slideshow.
    //This button is showed when the type is "video"
    var videoButton: some View {
        VStack(alignment: .center, spacing: 40) {
            HStack(alignment: .top) {
                Spacer()
                HStack {
                    VStack(alignment: .trailing) {
                        if (showVideoButton) {
                            Button(action: {
                                timerSubscription?.cancel()
                                timerSubscription = nil
                                running = false
                                thumbnail = false
                            }) {
                                Image(systemName: immichService.assetItems[currentIndex].type == .video ? "video" : "photo").padding(.horizontal, 30)
                            }.buttonStyle(ImmichTVSlideShowButtonStyle(isFocused: focusedButton == "videoButton"))
                                .focused($focusedButton, equals: "videoButton")
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
                        if !entitlementManager.demo {
                            Button(action: {
                                showToolbar()
                                Task {@MainActor in
                                    do {
                                        let updatedAssetItem = try await immichService.updateAssets(id: immichService.assetItems[currentIndex].id, favorite: !immichService.assetItems[currentIndex].isFavorite)
                                        guard !immichService.assetItems.isEmpty, currentIndex < immichService.assetItems.count else { return }
                                        isFavorite = updatedAssetItem.isFavorite
                                        immichService.assetItems.remove(at: currentIndex)
                                        immichService.assetItems.insert(updatedAssetItem, at: currentIndex)
                                    } catch {
                                        print(error.localizedDescription)
                                    }
                                }
                            }) {
                                Image(systemName: isFavorite ? "heart.fill" : "heart").padding(.horizontal, 30)
                            }.buttonStyle(ImmichTVSlideShowButtonStyle(isFocused: focusedButton == "favorite"))
                                .focused($focusedButton, equals: "favorite")
                        }
                        if entitlementManager.slideShowOfThumbnails || (immichService.assetItems[currentIndex].type == .video && !entitlementManager.playVideo && !entitlementManager.slideShowOfThumbnails) {
                            Button(action: {
                                showToolbar()
                                running = false
                                thumbnail = false
                            }) {
                                Image(systemName: immichService.assetItems[currentIndex].type == .video ? "video" : "photo").padding(.horizontal, 30)
                            }.buttonStyle(ImmichTVSlideShowButtonStyle(isFocused: focusedButton == "original"))
                                .focused($focusedButton, equals: "original")
                        }
                        if exifInfo != nil {
                            exifInfoView(exifInfo: exifInfo!)
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
            #if os(tvOS)
            focusedButton = "playpause"
            #endif
            if immichService.assetItems[currentIndex].exifInfo == nil {
                Task {
                    if let exif = try? await immichService.getAsset(id: immichService.assetItems[currentIndex].id).exifInfo {
                        exifInfo = exif
                    }
                }
            } else {
                exifInfo = immichService.assetItems[currentIndex].exifInfo!
            }
        }
    }
    
    var isVideoAndPlayable: Bool {
        return ((immichService.assetItems[currentIndex].type == .video && !thumbnail) ||
                (immichService.assetItems[currentIndex].type == .video && !entitlementManager.slideShowOfThumbnails && entitlementManager.playVideo))
    }
     
     var body: some View {
         ZStack(alignment: .center) {
             Color.black.ignoresSafeArea() // Full-screen background
             if isLoading {
                 Spacer()
                 ProgressView().progressViewStyle(CircularProgressViewStyle()).scaleEffect(1)
                 Spacer()
             } else if immichService.assetItems.isEmpty {
                 Spacer()
                 Text("No pictures found").font(.title)
                 Spacer()
             } else {
                 if !isVideoAndPlayable {
                     RetryableAsyncImage(url: immichService.getImageUrl(id: immichService.assetItems[currentIndex].id, thumbnail: entitlementManager.slideShowOfThumbnails && thumbnail, video: immichService.assetItems[currentIndex].type == .video))
                         .background(.black)
                         .focusable(isBarVisible ? false : true) // Only focus image when bar is hidden
                         .focused($focusedButton, equals: "image")
                         .frame(maxWidth: .infinity, maxHeight: .infinity)
                         .overlay() {
                             albumTitle
                         }
                         .onAppear {
                             isFavorite = immichService.assetItems[currentIndex].isFavorite
                         }
                 } else {
                     VideoPlayer(player: playerViewModel.player).frame(maxWidth: .infinity, maxHeight: .infinity)
                         .aspectRatio(contentMode: .fit) // Maintain video's aspect ratio, fitting within bounds
                         .ignoresSafeArea() // Extend to edges for iPad
                         .overlay() {
                             albumTitle
                         }
                         .onAppear {
                             isFavorite = immichService.assetItems[currentIndex].isFavorite
                             setupPlayer()
                         }
                 }
                 // Transparent bar
                 if isBarVisible {
                     toolBar
                 } else {
                     videoButton
                 }
             }
         }
         .clipped()
         .ignoresSafeArea()
         .ignoresSafeArea()
         .navigationBarBackButtonHidden(true)// Hides the back button
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
                     showToolbar()
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
                     if isBarVisible {
                         if ((focusedButton == "privious" || focusedButton == "next" || focusedButton == "playpause")) {
                             isBarVisible = false
                         } else if focusedButton == "favorite" {
                             if entitlementManager.slideShowOfThumbnails || (immichService.assetItems[currentIndex].type == .video && !entitlementManager.playVideo && !entitlementManager.slideShowOfThumbnails) {
                                 focusedButton = "original"
                             } else {
                                 focusedButton = "playpause"
                             }
                             showToolbar()
                         } else {
                             focusedButton = "playpause"
                             showToolbar()
                         }
                     } else {
                         isBarVisible = true
                         focusedButton = "playpause"
                         showToolbar()
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
                 // focusedButton = "playpause"
                 if isBarVisible {
                     showToolbar()
                 }
             }
         }
         #endif
         .background(Color.black)
         .onAppear {
             showToolbar()
             setupPlayerMusic()
           }.onDisappear {
               playerMusic?.pause() // Optional: pause when view disappears
           }
         .animation(.easeInOut(duration: 1.0), value: isBarVisible)
         .onReceive(timer) { _ in
             if running && !playerViewModel.isVideoPlaying {
                 goToNextItem()
             }
         }
     }
    
    private func setupPlayerMusic() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set up audio session: \(error)")
        }
        guard let url = entitlementManager.musicURL else { return }
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
        } catch {
            print("Failed to set up audio session: \(error)")
        }
        // Add notification observer for when audio ends
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerMusic?.currentItem,
            queue: .main
        ) { [weak playerMusic] _ in
            playerMusic?.seek(to: .zero)
            if running {
                playerMusic?.play()
            }
        }
        if running && !(playerMusic?.isPlaying ?? true) {
            playerMusic?.play() // Auto-play on appear
        }
    }
    
    private func goToNextItem() {
        playerViewModel.stopPlayer()
        NotificationCenter.default.removeObserver(self)
        if !immichService.assetItems.isEmpty {
            currentIndex = (currentIndex + 1) % immichService.assetItems.count
            Task {
                if currentIndex == 0 && !(query?.noNextPage ?? true)  {
                    do {
                        query!.page = try await immichService.searchAssets(query: query!.toNext())
                    } catch let error {
                        print(error.localizedDescription)
                    }
                }
                if immichService.assetItems[currentIndex].exifInfo == nil {
                    exifInfo = try? await immichService.getAsset(id: immichService.assetItems[currentIndex].id).exifInfo
                } else {
                    exifInfo = immichService.assetItems[currentIndex].exifInfo
                }
                isFavorite = immichService.assetItems[currentIndex].isFavorite
                thumbnail = true
                setupPlayer()
            }
        }
        UIApplication.shared.sendAction(#selector(UIResponder.becomeFirstResponder), to: nil, from: nil, for: nil)
    }
    
    private func goToPreviousItem() {
        playerViewModel.stopPlayer()
        NotificationCenter.default.removeObserver(self)
        if !immichService.assetItems.isEmpty {
            Task {
                currentIndex = (currentIndex - 1 + immichService.assetItems.count) % immichService.assetItems.count
                if currentIndex == (immichService.assetItems.count - 1) && !(query?.noNextPage ?? true) {
                    do {
                        query!.page = try await immichService.searchAssets(query: query!.toPrevious())
                    } catch let error {
                        print(error.localizedDescription)
                    }
                }
                if immichService.assetItems[currentIndex].exifInfo == nil {
                    exifInfo = try? await immichService.getAsset(id: immichService.assetItems[currentIndex].id).exifInfo
                } else {
                    exifInfo = immichService.assetItems[currentIndex].exifInfo
                }
                isFavorite = immichService.assetItems[currentIndex].isFavorite
                thumbnail = true
                setupPlayer()
            }
        }
        UIApplication.shared.sendAction(#selector(UIResponder.becomeFirstResponder), to: nil, from: nil, for: nil)
    }
    
    private func setupPlayer() {
        if !isVideoAndPlayable { return } else {
            playerMusic?.pause()
            playerViewModel.setupPlayer(with: immichService.getVideoUrl(id: immichService.assetItems[currentIndex].id)!)
            
            // Add observer for when video ends
            NotificationCenter.default.addObserver(
                forName: AVPlayerItem.didPlayToEndTimeNotification,
                object: playerViewModel.player?.currentItem,
                queue: .main
            ) { _ in
                self.playerViewModel.player?.seek(to: .zero)
                self.playerViewModel.isVideoPlaying = false
                if running {
                    playerMusic?.play()
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
    @Published var isVideoPlaying = false
    
    func setupPlayer(with url: URL) {
        player = AVPlayer(url: url)
        // Check player status before playing
        self.player?.play()
        self.isVideoPlaying = true
    }
    
    func stopPlayer() {
        player?.pause()
        isVideoPlaying = false
    }
}

extension AVPlayer {
    var isPlaying: Bool {
        return rate != 0 && error == nil
    }
}

