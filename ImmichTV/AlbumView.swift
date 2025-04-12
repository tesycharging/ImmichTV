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
    @FocusState private var focusedButton: String? // Track which button is focused
    @Environment(\.dismiss) private var dismiss
    @State private var navigationPath = NavigationPath() // Manages navigation stack
      
    var body: some View {
        VStack(alignment: .leading, spacing: 100) {
            Spacer()
            ScrollView(.vertical, showsIndicators: false) {
                HStack {
                    Text("\(albumName)").font(.title).padding()
                    NavigationLink(value: NavigationDestination.slide(albumName)) {
                        Image(systemName: "play").frame(height: 32)//.buttonStyle(PlainButtonStyle())
                    }.buttonStyle(ImmichTVButtonStyle(isFocused: focusedButton == "slideshow"))
                        .focused($focusedButton, equals: "slideshow")
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
                        AssetsView(albumName: albumName).onAppear {
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
