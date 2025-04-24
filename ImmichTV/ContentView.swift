//
//  ContentView.swift
//  ImmichTV
//
//  Created by David Lüthi on 17.03.2025.
//

import SwiftUI

// Define navigation destinations
enum NavigationDestination: Hashable {
    case settings
    case search
    case album(albumId: String, albumName: String)
    case slide(String? = nil, Int? = nil, Query? = nil)
}

struct ContentView: View {
    @EnvironmentObject private var entitlementManager: EntitlementManager
    @EnvironmentObject private var immichService: ImmichService
    @FocusState private var focusedButton: String? // Track which button is focused
    @State var user = ""
    @State var error = false
    @State var errorMessage = ""
    @State var isLoading = true
    @State private var navigationPath = NavigationPath() // Manages navigation stack
    @State private var cameFromSetting: Bool = true
    @State private var isloading = true
    @State private var slideActive = false
    #if targetEnvironment(macCatalyst)
    @State private var showSearch = false
    @State private var showSetting = false
    #endif
 

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if isLoading {
                    ProgressView().progressViewStyle(CircularProgressViewStyle()).scaleEffect(1)
                } else if error {
                    Text(errorMessage).font(.caption)
                        .onTapGesture {
                            navigationPath.append(NavigationDestination.settings)
                        }
                } else if immichService.albumsGrouped.isEmpty {
                    Text("no albums").font(.caption)
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        AssetsView(showAlbums: true, ascending: .constant(false))
                    }.navigationTitle("Immich Albums \(user == "" ? "" : "of \(user)")")
                }
            }.toolbar {
                ToolbarItem(placement: .navigation) {
#if targetEnvironment(macCatalyst)
                    Button( action: {
                        showSearch = true
                        if !slideActive {
                            immichService.assetItemsGrouped.removeAll()
                            immichService.assetItems.removeAll()
                        }
                    }){
                        Image(systemName: "magnifyingglass")
                    }.buttonStyle(ImmichTVButtonStyle(isFocused: focusedButton == "search"))
                        .focused($focusedButton, equals: "search")
                        .fullScreenCover(isPresented: $showSearch) {
                            ZStack(alignment: .topLeading) {
                                Button(action: {
                                    showSearch = false
                                }) {
                                    Image(systemName: "x.square")//.padding(.horizontal, 30)
                                }.buttonStyle(ImmichTVSlideShowButtonStyle(isFocused: focusedButton == "close"))
                                    .focused($focusedButton, equals: "close")
                                    .zIndex(1)
                                    .padding(.leading, 20)
                                SearchView().environmentObject(immichService).environmentObject(entitlementManager)
                            }
                        }
                    #else
                    NavigationLink(value: NavigationDestination.search) {
                        Image(systemName: "magnifyingglass")//.frame(width: 150, height: 60)
                    }.buttonStyle(ImmichTVButtonStyle(isFocused: focusedButton == "search"))
                    .focused($focusedButton, equals: "search")
                    #endif
                }
                ToolbarItem(placement: .primaryAction) {
#if targetEnvironment(macCatalyst)
                    Button( action: {
                        showSetting = true
                    }){
                        Image(systemName: "gear")
                    }.buttonStyle(ImmichTVButtonStyle(isFocused: focusedButton == "settings"))
                        .focused($focusedButton, equals: "settings")
                        .fullScreenCover(isPresented: $showSetting) {
                            VStack(alignment: .leading) {
                                Button(action: {
                                    showSetting = false
                                }) {
                                    Image(systemName: "x.square")//.padding(.horizontal, 30)
                                }.buttonStyle(ImmichTVSlideShowButtonStyle(isFocused: focusedButton == "close"))
                                    .focused($focusedButton, equals: "close")
                                    .zIndex(1)
                                    .padding(.leading, 20)
                                SettingView(cameFromSetting: $cameFromSetting).environmentObject(immichService).environmentObject(entitlementManager)
                            }
                        }
                    #else
                    NavigationLink(value: NavigationDestination.settings) {
                    //NavigationLink(destination: SettingView(immichService: immichService), isActive: $configure) {
                        Image(systemName: "gear")//.frame(width: 150, height: 60)
                    }.buttonStyle(ImmichTVButtonStyle(isFocused: focusedButton == "settings"))
                        .focused($focusedButton, equals: "settings")
                    #endif
                }
            }.onAppear{
                Task {
                   // if cameFromSetting {
                        cameFromSetting = false
                        error = false
                        isLoading = true
                        immichService.albumsGrouped.removeAll()
                        if entitlementManager.notConfigured {
                            user = ""
                            focusedButton = "settings"
                            self.error = true
                            errorMessage = "not configured yet"
                            isLoading = false
                        } else {
                            do {
                                user = try await immichService.getMyUser()
                                try await immichService.fetchAlbums()
                                error = false
                                isLoading = false
                            } catch {
                                self.error = true
                                errorMessage = (error as NSError).domain
                                immichService.albumsGrouped.removeAll()
                                user = ""
                                focusedButton = "settings"
                                isLoading = false
                            }
                        }
                    //}
                }
            }
            // Define navigation destinations
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationDestination(for: NavigationDestination.self) { destination in
                switch destination {
                case .search:
                    SearchView()
                        .onAppear {
                            if !slideActive {
                                immichService.assetItemsGrouped.removeAll()
                                immichService.assetItems.removeAll()
                            }
                        }
                case .settings:
                    SettingView(cameFromSetting: $cameFromSetting)
                case .album(let albumId, let albumName):
                    AlbumView(albumId: albumId, albumName: albumName, isLoading: $isLoading)
                        .onAppear {
                            if !slideActive {
                                immichService.assetItemsGrouped.removeAll()
                                immichService.assetItems.removeAll()
                                isLoading = true
                                Task {
                                    do {
                                        try Task.checkCancellation() // Throws if cancelled
                                        try await immichService.fetchAssets(albumId: albumId)
                                        isLoading = false
                                    } catch {
                                        print("Failed to fetch pictures: \(error)")
                                        isLoading = false
                                    }
                                }
                            }
                        }
                case .slide(let albumName, let index, let query):
                    SlideshowView(albumName: albumName, index: index, query: query)
                        .onAppear {
                            slideActive = true
                        }
                        .onDisappear {
                            slideActive = false
                        }
                }
            }
            .animation(.easeInOut(duration: 0.2), value: focusedButton)
        }.navigationViewStyle(.stack) // Ensures consistent navigation behavior
            .accentColor(.primary) // Affects all interactive elements
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
                #if os(tvOS)
                    .stroke(isFocused || configuration.isPressed ? Color.purple : Color.gray, lineWidth: 2) // Dynamic border
                #else
                    .stroke(configuration.isPressed ? Color.purple : Color.gray, lineWidth: 2) // Dynamic border
                #endif
            )
