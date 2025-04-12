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
       
    
    let tilewidth: CGFloat
    private let gridItems: [GridItem]
    @FocusState private var focusedButton: String? // Track which button is focused
    
    init(showAlbums: Bool = false, albumName: String? = nil, query: Query? = nil) {
        self._showAlbums = State(initialValue: showAlbums)
        self._albumName = State(initialValue: albumName)
        self._query = State(initialValue: query)
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
                AsyncImage(url: immichService.getImageUrl(id: id)) { phase in
                    switch phase {
                    case .empty:
                        ProgressView().progressViewStyle(CircularProgressViewStyle()).scaleEffect(1)
                    case .success(let image):
                        ZStack(alignment: .center) {
                            image.resizable().frame(width: tilewidth, height: tilewidth * 0.75).blur(radius: 10)
                            image.resizable().scaledToFit().frame(width: tilewidth - 4, height: (tilewidth * 0.75) - 3)
                        }
                    case .failure:
                        AsyncImage(url: immichService.getImageUrl(id: id)) { phase in
                            switch phase {
                            case .empty:
                                ProgressView().progressViewStyle(CircularProgressViewStyle()).scaleEffect(1)
                            case .success(let image):
                                ZStack(alignment: .center) {
                                    image.resizable().frame(width: tilewidth, height: tilewidth * 0.75).blur(radius: 10)
                                    image.resizable().scaledToFit().frame(width: tilewidth - 4, height: (tilewidth * 0.75) - 3)
                                }
                            case .failure:
                                Color.red.frame(width: tilewidth, height: tilewidth * 0.75).overlay(Text("Failed \(id)"))
                            @unknown default:
                                Color.gray.frame(width: tilewidth, height: tilewidth * 0.75)
                            }
                        }
                    @unknown default:
                        Color.gray.frame(width: tilewidth, height: tilewidth * 0.75)
                    }
                }
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
                                    NavigationLink(value: NavigationDestination.album(albumId: album.id, albumName: album.albumName)) {
                                        AssetCard(id: album.albumThumbnailAssetId).overlay(alignment: .bottom){
                                            Text(album.albumName).font(.subheadline).background(.black.opacity(0.5)).foregroundColor(.white.opacity(0.8))
                                        }
                                    }.buttonStyle(ImmichTVTaleStyle(isFocused: focusedButton == album.id))
                                        .focused($focusedButton, equals: album.id)
                                    Spacer()
                                }
                            }
                        }
                    }
                }
            } else if entitlementManager.groupByDay {
                ForEach(immichService.assetItemsGrouped.keys.sorted().reversed(), id: \.self) { key in
                    VStack(alignment: .leading, spacing: 0) {
                        Text("\(dateToString(date: key.adding(days: 1)))").font(.subheadline).padding()
                        LazyVGrid(columns: gridItems, spacing: 0) {
                            ForEach(immichService.assetItemsGrouped[key] ?? [], id: \.id) { item in
                                VStack {
                                    NavigationLink(value: NavigationDestination.slide(albumName, immichService.assetItems.firstIndex(where: { $0.id == item.id }), query)) {
                                        AssetCard(id: item.id)
                                    }.buttonStyle(ImmichTVTaleStyle(isFocused: focusedButton == item.id))
                                        .focused($focusedButton, equals: item.id)
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
                            NavigationLink(value: NavigationDestination.slide(albumName, immichService.assetItems.firstIndex(where: { $0.id == immichService.assetItems[index].id }), query)) {
                                AssetCard(id: immichService.assetItems[index].id)
                            }.buttonStyle(ImmichTVTaleStyle(isFocused: focusedButton == "\(index)"))
                            .focused($focusedButton, equals: "\(index)")
                            Spacer()
                        }
                    }
                }
            }
        }.animation(.easeInOut(duration: 0.2), value: focusedButton)
    }
}

extension Date {
    func adding(days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: self)!
    }
}
