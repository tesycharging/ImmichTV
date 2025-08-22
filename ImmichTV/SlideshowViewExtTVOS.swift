//
//  SlideshowViewExtTVOS.swift
//  ImmichTV
//
//  Created by David Lüthi on 20.08.2025.
//

import SwiftUI
import Foundation
import Combine

struct PinchToZoomModifier: ViewModifier {
    var minScale: CGFloat
    var maxScale: CGFloat
    @Binding var zoomScale: CGFloat
    
    func body(content: Content) -> some View {
        content.onTapGesture(count: 1) {
            withAnimation(.easeInOut) {
                // Toggle between min and max scale
                zoomScale = zoomScale == minScale ? maxScale : minScale
            }
        }
    }
}

struct TVOSCommand: ViewModifier {
    var timeinterval: TimeInterval
    @Binding var zoomScale: CGFloat
    var minScale: CGFloat
    var maxScale: CGFloat
    @Binding var slideSize: CGSize
    @Binding var offsetStepX: CGFloat
    @Binding var offsetStepY: CGFloat
    @Binding var imageSize: CGSize
    @Binding var offset: CGSize
    @ObservedObject var playlistModel: PlaylistViewModel
    let assetItemsCount: Int
    let isFavoritable: Bool
    let thumbnailShown: Bool
    @Binding var focusedButton: ButtonFocus?
    
    func zoomOffset(direction: MoveCommandDirection) {
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
        focusedButton = .zoomout
    }
    
    func arrowCommands(direction: MoveCommandDirection) {
        switch direction {
        case .left:
            if !playlistModel.isBarVisible {
                playlistModel.previousItem(count: assetItemsCount)
            } else {
                if focusedButton == nil {
                    focusedButton = .previous
                }
                playlistModel.showToolbar()
            }
        case .right:
            if !playlistModel.isBarVisible {
                playlistModel.nextItem(count: assetItemsCount)
            } else {
                if focusedButton == nil {
                    focusedButton = .next
                }
                playlistModel.showToolbar()
            }
        case .up:
            if playlistModel.isBarVisible {
                if focusedButton == nil {
                    focusedButton = .playpause
                } else {
                    if isFavoritable {
                        focusedButton = .favorite
                    } else if thumbnailShown {
                        focusedButton = .original
                    } else {
                        focusedButton = .zoom
                    }
                }
            } else {
                focusedButton = .playpause
            }
            playlistModel.showToolbar()
        case .down:
            withAnimation(.easeInOut(duration: 0.3)) {
                if playlistModel.isBarVisible {
                    if ((focusedButton == .previous || focusedButton == .next || focusedButton == .playpause)) {
                        playlistModel.isBarVisible = false
                        playlistModel.hideToolbar()
                    } else if focusedButton == .favorite {
                        if thumbnailShown {
                            focusedButton = .original
                        } else {
                            focusedButton = .playpause
                        }
                        playlistModel.showToolbar()
                    } else {
                        focusedButton = .playpause
                        playlistModel.showToolbar()
                    }
                } else {
                    playlistModel.isBarVisible = true
                    focusedButton = .playpause
                    playlistModel.showToolbar()
                }
            }
        default:
            break
        }
    }
    
    func body(content: Content) -> some View {
        content.onPlayPauseCommand {
            playlistModel.running.toggle()
            if playlistModel.running {
                playlistModel.showAlbumName = true
                zoomScale = minScale
                playlistModel.play(duration: timeinterval, count: assetItemsCount)
            } else {
                playlistModel.pause()
            }
        }
        .onMoveCommand { direction in // Handle arrow key/remote input
            if zoomScale > minScale {
                zoomOffset(direction: direction)
            } else {
                arrowCommands(direction: direction)
            }
        }
    }
}
        

// Extension to make it easier to apply the modifier
extension View {
    func pinchToZoom(
        minScale: CGFloat,
        maxScale: CGFloat,
        zoomScale: Binding<CGFloat>
    ) -> some View {
        modifier(PinchToZoomModifier(
            minScale: minScale,
            maxScale: maxScale,
            zoomScale: zoomScale
        ))
    }
    
    func tvOSCommand(
        timeinterval: TimeInterval,
        zoomScale: Binding<CGFloat>,
        minScale: CGFloat,
        maxScale: CGFloat,
        slideSize: Binding<CGSize>,
        offsetStepX: Binding<CGFloat>,
        offsetStepY: Binding<CGFloat>,
        imageSize: Binding<CGSize>,
        offset: Binding<CGSize>,
        playlistModel: PlaylistViewModel,
        assetItemsCount: Int,
        isFavoritable: Bool,
        thumbnailShown: Bool,
        focusedButton : Binding<ButtonFocus?>
    ) -> some View {
        modifier(TVOSCommand(
            timeinterval: timeinterval,
            zoomScale: zoomScale,
            minScale: minScale,
            maxScale: maxScale,
            slideSize: slideSize,
            offsetStepX: offsetStepX,
            offsetStepY: offsetStepY,
            imageSize: imageSize,
            offset: offset,
            playlistModel: playlistModel,
            assetItemsCount: assetItemsCount,
            isFavoritable: isFavoritable,
            thumbnailShown: thumbnailShown,
            focusedButton: focusedButton)
        )
    }
}
