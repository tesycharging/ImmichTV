//
//  SlideshowViewExtIOS_MACOS.swift
//  ImmichTV
//
//  Created by David Lüthi on 20.08.2025.
//

import SwiftUI
import Foundation
import Combine

struct PinchToZoomModifier: ViewModifier {
    @Binding var swipeOffset: CGFloat
    @Binding var imageSize: CGSize
    @Binding var offset: CGSize
    var minScale: CGFloat
    var maxScale: CGFloat
    @Binding var zoomScale: CGFloat
    @ObservedObject var playlistModel: PlaylistViewModel
    let assetItemsCount: Int
    
    @State private var lastScale: CGFloat = 1.0
    @State private var lastOffset: CGSize = .zero
    
    
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
    
    func body(content: Content) -> some View {
        content.gesture(
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
                                    playlistModel.previousItem(count: assetItemsCount)
                                    withAnimation {
                                        swipeOffset = 100 // Move right
                                    }
                                } else if value.translation.width < -50 {
                                    playlistModel.nextItem(count: assetItemsCount)
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
    }
}

struct MAC_IOSCommand: ViewModifier {
    @Binding var zoomScale: CGFloat
    @Binding var swipeOffset: CGFloat
    var minScale: CGFloat
    @Binding var isBarVisible: Bool
    @ObservedObject var playlistModel: PlaylistViewModel
    let assetItemsCount: Int
    @Environment(\.dismiss) var dismiss // For dismissing the full-screen view
    
    func body(content: Content) -> some View {
        content.onTapGesture(count: 1) {
            if zoomScale == minScale {
                withAnimation {
                    if isBarVisible {
                        isBarVisible = false
                        playlistModel.hideToolbar()
                    } else {
                        playlistModel.showToolbar()
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
                       playlistModel.previousItem(count: assetItemsCount)
                       withAnimation {
                           swipeOffset = 100 // Move right
                       }
                   } else if value.translation.width < -50 {
                       playlistModel.nextItem(count: assetItemsCount)
                       withAnimation {
                           swipeOffset = -100 // Move left
                       }
                   }
                   swipeOffset = 0
               }
           }
        )
    }
}


// Extension to make it easier to apply the modifier
extension View {
    func pinchToZoom(
        swipeOffset: Binding<CGFloat>,
        imageSize: Binding<CGSize>,
        offset: Binding<CGSize>,
        minScale: CGFloat,
        maxScale: CGFloat,
        zoomScale: Binding<CGFloat>,
        playlistModel: PlaylistViewModel,
        assetItemsCount: Int
    ) -> some View {
        modifier(PinchToZoomModifier(
            swipeOffset: swipeOffset,
            imageSize: imageSize,
            offset: offset,
            minScale: minScale,
            maxScale: maxScale,
            zoomScale: zoomScale,
            playlistModel: playlistModel,
            assetItemsCount: assetItemsCount
        ))
    }
    
    func mac_iosCommand(
        zoomScale: Binding<CGFloat>,
        swipeOffset: Binding<CGFloat>,
        minScale: CGFloat,
        isBarVisible: Binding<Bool>,
        playlistModel: PlaylistViewModel,
        assetItemsCount: Int
    ) -> some View {
        modifier(MAC_IOSCommand(
            zoomScale: zoomScale,
            swipeOffset: swipeOffset,
            minScale: minScale,
            isBarVisible: isBarVisible,
            playlistModel: playlistModel,
            assetItemsCount: assetItemsCount
        ))
    }
}
