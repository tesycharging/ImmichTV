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
    @ObservedObject var playlistModel: PlaylistViewModel
    
    func body(content: Content) -> some View {
        content.onTapGesture(count: 1) {
            withAnimation(.easeInOut) {
                zoomScale = minScale //zoomout
                playlistModel.showToolbar()
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
    @Binding var lastFocusedButton: ButtonFocus?
    @Binding var disableddButtons: [ButtonFocus]
    var isVideoAndPlayable: Bool
    
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
        playlistModel.showToolbar()
        focusedButton = .zoom
    }
    
    func arrowCommands(direction: MoveCommandDirection) {
        switch direction {
        case .left:
            if !playlistModel.showControls {
                playlistModel.previousItem(count: assetItemsCount)
            } else {
                if lastFocusedButton != .player {
                    var p = lastFocusedButton?.previous
                    while disableddButtons.contains(p ?? .close) {
                        p = p?.previous
                        if p == .originalVideo {
                            p = p?.previous
                        }
                    }
                    focusedButton = p
                } else {
                    focusedButton = .previous
                }
                playlistModel.showToolbar()
            }
        case .right:
            if !playlistModel.showControls {
                playlistModel.nextItem(count: assetItemsCount)
            } else {
                if lastFocusedButton != .player {
                    var n = lastFocusedButton?.next
                    while disableddButtons.contains(n ?? .setting)  {
                        n = n?.next
                        if n == .originalVideo {
                            n = n?.next
                        }
                    }
                    focusedButton = n
                } else {
                    focusedButton = .next
                }
                playlistModel.showToolbar()
            }
        case .up:
            if playlistModel.showControls {
                if self.isVideoAndPlayable {
                    if lastFocusedButton != .player {
                        playlistModel.hideToolbar()
                    } else {
                        focusedButton = .next
                        playlistModel.showToolbar()
                    }
                } else {
                    playlistModel.hideToolbar()
                }
            } else {
                playlistModel.showToolbar()
            }
        case .down:
            if playlistModel.showControls {
                if self.isVideoAndPlayable {
                    if focusedButton == nil || lastFocusedButton == .player {
                        playlistModel.hideToolbar()
                    } else {
                        focusedButton = .player
                        playlistModel.showToolbar()
                    }
                } else {
                    playlistModel.hideToolbar()
                }
            } else {
                playlistModel.showToolbar()
            }
        default:
            break
        }
    }
    
    func body(content: Content) -> some View {
        content.onPlayPauseCommand {
            if zoomScale == minScale {
                playlistModel.running.toggle()
                if !isVideoAndPlayable {
                    if playlistModel.running {
                        playlistModel.showAlbumName = true
                        zoomScale = minScale
                        playlistModel.startImageTimer(duration: timeinterval, count: assetItemsCount)
                    } else {
                        playlistModel.pausePlaylist()
                    }
                }
            } else {
                zoomScale = minScale
                playlistModel.showToolbar()
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
        zoomScale: Binding<CGFloat>,
        playlistModel: PlaylistViewModel
    ) -> some View {
        modifier(PinchToZoomModifier(
            minScale: minScale,
            maxScale: maxScale,
            zoomScale: zoomScale,
            playlistModel: playlistModel
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
        focusedButton: Binding<ButtonFocus?>,
        lastFocusedButton: Binding<ButtonFocus?>,
        disableddButtons: Binding<[ButtonFocus]>,
        isVideoAndPlayable: Bool
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
            focusedButton: focusedButton,
            lastFocusedButton: lastFocusedButton,
            disableddButtons: disableddButtons,
            isVideoAndPlayable: isVideoAndPlayable)
        )
    }
}
