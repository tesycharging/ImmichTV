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
    var shared: Bool
    @EnvironmentObject private var immichService: ImmichService
    @EnvironmentObject private var entitlementManager: EntitlementManager
    @FocusState private var focusedButton: String? // Track which button is focused
    @Environment(\.dismiss) private var dismiss
    @State private var ascending = false
    @State private var error = false
    @State private var errorMessage: String = "no picturesX"
    @State private var isLoading = false
    @State private var onAppear = true
    #if targetEnvironment(macCatalyst)
    @State private var showSlide = false
    @State private var slideActive = false
    #else
    @Binding var slideActive: Bool
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
                    .onAppear {
                        error = false
                        if !slideActive {
                            isLoading = true
                            onAppear = false
                            Task {
                                do {
                                    try Task.checkCancellation() // Throws if cancelled
                                    try await immichService.fetchAssets(albumId: albumId)
                                    isLoading = false
                                } catch let apiError as APIError {
                                    self.error = true
                                    errorMessage = apiError.localizedDescription
                                    isLoading = false
                                } catch {
                                    self.error = true
                                    errorMessage = "Failed to fetch pictures: \(error.localizedDescription)"
                                    isLoading = false
                                }
                            }
                        }
                    }
                ScrollView(.vertical, showsIndicators: false) {
                    HStack {
                        VStack {
                            HStack {
                                Text("\(albumName)").font(.title)
                                if shared {
                                    #if targetEnvironment(macCatalyst)
                                    Image(systemName: "link")
                                    #else
                                    Image(systemName: "sharedwithyou")
                                    #endif
                                }
                            }
                            if !immichService.assetItems.isEmpty {
                                Text("\(immichService.assetItems.count) Assets").font(.footnote)
                            }
                        }.padding()
                        Button( action: {
                            ascending.toggle()
                            isLoading = true
                            immichService.sortedAndGroupedAssets(assetItems: immichService.assetItems, ascending: ascending)
                            immichService.objectWillChange.send()
                            isLoading = false
                        }) {
                            Image(systemName: ascending ? "arrow.up.square" : "arrow.down.app").frame(height: 32)
                        }.buttonStyle(ImmichTVButtonStyle(isFocused: focusedButton == "asc"))
                            .focused($focusedButton, equals: "asc")
                            .disabled(isLoading)
#if targetEnvironment(macCatalyst)
                        Button( action: {
                            showSlide = true
                            slideActive = true
                        }) {
                            Image(systemName: "play").frame(height: 32)
                        }.buttonStyle(ImmichTVButtonStyle(isFocused: focusedButton == "slideshow"))
                            .focused($focusedButton, equals: "slideshow")
                            .disabled(isLoading)
                            .fullScreenCover(isPresented: $showSlide, onDismiss: { slideActive = false }) {
                                SlideshowView(albumName: albumName).environmentObject(immichService).environmentObject(entitlementManager)
                            }
#else
                        NavigationLink(value: NavigationDestination.slide(albumName)) {
                            Image(systemName: "play").frame(height: 32)//.buttonStyle(PlainButtonStyle())
                        }.buttonStyle(ImmichTVButtonStyle(isFocused: focusedButton == "slideshow"))
                            .focused($focusedButton, equals: "slideshow")
                            .disabled(isLoading)
#endif
                    }.padding()
                    //Text(album.albumName).font(.title).padding()
                    VStack(alignment: .leading, spacing: 0) {
                        if isLoading {
                            ProgressView().progressViewStyle(CircularProgressViewStyle()).scaleEffect(1)
                        } else if error {
                            Text(errorMessage).font(.caption)
                        } else if immichService.assetItems.isEmpty && !onAppear {
                            Text("no picture").font(.caption)
                        } else {
                            AssetsView(albumName: albumName, shared: shared, ascending: $ascending).onAppear {
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
