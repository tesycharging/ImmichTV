//
//  ContentView.swift
//  ImmichTV
//
//  Created by David Lüthi on 17.03.2025.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var immichService = ImmichService()
    @FocusState private var focusedButton: String? // Track which button is focused
    private let gridItems = [/*GridItem(.fixed(400))*/GridItem(.adaptive(minimum: 400, maximum: 400), spacing: 80)]
    @State var user = ""
    @State var alblumsExists = true
    @State var errorMessage = ""
    
    
    func AlbumOfYear() -> some View {
        ForEach(immichService.albumsByYear.keys.sorted().reversed(), id: \.self) { year in
            VStack(alignment: .leading, spacing: 0) {
                Text(year).font(.title).foregroundColor(.white).padding(.horizontal, 20)
                LazyVGrid(columns: gridItems, spacing: 0) {
                    ForEach(immichService.albumsByYear[year] ?? [], id: \.self) { album in
                        NavigationLink(destination: SlideshowView(album: album)) {
                            AlbumCard(album: album)
                        }//.buttonStyle(CardButtonStyle())
                    }
                }.padding(.horizontal, -40)
            }
        }
    }
    
    func AlbumCard(album: Album) -> some View {
        ZStack(alignment: .bottom) {
            VStack {
                AsyncImage(url: immichService.getImageUrl(id: album.albumThumbnailAssetId), content: { image in
                    ZStack(alignment: .center) {
                        image.resizable().frame(width: 400, height: 300).blur(radius: 10)
                        image.resizable().scaledToFit().frame(width: 396, height: 297)
                    }
                },
                           placeholder: {
                    ProgressView()
                })
            }
            Text(album.albumName).font(.caption).foregroundColor(.black.opacity(0.8))
        }
        //.frame(width: 300, height: 200)
        .cornerRadius(15)
        .focusable()
        .focused($focusedButton, equals: album.id)
        .buttonStyle(PlainButtonStyle())
    }

    var body: some View {
        NavigationView {
           ScrollView(.vertical, showsIndicators: false) {
               VStack(alignment: .leading, spacing: 40) {
                   if immichService.albumsByYear.isEmpty {
                       if alblumsExists {
                           ProgressView().progressViewStyle(CircularProgressViewStyle()).scaleEffect(1)
                       } else {
                           Text(errorMessage).font(.caption).foregroundColor(.white)
                       }
                   } else {
                       self.AlbumOfYear()
                   }
               }.padding(.vertical, 40)
           }.navigationTitle("Immich Albums \(user == "" ? "" : "of \(user)")").background(Color.black)
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    NavigationLink(destination: SearchView()) {
                        Image(systemName: "magnifyingglass")
                            .padding()
                            .frame(width: 150, height: 60)
                            .background(focusedButton == "search" ? Color.blue : Color.gray.opacity(0.8))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .focusable()
                    .focused($focusedButton, equals: "search")
                }
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink(destination: SettingView(immichService: immichService)) {
                        Image(systemName: "gear")
                            .padding()
                            .frame(width: 150, height: 60)
                            .background(focusedButton == "settings" ? Color.green : Color.gray.opacity(0.8))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .focusable()
                    .focused($focusedButton, equals: "settings")
                }
            }
            .animation(.easeInOut(duration: 0.2), value: focusedButton)
           .task {
               do {
                   user = try await immichService.getMyUser()
                   alblumsExists = try await immichService.fetchAlbums()
               } catch {
                   errorMessage = (error as NSError).domain
                   alblumsExists = false
                   print("Error fetching albums: \(error)")
               }
           }
        }.background(.black)
    }
}

#Preview {
    ContentView()
}
