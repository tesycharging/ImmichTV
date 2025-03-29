//
//  SearchView.swift
//  ImmichTV
//
//  Created by David Lüthi on 17.03.2025.
//

import SwiftUI

struct SearchView: View {
    @StateObject private var immichService = ImmichService()
    @State private var searchText = ""
    @State private var searchFavorite: Bool?
    @State private var searchResults: [AssetItem] = []
    @State private var showItemFullScreen = false
    @State private var showSlideShow = false
    @State private var searchIndex = 0
    @State private var matches: Int?
    @State private var nextPage: Int?
    @State private var previousPage: Int?
    @FocusState private var focusedButton: String? // Track which button is focused
    private let gridItems = [GridItem(.adaptive(minimum: 400, maximum: 400), spacing: 30)/*, GridItem(.adaptive(minimum: 400, maximum: 400), spacing: 30)*/]
    @Environment(\.dismiss) private var dismiss
    
    func AssetCard(assetItem: AssetItem) -> some View {
        ZStack(alignment: .bottom) {
            VStack {
                AsyncImage(url: immichService.getImageUrl(id: assetItem.id), content: { image in
                    ZStack(alignment: .center) {
                        image.resizable().frame(width: 400, height: 300).blur(radius: 10)
                        image.resizable().scaledToFit().frame(width: 396, height: 297)
                    }
                },
                           placeholder: {
                    ProgressView()
                })
            }
        }
        //.frame(width: 300, height: 200)
        .cornerRadius(15)
        .focusable()
        .focused($focusedButton, equals: assetItem.id)
        .buttonStyle(PlainButtonStyle())
    }

    var body: some View {
        NavigationView {
            ScrollView(.vertical, showsIndicators: false) {
                HStack(alignment: .top){
                    VStack(spacing: 40) {
                        HStack {
                            TextField("Smart Search", text: $searchText, onCommit: {
                                Task {
                                    searchFavorite = nil
                                    previousPage = nil
                                    nextPage = 1
                                    do {
                                        (searchResults, nextPage) = try await immichService.searchSmartAssets(query: searchText, page: nextPage)
                                        matches = searchResults.count
                                    } catch let error {
                                        print(error.localizedDescription)
                                    }
                                }
                            }).immichTVTestFieldStyle(isFocused: focusedButton == "smartsearch")
                                .focused($focusedButton, equals: "smartsearch")
                                .onAppear {
                                    focusedButton = "allphotos"
                                }
                            if !immichService.demo {
                                Button(action: {
                                    Task {
                                        self.searchText = ""
                                        nextPage = 1
                                        previousPage = nil
                                        searchFavorite = true
                                        do {
                                            (searchResults, nextPage) = try await immichService.searchAssets(isFavorite: searchFavorite, page: nextPage)
                                            matches = searchResults.count
                                        } catch let error {
                                            print(error.localizedDescription)
                                        }
                                    }
                                }) {
                                    Image(systemName: "heart.fill")
                                        .buttonStyle(PlainButtonStyle())
                                }.buttonStyle(ImmichTVButtonStyle(isFocused: focusedButton == "favorite"))
                                    .focused($focusedButton, equals: "favorite")
                                Button(action: {
                                    Task {
                                        self.searchText = ""
                                        nextPage = 1
                                        previousPage = nil
                                        searchFavorite = nil
                                        do {
                                            (searchResults, nextPage) = try await immichService.searchAssets(page: nextPage)
                                            matches = searchResults.count
                                        } catch let error {
                                            print(error.localizedDescription)
                                        }
                                    }
                                }) {
                                    Image(systemName: "swatchpalette")
                                        .buttonStyle(PlainButtonStyle())
                                }.buttonStyle(ImmichTVButtonStyle(isFocused: focusedButton == "allphotos"))
                                    .focused($focusedButton, equals: "allphotos")
                            }
                            Button(action: {
                                showSlideShow = true
                            }) { // Action is empty since NavigationLink handles the tap
                                Text("Play Slideshow")
                                    .font(.caption)
                            }.disabled(searchResults.isEmpty)
                                .buttonStyle(ImmichTVButtonStyle(isFocused: focusedButton == "slideshow"))
                                .focused($focusedButton, equals: "slideshow")
                        }.navigationTitle("Search Library")
                        if self.matches != nil {
                            HStack {
                                Text("\(matches ?? 0) matches found").font(.caption)
                                Spacer()
                                if (previousPage != nil || nextPage != nil) {
                                    Button(action: {
                                        Task {
                                            do {
                                                if self.searchText == "" {
                                                    (searchResults, nextPage) = try await immichService.searchAssets(isFavorite: searchFavorite, page: previousPage)
                                                } else {
                                                    (searchResults, nextPage) = try await immichService.searchSmartAssets(query: self.searchText, page: previousPage)
                                                }
                                                matches = searchResults.count
                                                if nextPage == nil {} else if nextPage! == 2 {
                                                    previousPage = nil
                                                } else {
                                                    previousPage = nextPage! - 2
                                                }
                                            } catch let error {
                                                print(error.localizedDescription)
                                            }
                                        }
                                    }) {
                                        Image(systemName: "backward.frame")
                                    }.disabled(previousPage == nil).buttonStyle(ImmichTVButtonStyle(isFocused: focusedButton == "back"))
                                        .focused($focusedButton, equals: "back")
                                    Text("page \((nextPage ?? 2) - 1)").font(.caption)
                                    Button(action: {
                                        Task {
                                            do {
                                                if self.searchText == "" {
                                                    (searchResults, nextPage) = try await immichService.searchAssets(isFavorite: searchFavorite, page: nextPage)
                                                } else {
                                                    (searchResults, nextPage) = try await immichService.searchSmartAssets(query: self.searchText, page: nextPage)
                                                }
                                                matches = searchResults.count
                                                if nextPage == nil {} else if nextPage! == 2 {
                                                    previousPage = nil
                                                } else {
                                                    previousPage = nextPage! - 2
                                                }
                                            } catch let error {
                                                print(error.localizedDescription)
                                            }
                                        }
                                    }) {
                                        Image(systemName: "forward.frame")
                                    }.disabled(nextPage == nil).buttonStyle(ImmichTVButtonStyle(isFocused: focusedButton == "forward"))
                                        .focused($focusedButton, equals: "forward")
                                }
                            }
                        }
                        if !searchResults.isEmpty {
                            VStack(alignment: .leading, spacing: 0) {
                                LazyVGrid(columns: gridItems, spacing: 0) {
                                    ForEach(searchResults.indices, id: \.self) { index in
                                        Button(action: {
                                            showItemFullScreen = true
                                            searchIndex = index
                                        }) {
                                            AssetCard(assetItem: searchResults[index])
                                        }
                                        .buttonStyle(ImmichTVTaleStyle(isFocused: focusedButton == "\(index)"))
                                            .focused($focusedButton, equals: "\(index)")
                                        .fullScreenCover(isPresented: $showItemFullScreen) {
                                            SlideshowView(searchResults: searchResults, id: searchResults[searchIndex].id, start: false)
                                        }
                                    }
                                }.padding()
                            }.onAppear {
                                self.focusedButton = searchResults.first?.id ?? ""
                            }.padding().animation(.easeInOut(duration: 0.2), value: focusedButton)
                        }
                        Spacer()
                    }
                }
            }
        }
        .navigationViewStyle(.stack) // Ensures consistent navigation behavior
        .edgesIgnoringSafeArea(.all)
        .fullScreenCover(isPresented: $showSlideShow) {
            SlideshowView(searchResults: searchResults)
        }
    }
}
