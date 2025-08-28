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
    @Binding var offsetStep: CGSize
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
    
    func calculateOffset(step: CGFloat, imageDim: CGSize, slideDim: CGSize) -> CGFloat {
        let maxStep: CGFloat = (maxScale - minScale) / 2
        let isPortrait = imageDim.height > imageDim.width
        if !isPortrait {
            return slideDim.width * step
        } else {
            let black = step > 0 ? (slideDim.width - imageDim.width / (imageDim.height / slideDim.height)) / 2 : (slideDim.width - imageDim.width / (imageDim.height / slideDim.height)) / -2
            let scaled = imageDim.width / (imageDim.height / slideDim.height) * zoomScale
            if (scaled / slideDim.width) <= 1 || step == 0 {
                return 0
            } else if (scaled / slideDim.width) <= (maxStep + 1) || step == maxStep {
                return black == 0 ? black + step * slideDim.width : black
            } else {
                return black + step * slideDim.width
            }
        }
    }
    
    func zoomOffset(direction: MoveCommandDirection) {
        let maxOffsetStep: CGFloat = (maxScale - minScale) / 2
        switch direction {
        case .left:
            offsetStep.width = offsetStep.width == maxOffsetStep ? maxOffsetStep : offsetStep.width + 1
            offset.width = calculateOffset(step: offsetStep.width, imageDim: imageSize, slideDim: slideSize)
        case .right:
            offsetStep.width = offsetStep.width == (-1 * maxOffsetStep) ? -maxOffsetStep : offsetStep.width - 1
            offset.width = calculateOffset(step: offsetStep.width, imageDim: imageSize, slideDim: slideSize)
        case .up:
            offsetStep.height = offsetStep.height == maxOffsetStep ? maxOffsetStep : offsetStep.height + 1
            offset.height = calculateOffset(step: offsetStep.height, imageDim: imageSize.swapped, slideDim: slideSize.swapped)
        case .down:
            offsetStep.height = offsetStep.height == (-1 * maxOffsetStep) ? -maxOffsetStep : offsetStep.height - 1
            offset.height = calculateOffset(step: offsetStep.height, imageDim: imageSize.swapped, slideDim: slideSize.swapped)
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
        offsetStep: Binding<CGSize>,
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
            offsetStep: offsetStep,
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

extension CGSize {
    var swapped: CGSize {
        CGSize(width: height, height: width)
    }
}
