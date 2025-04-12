//
//  SearchDetailView.swift
//  ImmichTV
//
//  Created by David Lüthi on 01.04.2025.
//

import SwiftUI

struct SearchDetailView: View {
    @Binding var smartquery: String
    var assetType = ["IMAGE", "VIDEO", "ALL"]
    @Binding var selectType : String
    @Binding var isFavorite: Bool
    @Binding var isNotInAlbum: Bool
    @Binding var isArchived: Bool
    @Binding var takenAfter: Date?
    @Binding var takenBefore: Date?
    @Binding var importedAfter: Date?
    @State var reset: Bool = false
    @Binding var search: Bool
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedButton: String? // Track which button is focused
    var onDismiss: () -> ()
    
    func resetSearch() {
        smartquery = ""
        selectType = "ALL"
        isFavorite = false
        isNotInAlbum = false
        isArchived = false
        takenAfter = nil
        takenBefore = nil
        importedAfter = nil
        reset = true
    }
    
    var body: some View {
        VStack(alignment: .center) {
            HStack(spacing: 5) {
                TextField("Smart Search", text: $smartquery)
                    .immichTVTestFieldStyle(isFocused: focusedButton == "smartsearch")
                    .focused($focusedButton, equals: "smartsearch")
            } //smartsearch
            #if os(tvOS)
            .onAppear {
                focusedButton = "smartsearch"
            }
            #endif
            HStack(spacing: 5) {
                Picker("Select a type", selection: $selectType) {
                    Image(systemName: "photo").tag("IMAGE").frame(height: 32)
                    Image(systemName: "video").tag("VIDEO").frame(height: 32)
                    Image(systemName: "livephoto.play").tag("ALL").frame(height: 32)
                }.pickerStyle(.menu) // or .wheel, .segmented
                    .immichTVTestFieldStyle(isFocused: focusedButton == "type")
                    .focused($focusedButton, equals: "type")
                Button(action: {
                    isFavorite.toggle()
                }) {
                    Image(systemName: isFavorite ? "heart.fill" : "heart").frame(height: 32)//.buttonStyle(PlainButtonStyle())
                }.buttonStyle(ImmichTVButtonStyle(isFocused: focusedButton == "favorite"))
                    .focused($focusedButton, equals: "favorite")
                Button(action: {
                    isNotInAlbum.toggle()
                }) {
                    Image(systemName: isNotInAlbum ? "swatchpalette" : "swatchpalette.fill").frame(height: 32)//.buttonStyle(PlainButtonStyle())
                }.buttonStyle(ImmichTVButtonStyle(isFocused: focusedButton == "NotInAlbum"))
                    .focused($focusedButton, equals: "NotInAlbum")
                Button(action: {
                    isArchived.toggle()
                }) {
                    Image(systemName: isArchived ? "archivebox.fill" : "archivebox").frame(height: 32)//.buttonStyle(PlainButtonStyle())
                }.buttonStyle(ImmichTVButtonStyle(isFocused: focusedButton == "Archived"))
                    .focused($focusedButton, equals: "Archived")
            }
            VStack(spacing: 10) {
                #if os(tvOS)
                DateSelectionView(label: "taken after", chosenDate: $takenAfter, reset: $reset).frame(height: 64)
                DateSelectionView(label: "taken before", chosenDate: $takenBefore, reset: $reset).frame(height: 64)
                DateSelectionView(label: "imported after", chosenDate: $importedAfter, reset: $reset).frame(height: 64)
                #else
                DateSelectionVIewIOS(label: "after", selectDate: $takenAfter)
                DateSelectionVIewIOS(label: "before", selectDate: $takenBefore)
                DateSelectionVIewIOS(label: "imported", selectDate: $importedAfter)
                #endif
            }
            HStack(spacing: 5) {
                Button(action: {
                    resetSearch()
                }) {
                    Image(systemName: "eraser.line.dashed").frame(height: 32)//.buttonStyle(PlainButtonStyle())
                }.buttonStyle(ImmichTVButtonStyle(isFocused: focusedButton == "reset"))
                    .focused($focusedButton, equals: "reset")
                Button(action: {
                    search = true
                    onDismiss()
                    dismiss()
                }) {
                    Image(systemName: "magnifyingglass").frame(height: 32)//.buttonStyle(PlainButtonStyle())
                }.buttonStyle(ImmichTVButtonStyle(isFocused: focusedButton == "search"))
                    .focused($focusedButton, equals: "search")
            }
            Spacer()
        }.padding(20)
            .onDisappear() {
                onDismiss()
            }
    }
}


