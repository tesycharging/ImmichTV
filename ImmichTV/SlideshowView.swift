//
//  SlideshowView.swift
//  ImmichTV
//
//  Created by David Lüthi on 17.03.2025.
//

import SwiftUI
import Foundation
import Combine
import AVKit
import AVFoundation
import UIKit
#if os(tvOS)
    #else
import Photos
#endif

enum ButtonFocus: Hashable, CaseIterable {
    case close
    case previous
    case playpause
    case next
    case favorite
    case original
    case zoom
    case setting
    case player
    case image
    case originalVideo
    case none
    
    func image(_ status: Bool = true, _ active: Bool = false) -> Image {
        switch self {
        case .close: return Image(systemName: "x.circle")
        case .previous: return Image(systemName: "chevron.left")
        case .playpause: return Image(systemName: (status ? "play" : "pause"))
        case .next: return Image(systemName: "chevron.right")
        case .favorite: return Image(systemName: status ? "heart.fill" : "heart")
        case .original: return Image(systemName: status ? (active ? "video.fill" : "video") : (active ? "photo.fill" : "photo"))
        case .zoom: return Image(systemName: status ? "plus.magnifyingglass" : "minus.magnifyingglass")
        case .setting: return Image(systemName: "gear")
        default: return Image(systemName: "x.circle")
        }
    }
    
    // Computed property to get the next enum case
    var next: ButtonFocus {
        // Get all cases
        let allCases = ButtonFocus.allCases
        // Find the current case's index
        guard let currentIndex = allCases.firstIndex(of: self) else {
            return self // Fallback to self if index not found
        }
        // Calculate the next index, looping back to 0 if at the end
        let nextIndex = (currentIndex + 1) % allCases.count
        return allCases[nextIndex]
    }
    
    // Computed property to get the previous enum case
    var previous: ButtonFocus {
        // Get all cases
        let allCases = ButtonFocus.allCases
        // Find the current case's index
        guard let currentIndex = allCases.firstIndex(of: self) else {
            return self // Fallback to self if index not found
        }
        // Calculate the next index, looping back to 0 if at the end
        let nextIndex = ((currentIndex == 0 ? allCases.count : currentIndex) - 1) % allCases.count
        return allCases[nextIndex]
    }
}

struct SlideshowView: View {
    @EnvironmentObject private var immichService: ImmichService
    @EnvironmentObject private var entitlementManager: EntitlementManager
    /*#if os(tvOS)
    @EnvironmentObject private var storeManager: StoreManager
    #endif*/
    let albumName: String?
    @State private var query: Query?
    @StateObject var playlistModel: PlaylistViewModel = PlaylistViewModel()
    
    @FocusState var focusedButton: ButtonFocus?
    @State var lastFocusedButton: ButtonFocus?
    @State var disableddButtons: [ButtonFocus] = []
    @Environment(\.dismiss) var dismiss // For dismissing the full-screen view
    @State private var switchFromThumbnailToVideo = false
    @State private var isFavorite = false
    @State private var isZoomed = false
    @State private var exifInfo: ExifInfo? = nil
    @State private var showSetting = false
    
    #if os(tvOS)
    #else
    @State private var swipeOffset: CGFloat = 0 // Tracks the swipe position
    #endif
    
    
    
    @State var zoomScale: CGFloat = 1.0 {
        didSet {
            if zoomScale == minScale {
#if os(tvOS)
                offsetStep = .zero
#endif
                offset = .zero
            } else {
                playlistModel.hideToolbar()
                playlistModel.pausePlaylist()
            }
        }
    }
    let minScale: CGFloat = 1.0
    let maxScale: CGFloat = 5.0

    @State var imageSize: CGSize = CGSizeZero
    @State var slideSize: CGSize = CGSizeZero
    @State var offset: CGSize = .zero

    @State private var startIndex: Int?
    ///
    /// Toolbar
    @State private var downloading = false
    #if os(tvOS)
    @State var offsetStep: CGSize = CGSizeZero
    #else
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isSaving = false
    #endif
    @State private var purchased = true // only tvOS can purchase it
    
    init(albumName: String? = nil, index: Int? = nil, query: Query? = nil) {
        self.albumName = albumName
        self._query = State(initialValue: query)
        self._startIndex = State(initialValue: index)
    }
    
