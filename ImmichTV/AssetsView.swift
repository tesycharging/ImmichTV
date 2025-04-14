//
//  AssetsView.swift
//  ImmichTV
//
//  Created by David Lüthi on 05.04.2025.
//

import SwiftUI
import Combine

struct AssetsView: View {
    @EnvironmentObject private var immichService: ImmichService
    @EnvironmentObject private var entitlementManager: EntitlementManager
    @State private var showAlbums: Bool
    @State private var albumName: String?
    @State private var query: Query?
    @Binding var ascending: Bool
       
    
    let tilewidth: CGFloat
    private let gridItems: [GridItem]
    @FocusState private var focusedButton: String? // Track which button is focused
    
    #if targetEnvironment(macCatalyst)
    @State private var showAlbum = false
    @State private var showAlbumId = ""
    @State private var showAlbumName = ""
    @State private var itemId = ""
    @State private var showSlide = false
    @State private var isLoading = true
    @State private var slideActive = false
    #endif
    
    init(showAlbums: Bool = false, albumName: String? = nil, query: Query? = nil, ascending: Binding<Bool>) {
        self._showAlbums = State(initialValue: showAlbums)
        self._albumName = State(initialValue: albumName)
        self._query = State(initialValue: query)
        self._ascending = ascending//State(initialValue: ascending)
        #if os(tvOS)
        tilewidth = 300
        #else
        tilewidth = 120
        #endif
        gridItems = [GridItem(.adaptive(minimum: tilewidth, maximum: tilewidth), spacing: tilewidth / 12)]
    }
    
    private func dateToYear(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy" // Only the year
        return formatter.string(from: date)
    }
    
    private func dateToString(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long    // e.g., "March 15, 2025"
        formatter.timeStyle = .none
        formatter.timeZone = TimeZone(identifier: "UTC") // Match the +00:00 offset
        return formatter.string(from: date)
    }
    
    func AssetCard(id: String) -> some View {
        ZStack(alignment: .bottom) {
            VStack {
                RetryableAsyncImage(url: immichService.getImageUrl(id: id), tilewidth: tilewidth)
            }
        }
        .cornerRadius(5)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if showAlbums {
                ForEach(immichService.albumsGrouped.keys.sorted().reversed(), id: \.self) { key in
                    VStack(alignment: .leading, spacing: 0) {
                        Text("\(dateToYear(date: key.adding(days: 1)))").font(.subheadline).padding()
                        LazyVGrid(columns: gridItems, spacing: 0) {
                            ForEach(immichService.albumsGrouped[key] ?? [], id: \.id) { album in
                                VStack {
                                    #if targetEnvironment(macCatalyst)
                                    Button(action: {
                                        showAlbum = true
                                        showAlbumId = album.albumThumbnailAssetId
                                        showAlbumName = album.albumName
                                        if !slideActive {
                                            immichService.assetItemsGrouped.removeAll()
                                            immichService.assetItems.removeAll()
                                            isLoading = true
                                            Task {
                                                do {
                                                    try Task.checkCancellation() // Throws if cancelled
                                                    try await immichService.fetchAssets(albumId: album.albumThumbnailAssetId)
                                                    isLoading = false
                                                } catch {
                                                    print("Failed to fetch pictures: \(error)")
                                                    isLoading = false
                                                }
                                            }
                                        }
                                    }){
                                        AssetCard(id: album.albumThumbnailAssetId).overlay(alignment: .bottom){
                                            Text(album.albumName).font(.subheadline).background(.black.opacity(0.5)).foregroundColor(.white.opacity(0.8))
                                        }
                                    }.buttonStyle(ImmichTVTaleStyle(isFocused: focusedButton == album.id))
                                        .focused($focusedButton, equals: album.id)
                                    #else
                                    NavigationLink(value: NavigationDestination.album(albumId: album.id, albumName: album.albumName)) {
                                        AssetCard(id: album.albumThumbnailAssetId).overlay(alignment: .bottom){
                                            Text(album.albumName).font(.subheadline).background(.black.opacity(0.5)).foregroundColor(.white.opacity(0.8))
                                        }
                                    }.buttonStyle(ImmichTVTaleStyle(isFocused: focusedButton == album.id))
                                        .focused($focusedButton, equals: album.id)
                                    #endif
                                    Spacer()
                                }
                            }
                        }
                    }
                }
            } else if entitlementManager.groupByDay {
                ForEach(immichService.sortedGroupAssets(ascending: ascending), id: \.self) { key in
                //ForEach(immichService.assetItemsGrouped.keys.sorted().reversed(), id: \.self) { key in
                    VStack(alignment: .leading, spacing: 0) {
                        Text("\(dateToString(date: key.adding(days: 1)))").font(.subheadline).padding()
                        LazyVGrid(columns: gridItems, spacing: 0) {
                            ForEach(immichService.assetItemsGrouped[key] ?? [], id: \.id) { item in
                                VStack {
                                    #if targetEnvironment(macCatalyst)
                                    Button(action: {
                                        showSlide = true
                                        itemId = item.id
                                        slideActive = true
                                    }) {
                                        AssetCard(id: item.id)
                                    }.buttonStyle(ImmichTVTaleStyle(isFocused: focusedButton == item.id))
                                        .focused($focusedButton, equals: item.id)
                                    #else
                                    NavigationLink(value: NavigationDestination.slide(albumName, immichService.assetItems.firstIndex(where: { $0.id == item.id }), query)) {
                                        AssetCard(id: item.id)
                                    }.buttonStyle(ImmichTVTaleStyle(isFocused: focusedButton == item.id))
                                        .focused($focusedButton, equals: item.id)
                                    #endif
                                    Spacer()
                                }
                            }
                        }
                    }
                }
            } else {
                LazyVGrid(columns: gridItems, spacing: 0) {
                    ForEach(immichService.assetItems.indices, id: \.self) { index in
                        VStack {
                            #if targetEnvironment(macCatalyst)
                            Button(action: {
                                showSlide = true
                                itemId = immichService.assetItems[index].id
                                slideActive = true
                            }) {
                                AssetCard(id: immichService.assetItems[index].id)
                            }.buttonStyle(ImmichTVTaleStyle(isFocused: focusedButton == "\(index)"))
                                .focused($focusedButton, equals: "\(index)")
                            #else
                            NavigationLink(value: NavigationDestination.slide(albumName, immichService.assetItems.firstIndex(where: { $0.id == immichService.assetItems[index].id }), query)) {
                                AssetCard(id: immichService.assetItems[index].id)
                            }.buttonStyle(ImmichTVTaleStyle(isFocused: focusedButton == "\(index)"))
                            .focused($focusedButton, equals: "\(index)")
                            #endif
                            Spacer()
                        }
                    }
                }
            }
        }.animation(.easeInOut(duration: 0.2), value: focusedButton)
#if targetEnvironment(macCatalyst)
            .fullScreenCover(isPresented: $showAlbum) {
                AlbumView(albumId: showAlbumId , albumName: showAlbumName, isLoading: $isLoading).environmentObject(immichService).environmentObject(entitlementManager)
            }
            .fullScreenCover(isPresented: $showSlide, onDismiss: { slideActive = false }) {
                SlideshowView(albumName: albumName, index: immichService.assetItems.firstIndex(where: { $0.id == itemId }), query: query).environmentObject(immichService).environmentObject(entitlementManager)
            }
        #endif
    }
}

extension Date {
    func adding(days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: self)!
    }
}
