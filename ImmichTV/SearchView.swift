//
//  SearchView.swift
//  ImmichTV
//
//  Created by David Lüthi on 17.03.2025.
//

import SwiftUI
import UIKit



struct SearchView: View {
    @EnvironmentObject private var immichService: ImmichService
    @EnvironmentObject private var entitlementManager: EntitlementManager
    @State private var searchText = ""
    @State private var query: Query = Query()
    @State private var currentPage: Int = 1
    @State private var matches: Int?
    @FocusState private var focusedButton: String? // Track which button is focused
    @State private var smartquery = ""
    @State private var selectType = "ALL"
    @State private var isFavorite = false
    @State private var isNotInAlbum = false
    @State private var isArchived = false
    @State private var takenAfter: Date? = nil
    @State private var takenBefore: Date? = nil
    @State private var importedAfter: Date? = nil
    @State private var search = false
    @State private var detailSearch = false
    @State private var detailSearchUsed = false
    @State private var error = false
    @State private var errorMessage = ""
    @State private var searchProgress = false
    #if targetEnvironment(macCatalyst)
    @State private var showSlide = false
    @State private var slideActive = false
    #endif
    

    var body: some View {
        VStack(alignment: .leading, spacing: 100) {
            Spacer()
            ScrollView(.vertical, showsIndicators: false) {
                Text("Search Library").font(.title).padding()
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 10) {
                        TextField("Smart Search", text: $smartquery)
                            .immichTVTestFieldStyle(isFocused: focusedButton == "smartsearch")
                            .focused($focusedButton, equals: "smartsearch")
                            #if os(tvOS)
                            .onAppear {
                                focusedButton = "smartsearch"
                            }
                            #endif
                        if !entitlementManager.demo {
                            Button(action: {
                                detailSearch = true
                            }) {
                                Image(systemName: detailSearchUsed ? "text.bubble.fill" : "text.bubble").frame(height: 32)//.buttonStyle(PlainButtonStyle())
                            }.buttonStyle(ImmichTVButtonStyle(isFocused: focusedButton == "searchmask"))
                                .focused($focusedButton, equals: "searchmask")
#if os(tvOS)
                                .sheet(isPresented: $detailSearch) {
                                    SearchDetailView(smartquery: $smartquery, selectType: $selectType, isFavorite: $isFavorite, isNotInAlbum: $isNotInAlbum, isArchived: $isArchived, takenAfter: $takenAfter, takenBefore: $takenBefore, importedAfter: $importedAfter, search: $search, onDismiss: {
                                        self.detailSearchUsed = smartquery != "" || selectType != "ALL" || isFavorite || isNotInAlbum || isArchived || takenAfter != nil || takenBefore != nil || importedAfter != nil
                                    })
                                }
#else
                                .popover(isPresented: $detailSearch) {
                                    SearchDetailView(smartquery: $smartquery, selectType: $selectType, isFavorite: $isFavorite, isNotInAlbum: $isNotInAlbum, isArchived: $isArchived, takenAfter: $takenAfter, takenBefore: $takenBefore, importedAfter: $importedAfter, search: $search, onDismiss: {
                                        self.detailSearchUsed = smartquery != "" || selectType != "ALL" || isFavorite || isNotInAlbum || isArchived || takenAfter != nil || takenBefore != nil || importedAfter != nil
                                    })
                                } 
#endif
                        }
                        Button(action: {
                            search = true
                        }) {
                            Image(systemName: "magnifyingglass").frame(height: 32)//.buttonStyle(PlainButtonStyle())
                        }.buttonStyle(ImmichTVButtonStyle(isFocused: focusedButton == "search"))
                            .focused($focusedButton, equals: "search")
                            .onChange(of: search) {
                                if search {
                                    searchProgress = true
                                    search = false
                                    query = Query(smartquery: smartquery, selectType: selectType, isFavorite: isFavorite, isNotInAlbum: isNotInAlbum, isArchived: isArchived, takenAfter: takenAfter, takenBefore: takenBefore, importedAfter: importedAfter)
                                    Task { @MainActor in
                                        do {
                                            query.page = try await immichService.searchAssets(query: query)
                                            matches = immichService.assetItems.count
                                            currentPage = (query.page ?? 2) - 1
                                            error = false
                                        } catch let error {
                                            self.error = true
                                            errorMessage = error.localizedDescription
                                        }
                                        searchProgress = false
                                    }
                                }
                            }
                        Spacer()
#if targetEnvironment(macCatalyst)
                    Button( action: {
                        showSlide = true
                        slideActive = true
                    }) {
                        Image(systemName: "play").frame(height: 32)
                    }.buttonStyle(ImmichTVButtonStyle(isFocused: focusedButton == "slideshow"))
                        .focused($focusedButton, equals: "slideshow")
                        .fullScreenCover(isPresented: $showSlide, onDismiss: { slideActive = false }) {
                            SlideshowView(query: query).environmentObject(immichService).environmentObject(entitlementManager)
                        }
                    #else
                        NavigationLink(value: NavigationDestination.slide(nil, nil, query)) {
                            Image(systemName: "play").frame(height: 32)//.buttonStyle(PlainButtonStyle())
                        }.disabled(immichService.assetItems.isEmpty)
                            .buttonStyle(ImmichTVButtonStyle(isFocused: focusedButton == "slideshow"))
                            .focused($focusedButton, equals: "slideshow")
#endif
                    }.padding() //smartsearch
                    if error {
                        Text("\(errorMessage)").font(.caption).padding()
                        Spacer()
                    } else if self.matches != nil {
                        HStack(spacing: 10) {
                            if !searchProgress {
                                VStack(alignment: .leading) {
                                    Text("\(matches ?? 0) matches found").font(.caption)
                                    if !query.body.isEmpty {
                                        Text("\(query.body)").multilineTextAlignment(.leading).font(.system(size: 12, weight: .medium, design: .rounded))
                                    }
                                }
                            }
                            Spacer()
                            if query.isPaged {
                                Button(action: {
                                    Task {
                                        searchProgress = true
                                        do {
                                            query.page = try await immichService.searchAssets(query: self.query.toPrevious())
                                            matches = immichService.assetItems.count
                                            currentPage = (query.page ?? 2) - 1
                                            error = false
                                        } catch let error {
                                            self.error = true
                                            errorMessage = error.localizedDescription
                                        }
                                        searchProgress = false
                                    }
                                }) {
                                    Image(systemName: "backward.frame")
                                }.disabled(query.noPreviousPage).buttonStyle(ImmichTVButtonStyle(isFocused: focusedButton == "back"))
                                    .focused($focusedButton, equals: "back")
                                Text("page \(currentPage)").font(.caption)
                                Button(action: {
                                    Task {
                                        searchProgress = true
                                        do {
                                            query.page = try await immichService.searchAssets(query: self.query.toNext())
                                            matches = immichService.assetItems.count
                                            currentPage = (query.page ?? 2) - 1
                                            error = false
                                        } catch let error {
                                            self.error = true
                                            errorMessage = error.localizedDescription
                                        }
                                        searchProgress = false
                                    }
                                }) {
                                    Image(systemName: "forward.frame")
                                }.disabled(query.noNextPage).buttonStyle(ImmichTVButtonStyle(isFocused: focusedButton == "forward"))
                                    .focused($focusedButton, equals: "forward")
                            }
                        }.padding()
                    }
                    if searchProgress {
                        HStack(alignment: .center, spacing: 10) {
                            Spacer()
                            ProgressView().progressViewStyle(CircularProgressViewStyle()).scaleEffect(1)
                            Spacer()
                        }
                    } else if !immichService.assetItems.isEmpty {
                        AssetsView(query: query)
                    }
                    Spacer()
                }
            }
        }.ignoresSafeArea()
    }
}

