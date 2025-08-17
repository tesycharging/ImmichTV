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
    
    @State private var zoomScale: CGFloat = 1.0 {
        didSet {
            if zoomScale == minScale {
                offsetStepX = 0
                offsetStepY = 0
                offset = .zero
            } else {
                isBarVisible = false
                running = false
            }
        }
    }
    private let minScale: CGFloat = 1.0
    private let maxScale: CGFloat = 5.0
    @State private var offsetStepX: CGFloat = 0
    @State private var offsetStepY: CGFloat = 0
    @State private var imageSize: CGSize = CGSizeZero
    @State private var slideSize: CGSize = CGSizeZero
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
#if os(tvOS)
    #else
    @State private var lastScale: CGFloat = 1.0
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isSaving = false
    #endif
    @State private var downloading = false
    
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
                VStack(alignment: .trailing) {
                    HStack {
                        if (showVideoButton) {
                            Button(action: {
                                timerSubscription?.cancel()
                                timerSubscription = nil
                                running = false
                                thumbnail = false
                            }) {
                                Image(systemName: immichService.assetItems[currentIndex].type == .video ? "video" : "photo")
                            }.buttonStyle(ImmichTVSlideShowButtonStyle(isFocused: focusedButton == "videoButton"))
                                .focused($focusedButton, equals: "videoButton")
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
                            showToolbar()
                        }) {
                            Image(systemName: "minus.magnifyingglass")
                        }.buttonStyle(ImmichTVSlideShowButtonStyle(isFocused: focusedButton == "zoomout"))
                            .focused($focusedButton, equals: "zoomout")
                            .onAppear{
                                focusedButton = "zoomout"
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
                        Image(systemName: "x.square")
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
                VStack(alignment: .trailing) {
                    HStack {
                        if !entitlementManager.demo && (immichService.assetItems[currentIndex].ownerId == immichService.user.id){
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
                                Image(systemName: isFavorite ? "heart.fill" : "heart")
                            }.buttonStyle(ImmichTVSlideShowButtonStyle(isFocused: focusedButton == "favorite"))
                                .focused($focusedButton, equals: "favorite")
                        }
                        if entitlementManager.slideShowOfThumbnails || (immichService.assetItems[currentIndex].type == .video && !entitlementManager.playVideo && !entitlementManager.slideShowOfThumbnails) {
                            Button(action: {
                                showToolbar()
                                running = false
                                thumbnail = false
                            }) {
                                Image(systemName: immichService.assetItems[currentIndex].type == .video ? "video" : "photo")
                            }.buttonStyle(ImmichTVSlideShowButtonStyle(isFocused: focusedButton == "original"))
                                .focused($focusedButton, equals: "original")
                        }
                        Button(action: {
                            zoomScale = maxScale
                        }) {
                            Image(systemName: "plus.magnifyingglass")
                        }.buttonStyle(ImmichTVSlideShowButtonStyle(isFocused: focusedButton == "zoom"))
                            .focused($focusedButton, equals: "zoom")
#if os(tvOS)
#else
#if targetEnvironment(macCatalyst)
                        #else
                        Button(action: {
                            Task { @MainActor in
                                do {
                                    downloading = true
                                    if immichService.assetItems[currentIndex].type == .image {
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
                        }.buttonStyle(ImmichTVSlideShowButtonStyle(isFocused: focusedButton == "downdload"))
                            .focused($focusedButton, equals: "downdload")
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
                            exifInfoView(exifInfo: exifInfo!)
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
     
#if os(tvOS)
    private func zoomOffset(direction: MoveCommandDirection, slideSize: CGSize) {
        let maxOffsetStep: CGFloat = (maxScale - minScale) / 2
        let isPortrait = imageSize.height > imageSize.width
        switch direction {
        case .left:
            offsetStepX = offsetStepX == maxOffsetStep ? maxOffsetStep : offsetStepX + 1
            if !isPortrait {
                offset.width = slideSize.width * offsetStepX
            } else {
                let blackX = offsetStepX > 0 ? (slideSize.width - imageSize.width / (imageSize.height / slideSize.height)) / 2 : (slideSize.width - imageSize.width / (imageSize.height / slideSize.height)) / -2
                let width = imageSize.width / (imageSize.height / slideSize.height) * zoomScale
                if (width / slideSize.width) <= 1 || offsetStepX == 0 {
                    offset.width = 0
                } else if (width / slideSize.width) <= (maxOffsetStep + 1) || offsetStepX == maxOffsetStep {
                    offset.width = blackX == 0 ? blackX + offsetStepX * slideSize.width : blackX
                } else {
                    offset.width = blackX + offsetStepX * slideSize.width
                }
            }
        case .right:
            offsetStepX = offsetStepX == (-1 * maxOffsetStep) ? -maxOffsetStep : offsetStepX - 1
            if !isPortrait {
                offset.width = slideSize.width * offsetStepX
            } else {
                let blackX = offsetStepX > 0 ? (slideSize.width - imageSize.width / (imageSize.height / slideSize.height)) / 2 : (slideSize.width - imageSize.width / (imageSize.height / slideSize.height)) / -2
                let width = imageSize.width / (imageSize.height / slideSize.height) * zoomScale
                if (width / slideSize.width) <= 1 || offsetStepX == 0 {
                    offset.width = 0
                } else if (width / slideSize.width) <= (maxOffsetStep + 1) || offsetStepX == maxOffsetStep {
                    offset.width = blackX == 0 ? blackX + offsetStepX * slideSize.width : blackX
                } else {
                    offset.width = blackX + offsetStepX * slideSize.width
                }
            }
        case .up:
            offsetStepY = offsetStepY == maxOffsetStep ? maxOffsetStep : offsetStepY + 1
            if isPortrait {
                offset.height = slideSize.height * offsetStepY
            } else {
                let blackY = offsetStepY > 0 ? (slideSize.height - imageSize.height / (imageSize.width / slideSize.width)) / 2 : (slideSize.height - imageSize.height / (imageSize.width / slideSize.width)) / -2
                let height = imageSize.height / (imageSize.width / slideSize.width) * zoomScale
                if (height / slideSize.height) <= 1 || offsetStepY == 0 {
                    offset.height = 0
                } else if (height / slideSize.height) <= (maxOffsetStep + 1) || offsetStepY == maxOffsetStep {
                    offset.height = blackY == 0 ? blackY + offsetStepY * slideSize.height : blackY
                } else {
                    offset.height = blackY + offsetStepY * slideSize.height
                }
            }
        case .down:
            offsetStepY = offsetStepY == (-1 * maxOffsetStep) ? -maxOffsetStep : offsetStepY - 1
            if isPortrait {
                offset.height = slideSize.height * offsetStepY
            } else {
                let blackY = offsetStepY > 0 ? (slideSize.height - imageSize.height / (imageSize.width / slideSize.width)) / 2 : (slideSize.height - imageSize.height / (imageSize.width / slideSize.width)) / -2
                let height = imageSize.height / (imageSize.width / slideSize.width) * zoomScale
                if (height / slideSize.height) <= 1 || offsetStepY == 0 {
                    offset.height = 0
                } else if (height / slideSize.height) <= (maxOffsetStep + 1) || offsetStepY == maxOffsetStep {
                    offset.height = blackY == 0 ? blackY + offsetStepY * slideSize.height : blackY
                } else {
                    offset.height = blackY + offsetStepY * slideSize.height
                }
            }
        @unknown default:
            break
        }
        focusedButton = "zoomout"
    }
    
    private func arrowCommands(direction: MoveCommandDirection) {
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
    #endif
    // Clamp offset to keep image within viewable bounds
    private func clampOffset(for scale: CGFloat) {
        let scaledSize = CGSize(
            width: imageSize.width * scale,
            height: imageSize.height * scale
        )
        let maxOffsetX = (scaledSize.width - imageSize.width) / 2
        let maxOffsetY = (scaledSize.height - imageSize.height) / 2
        
        offset.width = min(max(offset.width, -maxOffsetX), maxOffsetX)
        offset.height = min(max(offset.height, -maxOffsetY), maxOffsetY)
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
                     GeometryReader { g in
                         RetryableAsyncImage(url: immichService.getImageUrl(id: immichService.assetItems[currentIndex].id, thumbnail: entitlementManager.slideShowOfThumbnails && thumbnail, video: immichService.assetItems[currentIndex].type == .video), imageSize: $imageSize)
                             .background(.black)
                             .scaleEffect(zoomScale)
                             .focusable(isBarVisible ? false : true) // Only focus image when bar is hidden
                             .focused($focusedButton, equals: "image")
                             .frame(maxWidth: .infinity, maxHeight: .infinity)
                             .offset(x: offset.width, y: offset.height)
#if os(tvOS)
                             .onTapGesture(count: 1) {
                                 withAnimation(.easeInOut) {
                                     // Toggle between min and max scale
                                     zoomScale = zoomScale == minScale ? maxScale : minScale
                                 }
                             }
#else
                             .gesture(
                                // Pinch-to-zoom
                                MagnifyGesture()
                                    .onChanged { value in
                                        let newScale = max(min(lastScale * value.magnification, maxScale), minScale)
                                        zoomScale = newScale
                                        clampOffset(for: newScale)
                                    }
                                    .onEnded { _ in
                                        lastScale = zoomScale
                                        clampOffset(for: zoomScale)
                                    }
                                    .simultaneously(with: DragGesture()
                                        .onChanged { value in
                                            if zoomScale == minScale {
                                                // Update offset while dragging
                                                swipeOffset = value.translation.width
                                            } else {
                                                let newOffset = CGSize(
                                                    width: lastOffset.width + value.translation.width,
                                                    height: lastOffset.height + value.translation.height
                                                )
                                                offset = newOffset
                                                clampOffset(for: zoomScale)
                                            }
                                        }
                                        .onEnded { value in
                                            if zoomScale == minScale {
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
                                            } else {
                                                lastOffset = offset
                                                clampOffset(for: zoomScale)
                                            }
                                        }
                                                   )
                             )
                             .gesture(
                                // Double-tap to toggle zoom
                                TapGesture(count: 2)
                                    .onEnded {
                                        withAnimation(.easeInOut) {
                                            if zoomScale > minScale {
                                                // Reset to default
                                                zoomScale = minScale
                                                offset = .zero
                                                lastScale = minScale
                                                lastOffset = .zero
                                            } else {
                                                // Zoom to 2x
                                                zoomScale = 2.0
                                                lastScale = 2.0
                                                clampOffset(for: 2.0)
                                            }
                                        }
                                    }
                             )
#endif
                             .overlay() {
                                 albumTitle
                             }
                             .onAppear {
                                 isFavorite = immichService.assetItems[currentIndex].isFavorite
                                 slideSize = g.size
                             }
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
         .ignoresSafeArea()
         .navigationBarBackButtonHidden(true)// Hides the back button
        #if os(tvOS)
         .onPlayPauseCommand {
             running.toggle()
             if running {
                 showAlbumName = true
                 zoomScale = minScale
             }
         }
         .onMoveCommand { direction in // Handle arrow key/remote input
             if zoomScale > minScale {
                 zoomOffset(direction: direction, slideSize: slideSize)
             } else {
                 arrowCommands(direction: direction)
             }
         }
        #else
         .offset(x: swipeOffset) // Moves the text based on swipe
         .onTapGesture(count: 1) {
             if zoomScale == minScale {
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
         }
         .gesture(
            LongPressGesture(minimumDuration: 1)
                .onEnded { _ in
                withAnimation {
                    UIApplication.shared.isIdleTimerDisabled = false
                    dismiss()
                }
            }
         )
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

extension View {
    func progressView(
        isPresented: Binding<Bool>,
        message: String
    ) -> some View {
        fullScreenCover(isPresented: isPresented) {
            VStack {
                ProgressView().progressViewStyle(CircularProgressViewStyle()).scaleEffect(1.5) // Optional: Adjust size
                    .tint(Color.primary)
                Text("\(message)").multilineTextAlignment(.center)
                
            }.padding()
                .frame(maxWidth: .infinity)
                .background(Color.secondary)
                .cornerRadius(35)
                .padding()
                .transition(.slide)
            .presentationBackground(.clear)
        }.transaction { transaction in
            if isPresented.wrappedValue {
                // disable the default FullScreenCover animation
                transaction.disablesAnimations = true
                
                // add custom animation for presenting and dismissing the FullScreenCover
                transaction.animation = .linear(duration: 0.1)
            }
        }
    }
}