    // Create a Binding<ButtonFocus?> from FocusState
   private var focusedButtonBinding: Binding<ButtonFocus?> {
       Binding(
           get: { focusedButton },
           set: { focusedButton = $0 }
       )
   }
    
    var albumTitle: some View {
        VStack(alignment: .center) {
            if let aName = albumName, playlistModel.showAlbumName {
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
    
    var currentItem: AssetItem {
        immichService.assetItems[playlistModel.currentIndex]
    }
    
    var assetItemsCount: Int {
        immichService.assetItems.count
    }
    
    private var isVideoAndPlayable: Bool {
        return ((currentItem.type == .video && !playlistModel.thumbnail) ||
                (currentItem.type == .video && !entitlementManager.slideShowOfThumbnails && entitlementManager.playVideo))
    }
    
    private var thumbnailShown: Bool {
        entitlementManager.slideShowOfThumbnails || (self.currentItem.type == .video && !entitlementManager.playVideo && !entitlementManager.slideShowOfThumbnails)
    }
    
    var hasFavoriteButton: Bool {
        !entitlementManager.demo && (currentItem.ownerId == immichService.user.id)
    }
    
    var hasOriginalButton: Bool {
        (!isMac() || (isMac() && currentItem.type != .video)) && (entitlementManager.slideShowOfThumbnails || (currentItem.type == .video && !entitlementManager.playVideo && !entitlementManager.slideShowOfThumbnails))
    }
    
     var body: some View {
         ZStack(alignment: .center) {
             Color.black.edgesIgnoringSafeArea(.all) // Full-screen black background
             if immichService.assetItems.isEmpty {
                 Spacer()
                 Text("No pictures found").font(.title)
                 Spacer()
             } else {
                 if !isVideoAndPlayable {
                     GeometryReader { g in
                         RetryableAsyncImage(url: immichService.getImageUrl(id: currentItem.id, thumbnail: entitlementManager.slideShowOfThumbnails && playlistModel.thumbnail, video: currentItem.type == .video), imageSize: $imageSize, video: currentItem.type == .video)
                             .background(.black)
                             .scaleEffect(zoomScale)
                             .focusable(playlistModel.showControls ? false : true) // Only focus image when bar is hidden
                             .focused($focusedButton, equals: .image)
                             .frame(maxWidth: .infinity, maxHeight: .infinity)
                             .offset(x: offset.width, y: offset.height)
#if os(tvOS)
                             .pinchToZoom(minScale: minScale, maxScale: maxScale, zoomScale: $zoomScale, playlistModel: playlistModel).disabled(!purchased || isVideoAndPlayable)
#else
                             .pinchToZoom(swipeOffset: $swipeOffset, imageSize: $imageSize, offset: $offset, minScale: minScale, maxScale: maxScale, zoomScale: $zoomScale, playlistModel: playlistModel, assetItemsCount: assetItemsCount).disabled(isVideoAndPlayable)
#endif
                             .overlay() {
                                 albumTitle
                             }
                             .onAppear {
                                 isFavorite = currentItem.isFavorite
                                 slideSize = g.size
                             }
                     }
                 } else {
                     // Video playback
                     AVPlayerView(player: playlistModel.player, playlistModel: playlistModel)
                         .overlay() {
                             albumTitle
                         }
                         .onAppear {
                             isFavorite = currentItem.isFavorite
                             if switchFromThumbnailToVideo {
                                 switchFromThumbnailToVideo = false
                                 playlistModel.playVideo(url: immichService.getVideoUrl(id: currentItem.id)!, count: assetItemsCount)
                             }
                             // Request focus when the view appears
                             DispatchQueue.main.async {
                                 if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                                    let window = windowScene.windows.first {
                                     window.rootViewController?.view.becomeFirstResponder()
                                 }
                             }
                         }
                         .focusable(true) // Makes the view focusable on tvOS
                         .focused($focusedButton, equals: .player)
                 }
                 // Transparent bar
                 if purchased {
                     if playlistModel.showControls {
                         toolbarView.padding(.top, isTVOS() ? 20 : 50).padding(.leading, isIOS() ? 10 : 20).padding(.trailing, isIOS() ? 10 : 20)
                     }
                 }
             }
         }
         .clipped()
         .ignoresSafeArea()
         .navigationBarBackButtonHidden(true)// Hides the back button
         .onChange(of: playlistModel.currentIndex) { newValue, oldValue in
             if !immichService.assetItems.isEmpty {
                 Task {
                     if playlistModel.currentIndex == 0 && !(query?.noNextPage ?? true)  {
                         do {
                             query!.page = try await immichService.searchAssets(query: query!.toNext())
                         } catch let error {
                             print(error.localizedDescription)
                         }
                     } else if playlistModel.currentIndex == (assetItemsCount - 1) && !(query?.noNextPage ?? true) {
                         do {
                             query!.page = try await immichService.searchAssets(query: query!.toPrevious())
                         } catch let error {
                             print(error.localizedDescription)
                         }
                     }
                     if currentItem.exifInfo == nil {
                         exifInfo = try? await immichService.getAsset(id: currentItem.id).exifInfo
                     } else {
                         exifInfo = currentItem.exifInfo
                     }
                     isFavorite = currentItem.isFavorite
                     playlistModel.thumbnail = true
                 }
                 if isVideoAndPlayable {
                     playlistModel.playVideo(url: immichService.getVideoUrl(id: currentItem.id)!, count: assetItemsCount)
                 } else if playlistModel.running {
                     playlistModel.startImageTimer(duration: entitlementManager.timeinterval, count: assetItemsCount)
                 }
             }
         }
#if os(tvOS)
         .onChange(of: focusedButton) { oldValue, _ in
             lastFocusedButton = oldValue
         }
         .onChange(of: zoomScale) {
             offset.width = 0
             offset.height = 0
             isZoomed = zoomScale != minScale
         }
         .tvOSCommand(timeinterval: entitlementManager.timeinterval, zoomScale: $zoomScale, minScale: minScale, maxScale: maxScale, slideSize: $slideSize, offsetStep: $offsetStep, imageSize: $imageSize, offset: $offset, playlistModel: playlistModel, assetItemsCount: assetItemsCount, isFavoritable: hasFavoriteButton, thumbnailShown: thumbnailShown, focusedButton: focusedButtonBinding, lastFocusedButton: $lastFocusedButton, disableddButtons: $disableddButtons, isVideoAndPlayable: isVideoAndPlayable).disabled(!purchased)
#else
         .offset(x: swipeOffset) // Moves the text based on swipe
         .mac_iosCommand(zoomScale: $zoomScale, swipeOffset: $swipeOffset, minScale: minScale, playlistModel: playlistModel, assetItemsCount: assetItemsCount)
#endif
         .background(Color.black)
         .onAppear {
             /*#if os(tvOS)
             self.purchased = storeManager.appinIsPurchased
             #endif*/
             playlistModel.currentIndex = startIndex ?? 0
             playlistModel.running = startIndex == nil
             playlistModel.showToolbar()
             guard let url = entitlementManager.musicURL else { return }
             playlistModel.playMusicSetup(url: url)
             if playlistModel.running && !isVideoAndPlayable {
                 playlistModel.startImageTimer(duration: entitlementManager.timeinterval, count: assetItemsCount)
             } else if isVideoAndPlayable {
                 playlistModel.playVideo(url: immichService.getVideoUrl(id: currentItem.id)!, count: assetItemsCount)
             }
         }
         .onDisappear {
             playlistModel.deinitPlaylist()
         }
         .animation(.easeInOut(duration: 1.0), value: playlistModel.showControls)
         .sheet(isPresented: $showSetting) {
             ExifInfoView(currentItem: currentItem, exifInfo: exifInfo, index: self.playlistModel.currentIndex + 1, page: ((query?.page ?? 2) - 1))
         }
/*#if os(tvOS)
         .overlay{
             if !purchased {
                 InAppPurchaseView(purchased: $purchased)
             }
         }
#endif*/
     }
    
    ////
    /// Toolbar
    ///
    var toolbarView: some View {
        // Custom navigation buttons
        VStack(alignment: .leading) {
            HStack(spacing: isIOS() ? 10 : 20) {
               // Close button
               Button(action: {
                   UIApplication.shared.isIdleTimerDisabled = false
                   dismiss()
               }){
                   ButtonFocus.close.image()
               }.buttonStyle(FancySlideShowButtonStyle(isFocused: focusedButton == ButtonFocus.close, isDisabled: isZoomed))
                   .focused($focusedButton, equals: ButtonFocus.close)
                   .disabled(isZoomed)
              
               // Previous button
               Button(action: {
                   playlistModel.showToolbar()
                   playlistModel.previousItem(count: immichService.assetItems.count)
               }){
                   ButtonFocus.previous.image()
               }.buttonStyle(FancySlideShowButtonStyle(isFocused: focusedButton == ButtonFocus.previous, isDisabled: isZoomed))
                   .focused($focusedButton, equals: ButtonFocus.previous)
                   .disabled(isZoomed)
               
               // Play/Pause button
               Button(action: {
                   playlistModel.showToolbar()
                   playlistModel.running.toggle()
                   if !isVideoAndPlayable {
                       if playlistModel.running {
                           playlistModel.showAlbumName = true
                           playlistModel.startImageTimer(duration: entitlementManager.timeinterval, count: assetItemsCount)
                       } else {
                           playlistModel.pausePlaylist()
                       }
                   }
               }) {
                   ButtonFocus.playpause.image(!playlistModel.running)
               }.buttonStyle(FancySlideShowButtonStyle(isFocused: focusedButton == .playpause, isDisabled: isZoomed))
                   .focused($focusedButton, equals: .playpause)
                   .disabled(isZoomed)
               
               // Next button
               Button(action: {
                   playlistModel.showToolbar()
                   playlistModel.nextItem(count: immichService.assetItems.count)
               }) {
                   ButtonFocus.next.image()
               }.buttonStyle(FancySlideShowButtonStyle(isFocused: focusedButton == .next, isDisabled: isZoomed))
                   .focused($focusedButton, equals: .next)
                   .disabled(isZoomed)
               
               Spacer()
               
               // Favorite button
               Button(action: {
                   playlistModel.showToolbar()
                   Task {@MainActor in
                       do {
                           let updatedAssetItem = try await immichService.updateAssets(id: currentItem.id, favorite: !currentItem.isFavorite)
                           guard !immichService.assetItems.isEmpty, playlistModel.currentIndex < immichService.assetItems.count else { return }
                           isFavorite = updatedAssetItem.isFavorite
                           immichService.assetItems.remove(at: playlistModel.currentIndex)
                           immichService.assetItems.insert(updatedAssetItem, at: playlistModel.currentIndex)
                       } catch {
                           print(error.localizedDescription)
                       }
                   }
               }) {
                   ButtonFocus.favorite.image(isFavorite)
               }.buttonStyle(FancySlideShowButtonStyle(isFocused: focusedButton == .favorite, isDisabled: !hasFavoriteButton || isZoomed))
                   .focused($focusedButton, equals: .favorite)
                   .disabled(!hasFavoriteButton || isZoomed)
               
               // Original button (show video or pic)
               Button(action: {
                   if !isMac() || currentItem.type != .video {
                       playlistModel.showToolbar()
                       playlistModel.running = false
                       playlistModel.pausePlaylist()
                       playlistModel.thumbnail.toggle()
                       if currentItem.type == .video {
                           switchFromThumbnailToVideo = true
                       }
                   }
               }) {
                   ButtonFocus.original.image(currentItem.type == .video, !playlistModel.thumbnail)
               }.buttonStyle(FancySlideShowButtonStyle(isFocused: focusedButton == .original, isDisabled: (disableddButtons.contains(.original) && currentItem.type != .video) || (disableddButtons.contains(.originalVideo) && currentItem.type == .video) || isZoomed))
                   .focused($focusedButton, equals: .original)
                   .disabled((disableddButtons.contains(.original) && currentItem.type != .video) || (disableddButtons.contains(.originalVideo) && currentItem.type == .video) || isZoomed)
               
               // Zoom button
               Button(action: {
                   isZoomed = zoomScale == minScale
                   zoomScale = isZoomed ? maxScale : minScale
                   playlistModel.showToolbar()
               }) {
                   ButtonFocus.zoom.image(zoomScale == minScale)
               }.buttonStyle(FancySlideShowButtonStyle(isFocused: focusedButton == .zoom, isDisabled: isVideoAndPlayable))
                   .focused($focusedButton, equals: .zoom)
                   .disabled(isVideoAndPlayable)
               
               // Download button
                #if os(tvOS)
                #else
                #if targetEnvironment(macCatalyst)
                #else
                Button(action: {
                    Task { @MainActor in
                        do {
                            downloading = true
                            if currentItem.type == .image {
                                alertMessage = try await immichService.downloadImage(currentIndex: playlistModel.currentIndex)
                            } else {
                                alertMessage = try await immichService.downloadVideo(currentIndex: playlistModel.currentIndex)
                            }
                        } catch {
                            alertMessage = error.localizedDescription
                        }
                        downloading = false
                        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.2) {
                            showAlert = true
                        }
                    }
                }) {
                    Image(systemName: "arrow.down.app")
                }.buttonStyle(FancySlideShowButtonStyle(isFocused: focusedButton == ButtonFocus.none, isDisabled: isZoomed))
                    .disabled(isZoomed)
                    .alert(isPresented: $showAlert) {
                        Alert(title: Text("Save Image"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
                    }
                    .progressView(isPresented: $downloading, message: "downloading")
                #endif
                #endif
               
               // Setting Button
               Button(action: {
                   showSetting.toggle()
               }) {
                   ButtonFocus.setting.image()
               }.buttonStyle(FancySlideShowButtonStyle(isFocused: focusedButton == .setting, isDisabled: isZoomed))
                   .focused($focusedButton, equals: .setting)
                   .disabled(isZoomed)
           }
           .padding(.bottom, 40) // Space from bottom for better visibility
            Spacer()
        }.onAppear {
            focusedButton = .playpause
            disableddButtons.append(ButtonFocus.player)
            disableddButtons.append(ButtonFocus.image)
            disableddButtons.append(ButtonFocus.none)
            if !hasFavoriteButton {
                disableddButtons.append(ButtonFocus.favorite)
            } else {
                disableddButtons.removeAll { $0 == ButtonFocus.favorite }
            }
            if !entitlementManager.slideShowOfThumbnails {
                disableddButtons.append(ButtonFocus.original)
            } else {
                disableddButtons.removeAll { $0 == ButtonFocus.original }
            }
            #if targetEnvironment(macCatalyst)
            disableddButtons.append(ButtonFocus.originalVideo)
            #else
            if entitlementManager.slideShowOfThumbnails {
                disableddButtons.removeAll { $0 == ButtonFocus.originalVideo }
            } else {
                if  entitlementManager.playVideo {
                    disableddButtons.append(ButtonFocus.originalVideo)
                } else {
                    disableddButtons.removeAll { $0 == ButtonFocus.originalVideo }
                }
            }
            #endif
            if currentItem.exifInfo == nil {
                Task {
                    if let exif = try? await immichService.getAsset(id: currentItem.id).exifInfo {
                        exifInfo = exif
                    }
                }
            } else {
                exifInfo = currentItem.exifInfo!
            }
        }.onChange(of: hasFavoriteButton) { _, newValue in
            if !newValue {
                disableddButtons.append(ButtonFocus.favorite)
            } else {
                disableddButtons.removeAll { $0 == ButtonFocus.favorite }
            }
        }.onChange(of: isVideoAndPlayable) { _, newValue in
            if newValue {
                disableddButtons.append(ButtonFocus.zoom)
            } else {
                disableddButtons.removeAll { $0 == ButtonFocus.zoom }
            }
        }
   }
}


struct SlideShowButton: View {
    let icon: String
    let action: () -> Void
    @FocusState var focusedButton: ButtonFocus?
    let isDisabled: Bool
    
    @Environment(\.isFocused) var isFocused // Detect focus on tvOS
    
    var body: some View {
        Button(action: action){
            Image(systemName: icon).resizable().scaledToFit().frame(width: isIOS() ? 32 : 80, height: isIOS() ? 32 : 80)
        }.buttonStyle(FancySlideShowButtonStyle(isFocused: focusedButton == ButtonFocus.close, isDisabled: isDisabled))
            .focused($focusedButton, equals: ButtonFocus.close)
    }
}

struct FancySlideShowButtonStyle: ButtonStyle {
    let isFocused: Bool
    let isDisabled: Bool
    
    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label.disabled(isDisabled)
            .scaledToFit().frame(width: configuration.label.isIOS() ? 32 : 80, height: configuration.label.isIOS() ? 32 : 80)
            .foregroundColor(isFocused || configuration.isPressed ? .black : (isDisabled ? .black.opacity(0.5): .white))
            .background(Color.white.opacity(isFocused || configuration.isPressed ? 1.0 : 0.2))
            .clipShape(Circle())
            .shadow(color: .white.opacity(isFocused || configuration.isPressed ? 1.0 : 0.2), radius: 5, x: 0, y: 2)
            .focusable(configuration.label.isTVOS())
    }
}