class Query: Hashable {
    let id = UUID()
    var body: [String: Any] = ["page": 1]
    var isSmartSearch = false
    var page: Int? {
        willSet {
            if newValue == nil {} else if newValue == 2 {
                previousPage = nil
            } else {
                previousPage = newValue! - 2
            }
            nextPage = newValue
        }
    }
    var isPaged: Bool {
        (previousPage != nil || nextPage != nil)
    }
    var noPreviousPage: Bool {
        previousPage == nil
    }
    var noNextPage: Bool {
        nextPage == nil
    }
    private var previousPage: Int? = nil
    private var nextPage: Int? = nil
    
    init(smartquery: String = "", selectType: String = "ALL", isFavorite: Bool = false, isNotInAlbum: Bool = false, isArchived: Bool = false, takenAfter: Date? = nil, takenBefore: Date? = nil, importedAfter: Date? = nil) {
        addQuery(smartquery: smartquery, selectType: selectType, isFavorite: isFavorite, isNotInAlbum: isNotInAlbum, isArchived: isArchived, takenAfter: takenAfter, takenBefore: takenBefore, importedAfter: importedAfter)
    }
    
    func addQuery(smartquery: String = "", selectType: String = "ALL", isFavorite: Bool = false, isNotInAlbum: Bool = false, isArchived: Bool = false, takenAfter: Date? = nil, takenBefore: Date? = nil, importedAfter: Date? = nil) {
        if smartquery != "" {
            body["query"] = smartquery
            isSmartSearch = true
        } else {
            isSmartSearch = false
        }
        if selectType != "ALL" {
            body["type"] = selectType
        }
        if isFavorite {
            body["isFavorite"] = isFavorite
        }
        if isNotInAlbum {
            body["isNotInAlbum"] = isNotInAlbum
        }
        if isArchived {
            body["isArchived"] = isArchived
        }
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime]
        if let ta = takenAfter {
            body["takenAfter"] = isoFormatter.string(from: ta)
        }
        if let tb = takenBefore {
            body["takenBefore"] = isoFormatter.string(from: tb)
        }
        if let ia = importedAfter {
            body["createdAfter"] = isoFormatter.string(from: ia)
            body["order"] = "asc"
        }
        body["page"] = 1
    }
    
    func toPrevious() -> Query {
        body["page"] = previousPage
        return self
    }
    
    func toNext() -> Query {
        body["page"] = nextPage
        return self
    }
    
    static func == (lhs: Query, rhs: Query) -> Bool {
        return lhs.id == rhs.id && NSDictionary(dictionary: lhs.body).isEqual(to: rhs.body)
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        // Hash the query dictionary by converting to a hashable form
        for (key, value) in body.sorted(by: { $0.key < $1.key }) {
            hasher.combine(key)
            // Handle common types; extend as needed
            if let stringValue = value as? String {
                hasher.combine(stringValue)
            } else if let intValue = value as? Int {
                hasher.combine(intValue)
            } // Add more type cases as needed
        }
    }
}
