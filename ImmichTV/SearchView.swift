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
    @State private var searchResults: [AssetItem] = []
    @State private var showSlideShow = false
    @FocusState private var focusedButton: String? // Track which button is focused
    private let gridItems = [GridItem(.adaptive(minimum: 400, maximum: 400), spacing: 80), GridItem(.adaptive(minimum: 400, maximum: 400), spacing: 80)]
    
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
            HStack(alignment: .top){
                VStack(spacing: 40) {
                    HStack {
                        TextField("Smart Search", text: $searchText, onCommit: {
                            Task {
                                do {
                                    searchResults = try await immichService.searchAssets(query: searchText)
                                } catch let error {
                                    print(error.localizedDescription)
                                }
                            }
                        })
                        .textFieldStyle(PlainTextFieldStyle())
                        .frame(height: 70)
                        .padding()
                        Button(action: {
                            showSlideShow = true
                        }) { // Action is empty since NavigationLink handles the tap
                            Text("Play Slideshow")
                                .font(.caption)
                                .padding()
                                .frame(width: 250, height: 70)
                                .foregroundColor(.black)
                                .cornerRadius(10)
                        }.disabled(searchResults.isEmpty).buttonStyle(DefaultButtonStyle())
                    }.navigationTitle("Search Library")
                    if !searchResults.isEmpty {
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(alignment: .leading, spacing: 40) {
                                VStack(alignment: .leading, spacing: 0) {
                                    LazyVGrid(columns: gridItems, spacing: 0) {
                                        ForEach(searchResults, id: \.self) { assetItem in
                                            NavigationLink(destination: SlideshowView(searchResults: searchResults, id: assetItem.id, start: false)) {
                                                AssetCard(assetItem: assetItem)
                                            }
                                        }
                                    }.padding(.horizontal, -40)
                                }.onAppear {
                                    self.focusedButton = searchResults.first?.id ?? ""
                                }
                            }.padding(.vertical, 40)
                        }.background(Color.black)
                         .animation(.easeInOut(duration: 0.2), value: focusedButton)
                    }
                    Spacer()
                }
            }
        }
        .fullScreenCover(isPresented: $showSlideShow) {
            SlideshowView(searchResults: searchResults)
        }
        .navigationViewStyle(.stack) // Ensures consistent navigation behavior
    }
}
