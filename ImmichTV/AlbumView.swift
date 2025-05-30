//
//  AlbumView.swift
//  ImmichTV
//
//  Created by David Lüthi on 04.04.2025.
//

import SwiftUI

struct AlbumView: View {
    var albumId: String
    var albumName: String
    @Binding var isLoading: Bool
    @EnvironmentObject private var immichService: ImmichService
    @EnvironmentObject private var entitlementManager: EntitlementManager
    @FocusState private var focusedButton: String? // Track which button is focused
    @Environment(\.dismiss) private var dismiss
    @State private var ascending = false
    #if targetEnvironment(macCatalyst)
    @State private var showSlide = false
    @State private var slideActive = false
    #endif
      
    var body: some View {
        ZStack(alignment: .topLeading) {
#if targetEnvironment(macCatalyst)
            Button(action: {
                dismiss()
            }) {
                Image(systemName: "x.square")//.padding(.horizontal, 30)
            }.buttonStyle(ImmichTVSlideShowButtonStyle(isFocused: focusedButton == "close"))
                .focused($focusedButton, equals: "close")
                .zIndex(1)
                .padding(.leading, 20)
            #endif
            VStack(alignment: .leading, spacing: 100) {
                Spacer()
                ScrollView(.vertical, showsIndicators: false) {
                    HStack {
                        VStack {
                            Text("\(albumName)").font(.title)
                            if !immichService.assetItems.isEmpty {
                                Text("\(immichService.assetItems.count) Assets").font(.footnote)
                            }
                        }.padding()
                        Button( action: {
                            ascending.toggle()
                            isLoading = true
                            let assetItems = immichService.assetItems
                            immichService.assetItems.removeAll()
                            immichService.assetItems = assetItems.reversed()
                            if entitlementManager.groupByDay {
                                immichService.assetItemsGrouped.removeAll()
                                immichService.assetItemsGrouped = immichService.groupAssets(assetItems: immichService.assetItems, ascending: ascending)
                            }
                            immichService.objectWillChange.send()
                            isLoading = false
                        }) {
                            Image(systemName: ascending ? "arrow.up.square" : "arrow.down.app").frame(height: 32)
                        }.buttonStyle(ImmichTVButtonStyle(isFocused: focusedButton == "asc"))
                            .focused($focusedButton, equals: "asc")
#if targetEnvironment(macCatalyst)
                        Button( action: {
                            showSlide = true
                            slideActive = true
                        }) {
                            Image(systemName: "play").frame(height: 32)
                        }.buttonStyle(ImmichTVButtonStyle(isFocused: focusedButton == "slideshow"))
                            .focused($focusedButton, equals: "slideshow")
                            .fullScreenCover(isPresented: $showSlide, onDismiss: { slideActive = false }) {
                                SlideshowView(albumName: albumName).environmentObject(immichService).environmentObject(entitlementManager)
                            }
#else
                        NavigationLink(value: NavigationDestination.slide(albumName)) {
                            Image(systemName: "play").frame(height: 32)//.buttonStyle(PlainButtonStyle())
                        }.buttonStyle(ImmichTVButtonStyle(isFocused: focusedButton == "slideshow"))
                            .focused($focusedButton, equals: "slideshow")
#endif
                    }.padding()
                    //Text(album.albumName).font(.title).padding()
                    VStack(alignment: .leading, spacing: 0) {
                        if immichService.assetItems.isEmpty {
                            if isLoading {
                                Spacer()
                                ProgressView().progressViewStyle(CircularProgressViewStyle()).scaleEffect(1)
                                Spacer()
                            } else {
                                Spacer()
                                Text("No pictures found").font(.title)
                                Spacer()
                            }
                        } else {
                            AssetsView(albumName: albumName, ascending: $ascending).onAppear {
#if os(tvOS)
                                focusedButton = "slideshow"
#endif
                            }
                        }
                        Spacer()
                    }
                }
            }.ignoresSafeArea()
        }
    }
}
