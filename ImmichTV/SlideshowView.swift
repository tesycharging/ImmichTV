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

enum ButtonFocus: Hashable {
    case favorite
    case original
    case zoom
    case download
    case previous
    case playpause
    case next
    case videobutton
    case zoomout
    case image
    case close
    case none
}

struct SlideshowView: View {
    @EnvironmentObject private var immichService: ImmichService
    @EnvironmentObject private var entitlementManager: EntitlementManager
    let albumName: String?
    @State private var query: Query?
    @StateObject var playlistModel: PlaylistViewModel = PlaylistViewModel()
    
    @FocusState var focusedButton: ButtonFocus?
    @Environment(\.dismiss) var dismiss // For dismissing the full-screen view
    @State private var thumbnail = true
    @State private var isFavorite = false
    @State private var exifInfo: ExifInfo? = nil
    
    #if os(tvOS)
    #else
    @State private var swipeOffset: CGFloat = 0 // Tracks the swipe position
    #endif
    
    
    
    @State var zoomScale: CGFloat = 1.0 {
        didSet {
            if zoomScale == minScale {
                offsetStepX = 0
                offsetStepY = 0
                offset = .zero
            } else {
                playlistModel.isBarVisible = false
                playlistModel.running = false
                playlistModel.pause()
            }
        }
    }
    let minScale: CGFloat = 1.0
    let maxScale: CGFloat = 5.0
    @State var offsetStepX: CGFloat = 0
    @State var offsetStepY: CGFloat = 0
    @State var imageSize: CGSize = CGSizeZero
    @State var slideSize: CGSize = CGSizeZero
    @State var offset: CGSize = .zero

    @State private var startIndex: Int?
    ///
    /// Toolbar
    @State private var downloading = false
    #if os(tvOS)
    #else
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isSaving = false
    #endif
    
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
        return ((currentItem.type == .video && !thumbnail) ||
                (currentItem.type == .video && !entitlementManager.slideShowOfThumbnails && entitlementManager.playVideo))
    }
    
    var isFavoritable: Bool {
        !entitlementManager.demo && (currentItem.ownerId == immichService.user.id)
    }
    
    private var thumbnailShown: Bool {
        entitlementManager.slideShowOfThumbnails || (self.currentItem.type == .video && !entitlementManager.playVideo && !entitlementManager.slideShowOfThumbnails)
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
                         RetryableAsyncImage(url: immichService.getImageUrl(id: currentItem.id, thumbnail: entitlementManager.slideShowOfThumbnails && thumbnail, video: currentItem.type == .video), imageSize: $imageSize)
                             .background(.black)
                             .scaleEffect(zoomScale)
                             .focusable(playlistModel.isBarVisible ? false : true) // Only focus image when bar is hidden
                             .focused($focusedButton, equals: .image)
                             .frame(maxWidth: .infinity, maxHeight: .infinity)
                             .offset(x: offset.width, y: offset.height)
#if os(tvOS)
                             .pinchToZoom(minScale: minScale, maxScale: maxScale, zoomScale: $zoomScale)
#else
                             .pinchToZoom(swipeOffset: $swipeOffset, imageSize: $imageSize, offset: $offset, minScale: minScale, maxScale: maxScale, zoomScale: $zoomScale, playlistModel: playlistModel, assetItemsCount: assetItemsCount)
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
                     AVPlayerView(player: playlistModel.player)
                         .overlay() {
                             albumTitle
                         }
                         .onAppear {
                             isFavorite = currentItem.isFavorite
                             playlistModel.playVideo(url: immichService.getVideoUrl(id: currentItem.id)!, count: assetItemsCount)
                         }
                         .onDisappear {
                             playlistModel.pause()
                         }
                 }
                 // Transparent bar
                 if playlistModel.isBarVisible {
                     toolbarView
                 } else {
                     if zoomScale == minScale {
                         videoButton
                     } else {
                         zoomOutButton
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
                     thumbnail = true
                 }
                 if playlistModel.running {
                     playlistModel.play(duration: entitlementManager.timeinterval, count: assetItemsCount)
                 }
             }
         }
        #if os(tvOS)
         .tvOSCommand(timeinterval: entitlementManager.timeinterval, zoomScale: $zoomScale, minScale: minScale, maxScale: maxScale, slideSize: $slideSize, offsetStepX: $offsetStepX, offsetStepY: $offsetStepY, imageSize: $imageSize, offset: $offset, playlistModel: playlistModel, assetItemsCount: assetItemsCount, isFavoritable: isFavoritable, thumbnailShown: thumbnailShown, focusedButton: focusedButtonBinding)
        #else
         .offset(x: swipeOffset) // Moves the text based on swipe
         .mac_iosCommand(zoomScale: $zoomScale, swipeOffset: $swipeOffset, minScale: minScale, isBarVisible: $playlistModel.isBarVisible, playlistModel: playlistModel, assetItemsCount: assetItemsCount)
         #endif
         .background(Color.black)
         .onAppear {
             playlistModel.currentIndex = startIndex ?? 0
             playlistModel.running = startIndex == nil
             playlistModel.showToolbar()
             guard let url = entitlementManager.musicURL else { return }
             playlistModel.playMusicSetup(url: url)
             if playlistModel.running {
                 playlistModel.play(duration: entitlementManager.timeinterval, count: assetItemsCount)
             }
           }
         .onDisappear {
             playlistModel.player.pause()
         }
         .animation(.easeInOut(duration: 1.0), value: playlistModel.isBarVisible)
     }