#if os(tvOS)
            .foregroundStyle(isFocused || configuration.isPressed ? Color.purple : .primary) // Text color adapts to light/dark mode
        #else
            .foregroundStyle(configuration.isPressed ? Color.purple : .primary) // Text color adapts to light/dark mode
        #endif
            .textFieldStyle(.plain) // Removes default styling (optional)
            .focusable()
            .scaleEffect(configuration.isPressed ? 1.1 : 1.0)
    }
}

struct ImmichTVTaleStyle: ButtonStyle {
    let isFocused: Bool
    
    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(isFocused || configuration.isPressed ? Color.purple : Color.gray,
                            lineWidth: isFocused || configuration.isPressed ? 2 : 0) // Dynamic border
            )
            .textFieldStyle(.plain) // Removes default styling (optional)
            .focusable()
            .scaleEffect(isFocused || configuration.isPressed ? 1.1 : 1.0)
            .zIndex(isFocused || configuration.isPressed ? 10 : 0) // Ensure bar is above image
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
                #if os(tvOS)
                    .stroke(isFocused || configuration.isPressed ? Color.purple : Color.gray, lineWidth: 2) // Dynamic border
                #else
                    .stroke(configuration.isPressed ? Color.purple : Color.gray, lineWidth: 2) // Dynamic border
                #endif
            )
#if os(tvOS)
            .foregroundStyle(isFocused || configuration.isPressed ? Color.purple : Color.gray) // Text color adapts to light/dark mode
        #else
            .foregroundStyle(configuration.isPressed ? Color.purple : Color.gray) // Text color adapts to light/dark mode
        #endif
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
                #if os(tvOS)
                    .stroke(isFocused ? Color.purple : Color.gray, lineWidth: 2) // Dynamic border
                    //.stroke(Color.gray, lineWidth: 2)
                #else
                    .stroke(Color.gray, lineWidth: 2) // Dynamic border
                    //.stroke(Color.gray, lineWidth: 2)
                #endif
            )
#if os(tvOS)
            .foregroundStyle(isFocused ? .purple : .primary) // Text color adapts to light/dark mode
#else
            .foregroundStyle(.primary) // Text color adapts to light/dark mode
#endif
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
