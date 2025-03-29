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
    private let gridItems = [/*GridItem(.fixed(400))*/GridItem(.adaptive(minimum: 400, maximum: 400), spacing: 30)]
    @State var user = ""
    @State var alblumsExists = true
    @State var errorMessage = ""
    @State private var selectedAlbum: Album?
    @FocusState private var isFocused: Bool
    
    
    func AlbumOfYear() -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            ForEach(immichService.albumsByYear.keys.sorted().reversed(), id: \.self) { year in
                VStack(alignment: .leading, spacing: 0) {
                    Text(year).font(.title).padding(.horizontal, 20)
                    LazyVGrid(columns: gridItems, spacing: 0) {
                        ForEach(immichService.albumsByYear[year] ?? [], id: \.id) { album in
                            Button(action: {
                                selectedAlbum = album
                            }) {
                                AlbumCard(album: album)
                            }.buttonStyle(ImmichTVTaleStyle(isFocused: focusedButton == album.id))
                                .focused($focusedButton, equals: album.id)
                        }
                    }.padding()
                }
            }
        }.navigationTitle("Immich Albums \(user == "" ? "" : "of \(user)")")
            .fullScreenCover(isPresented: Binding(
                get: { selectedAlbum != nil },
                set: {if !$0 { selectedAlbum = nil }}
            )) {
                if let album = selectedAlbum {
                    SlideshowView(album: album)
                } else {
                    #if os(tvOS)
                    Text("Error: No album selected")
                    #else
                    ErrorView()
                    #endif
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
            Text(album.albumName).font(.headline).background(.black.opacity(0.5)).foregroundColor(.white.opacity(0.8))
        }
        .cornerRadius(15)
    }

    var body: some View {
        NavigationView {
            Group {
                if immichService.albumsByYear.isEmpty {
                    if alblumsExists {
                        ProgressView().progressViewStyle(CircularProgressViewStyle()).scaleEffect(1)
                    } else {
                        Text(errorMessage).font(.caption)
                    }
                } else {
                    self.AlbumOfYear()
                }
            }.onAppear {
                Task {
                    immichService.loadSettings()
                    do {
                        user = try await immichService.getMyUser()
                        alblumsExists = try await immichService.fetchAlbums()
                    } catch {
                        errorMessage = (error as NSError).domain
                        alblumsExists = false
                        print("Error fetching albums: \(error)")
                    }
                }
            }.toolbar {
                ToolbarItem(placement: .navigation) {
                    NavigationLink(destination: SearchView().edgesIgnoringSafeArea(.all)) {
                        Image(systemName: "magnifyingglass")//.frame(width: 150, height: 60)
                    }.buttonStyle(ImmichTVButtonStyle(isFocused: focusedButton == "search"))
                    .focused($focusedButton, equals: "search")
                }
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink(destination: SettingView(immichService: immichService, baseURL: UserDefaults.standard.string(forKey: "baseURL") ?? "", apikey: UserDefaults.standard.string(forKey: "apikey") ?? "")) {
                        Image(systemName: "gear")//.frame(width: 150, height: 60)
                    }.buttonStyle(ImmichTVButtonStyle(isFocused: focusedButton == "settings"))
                        .focused($focusedButton, equals: "settings")
                }
            }
            .animation(.easeInOut(duration: 0.2), value: focusedButton)
        }.navigationViewStyle(.stack) // Ensures consistent navigation behavior
            .accentColor(.primary) // Affects all interactive elements
    }
}

struct ErrorView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        HStack {
            Text("Error: No album selected").onTapGesture(count: 1) {
                dismiss()
            }
        }
    }
}

struct ImmichTVButtonStyle: ButtonStyle {
    let isFocused: Bool
    
    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.gray.opacity(0.2)) // Light gray background
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isFocused || configuration.isPressed ? Color.purple : Color.gray, lineWidth: 2) // Dynamic border
            )
            .foregroundStyle(isFocused || configuration.isPressed ? Color.purple : .primary) // Text color adapts to light/dark mode
            .textFieldStyle(.plain) // Removes default styling (optional)
            .focusable()
            .scaleEffect(configuration.isPressed ? 1.1 : 1.0)
    }
}

struct ImmichTVTaleStyle: ButtonStyle {
    let isFocused: Bool
    
    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isFocused || configuration.isPressed ? Color.purple :Color.gray.opacity(0.2)) // Light gray background
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isFocused || configuration.isPressed ? Color.purple : Color.gray, lineWidth: 2) // Dynamic border
            )
            .foregroundStyle(isFocused || configuration.isPressed ? Color.purple : .primary) // Text color adapts to light/dark mode
            .textFieldStyle(.plain) // Removes default styling (optional)
            .focusable()
            .scaleEffect(configuration.isPressed ? 1.1 : 1.0)
    }
}

struct ImmichTVSlideShowButtonStyle: ButtonStyle {
    let isFocused: Bool
    
    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.gray.opacity(0.2)) // Light gray background
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isFocused || configuration.isPressed ? Color.purple : Color.gray, lineWidth: 2) // Dynamic border
            )
            .foregroundStyle(isFocused || configuration.isPressed ? Color.purple : Color.gray) // Text color adapts to light/dark mode
            .textFieldStyle(.plain) // Removes default styling (optional)
            .focusable()
            .scaleEffect(configuration.isPressed ? 1.1 : 1.0)
    }
}

struct ImmichTVTextFieldStyle: ViewModifier {
    let isFocused: Bool
    
    func body(content: Content) -> some View {
        content
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.gray.opacity(0.1)) // Light gray background
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isFocused ? Color.purple : Color.gray, lineWidth: 2) // Dynamic border
                    //.stroke(Color.gray, lineWidth: 2)
            )
            .foregroundStyle(isFocused ? .purple : .primary) // Text color adapts to light/dark mode
            .font(.system(size: 16, weight: .medium, design: .rounded)) // Custom font
            .textFieldStyle(.plain) // Removes default styling (optional)
            .tint(.purple) // Cursor color
            .autocapitalization(.none) // Text input behavior
            .submitLabel(.done) // Keyboard "Done" button
    }
}

extension View {
    func immichTVTestFieldStyle(isFocused: Bool) -> some View {
        self.modifier(ImmichTVTextFieldStyle(isFocused: isFocused))
    }
}