////
/// Toolbar
///
    var toolbarView: some View {
        VStack(alignment: .center, spacing: 40) {
            HStack(alignment: .top) {
#if os(tvOS)
#else
                HStack {
                    Button(action: {
                        UIApplication.shared.isIdleTimerDisabled = false
                        dismiss()
                    }) {
                        Image(systemName: "x.square")
                    }.buttonStyle(ImmichTVSlideShowButtonStyle(isFocused: focusedButton == ButtonFocus.close))
                        .focused($focusedButton, equals: ButtonFocus.close)
                }.padding()
                    .background(Color.black.opacity(0.5)) // Transparent background
                    .cornerRadius(15)
                    .transition(.move(edge: .bottom).combined(with: .opacity)) // Slide and fade
                    .zIndex(1) // Ensure bar is above image
                    .padding(.top, 20)
#endif
                Spacer()
                VStack(alignment: .trailing) {
                    HStack {
                        if !entitlementManager.demo && (currentItem.ownerId == immichService.user.id){
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
                                Image(systemName: isFavorite ? "heart.fill" : "heart")
                            }.buttonStyle(ImmichTVSlideShowButtonStyle(isFocused: focusedButton == .favorite))
                                .focused($focusedButton, equals: .favorite)
                        }
                        if entitlementManager.slideShowOfThumbnails || (currentItem.type == .video && !entitlementManager.playVideo && !entitlementManager.slideShowOfThumbnails) {
                            Button(action: {
                                playlistModel.showToolbar()
                                playlistModel.running = false
                                playlistModel.pause()
                                thumbnail = false
                            }) {
                                Image(systemName: currentItem.type == .video ? "video" : "photo")
                            }.buttonStyle(ImmichTVSlideShowButtonStyle(isFocused: focusedButton == .original))
                                .focused($focusedButton, equals: .original)
                        }
                        Button(action: {
                            zoomScale = maxScale
                        }) {
                            Image(systemName: "plus.magnifyingglass")
                        }.buttonStyle(ImmichTVSlideShowButtonStyle(isFocused: focusedButton == .zoom))
                            .focused($focusedButton, equals: .zoom)
#if os(tvOS)
#else
#if targetEnvironment(macCatalyst)
                        #else
                        Button(action: {
                            Task { @MainActor in
                                do {
                                    downloading = true
                                    if currentItem.type == .image {
                                        alertMessage = try await immichService.downloadImage(currentIndex: currentIndex)
                                    } else {
                                        alertMessage = try await immichService.downloadVideo(currentIndex: currentIndex)
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
                        }.buttonStyle(ImmichTVSlideShowButtonStyle(isFocused: focusedButton == .download))
                            .focused($focusedButton, equals: .download)
                            .alert(isPresented: $showAlert) {
                                Alert(title: Text("Save Image"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
                            }
                        #endif
                        #endif
                    }.padding()
                        .background(Color.black.opacity(0.5)) // Transparent background
                        .cornerRadius(15)
                        .transition(.move(edge: .bottom).combined(with: .opacity)) // Slide and fade
                        .zIndex(1) // Ensure bar is above image
                        .padding(.top, 20)
                        .progressView(isPresented: $downloading, message: "downloading")
                    HStack {
                        if exifInfo != nil {
                            exifInfoView(exifInfo: exifInfo!, index: self.playlistModel.currentIndex + 1, page: ((query?.page ?? 2) - 1))
                        }
                    }.padding()
                        .background(Color.black.opacity(0.5)) // Transparent background
                        .cornerRadius(15)
                        .transition(.move(edge: .bottom).combined(with: .opacity)) // Slide and fade
                        .zIndex(1) // Ensure bar is above image
                }
            }
            Spacer()
            HStack(alignment: .bottom){
                Button(action: {
                    playlistModel.showToolbar()
                    playlistModel.previousItem(count: immichService.assetItems.count)
                    //self.goToPreviousItem()
                }) {
                    Image(systemName: "backward.frame").padding(.horizontal, 30)
                }.buttonStyle(ImmichTVSlideShowButtonStyle(isFocused: focusedButton == .previous))
                    .focused($focusedButton, equals: .previous)
                Button(action: {
                    playlistModel.showToolbar()
                    playlistModel.running.toggle()
                    if playlistModel.running {
                        playlistModel.showAlbumName = true
                        playlistModel.play(duration: entitlementManager.timeinterval, count: immichService.assetItems.count)
                    } else {
                        playlistModel.pause()
                    }
                }) {
                    Image(systemName: (!playlistModel.running ? "play" : "pause")).padding(.horizontal, 30)
                }.buttonStyle(ImmichTVSlideShowButtonStyle(isFocused: focusedButton == .playpause))
                    .focused($focusedButton, equals: .playpause)
                Button(action: {
                    playlistModel.showToolbar()
                    playlistModel.nextItem(count: immichService.assetItems.count)
                    //self.goToNextItem()
                }) {
                    Image(systemName: "forward.frame").padding(.horizontal, 30)
                }.buttonStyle(ImmichTVSlideShowButtonStyle(isFocused: focusedButton == .next))
                    .focused($focusedButton, equals: .next)
            }.padding()
                .background(Color.black.opacity(0.5)) // Transparent background
                .cornerRadius(15)
                .transition(.move(edge: .bottom).combined(with: .opacity)) // Slide and fade
                .zIndex(1) // Ensure bar is above image
                .padding(.bottom, 10)
        }.onAppear {
            #if os(tvOS)
            focusedButton = .playpause
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
        }
    }
    
    func exifInfoView(exifInfo: ExifInfo, index: Int, page: Int) -> some View {
        VStack(alignment: .trailing) {
            Text("\(currentItem.originalFileName) #\(index) of Page \(page)").font(.caption).foregroundColor(.white.opacity(0.8))
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
    
    var showVideoButton: Bool {
        if (currentItem.type == .video && thumbnail && (entitlementManager.slideShowOfThumbnails || (!entitlementManager.slideShowOfThumbnails && !entitlementManager.playVideo))) {
            focusedButton = .videobutton
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
                VStack(alignment: .trailing) {
                    HStack {
                        if (showVideoButton) {
                            Button(action: {
                                playlistModel.hideToolbar()
                                playlistModel.running = false
                                playlistModel.pause()
                                thumbnail = false
                            }) {
                                Image(systemName: currentItem.type == .video ? "video" : "photo")
                            }.buttonStyle(ImmichTVSlideShowButtonStyle(isFocused: focusedButton == .videobutton))
                                .focused($focusedButton, equals: .videobutton)
                        }
                    }.padding()
                        .background(Color.black.opacity(0.5)) // Transparent background
                        .cornerRadius(15)
                        .transition(.move(edge: .bottom).combined(with: .opacity)) // Slide and fade
                        .zIndex(1) // Ensure bar is above image
                        .padding(.top, 20)
                }
            }
            Spacer()
        }
    }
    
    var zoomOutButton: some View {
        VStack(alignment: .center, spacing: 40) {
            HStack(alignment: .top) {
                Spacer()
                HStack {
                    VStack(alignment: .trailing) {
                        Button(action: {
                            zoomScale = minScale
                            playlistModel.showToolbar()
                        }) {
                            Image(systemName: "minus.magnifyingglass")
                        }.buttonStyle(ImmichTVSlideShowButtonStyle(isFocused: focusedButton == .zoomout))
                            .focused($focusedButton, equals: .zoomout)
                            .onAppear{
                                focusedButton = .zoomout
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
}

