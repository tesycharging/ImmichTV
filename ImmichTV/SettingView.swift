//
//  SettingView.swift
//  ImmichTV
//
//  Created by David Lüthi on 18.03.2025.
//

import SwiftUI
import UniformTypeIdentifiers
import AVKit

struct SettingView: View {
    @EnvironmentObject private var immichService: ImmichService
    @EnvironmentObject private var entitlementManager: EntitlementManager
    @Binding var cameFromSetting: Bool
    @State var baseURL: String = ""
    @State var apiKey: String = ""
    @State var slideShowOfThumbnails = false
    @State var playVideo = false
    @State var groupByDay = false
    @State var timeinterval = 5.0
    @State var storage: Storage?
    @State var username = ""
    @State var password = ""
    @State private var credentialPopup = false
    @State var message = ""
    @Environment(\.dismiss) private var dismiss // For dismissing the full-screen view
    @FocusState private var focusedButton: String? // Track which button is focused
    @State var selectedMusic: String = UserDefaults.group.string(forKey: "selectedMusic") ?? "no sound"
    @State private var musicOptions: Dictionary<String, String> = UserDefaults.group.loadOptions() ??
    ["Song-1": "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3",
     "Song-2": "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3",
     "Song-3": "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3",
     "Song-4": "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-4.mp3",
     "Song-5": "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-5.mp3",
     "no sound": ""]
    @State private var addMusic = false
    @State private var title = ""
    @State private var url = ""
    @State private var isPlaying = false
    @State private var comeFromSubview = false
    @StateObject var playModel: PlaylistViewModel = PlaylistViewModel()
    
    var pickers: some View {
        Group {
            Text("time interval")
            Picker("Select a number", selection: $timeinterval) {
                ForEach(Array(stride(from: 3.0, through: 10.0, by: 1.0)), id: \.self) { number in
                    Text("\(number, specifier: "%.1f")").tag(number)
                }
            }.pickerStyle(.menu)
                .immichTVTestFieldStyle(isFocused: focusedButton == "picker")
                .focused($focusedButton, equals: "picker")
            Text("music")
            HStack(spacing: 5) {
                // Picker to select an musicOption
                Picker("Select a music", selection: $selectedMusic) {
                    ForEach(musicOptions.keys.sorted(), id: \.self) { key in
                        Text(key).tag(key)
                    }
                }.pickerStyle(.menu)
                    .immichTVTestFieldStyle(isFocused: focusedButton == "pickerMusic")
                    .focused($focusedButton, equals: "pickerMusic")
                    .onChange(of: selectedMusic) { _, newValue in
                        playModel.playerMusic.pause()
                        isPlaying = false
                    }
                Button(action: {
                    isPlaying.toggle()
                    if isPlaying {
                        let url: URL
                        let value = musicOptions[selectedMusic] ?? ""
                        if URL(string: value)?.scheme?.lowercased() == nil {
                            let fileManager = FileManager.default
                            let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
                            url = documentsDirectory.appendingPathComponent(musicOptions[selectedMusic] ?? "")
                        } else {
                            url = URL(string: value)!
                        }
                        playModel.playMusicSetup(url: url, autoplay: true)
                    } else {
                        playModel.playerMusic.pause()
                    }
                }) {
                    Image(systemName: isPlaying ? "pause" : "play")
                }.buttonStyle(ImmichTVButtonStyle(isFocused: focusedButton == "play"))
                    .focused($focusedButton, equals: "play")
                Button("add") {
                    addMusic =  true
                }.buttonStyle(ImmichTVButtonStyle(isFocused: focusedButton == "add"))
                    .focused($focusedButton, equals: "add")
#if os(tvOS)
                    .sheet(isPresented: $addMusic) {
                        AddMusicPopup(key: $title, value: $url, isPresented: $addMusic, comeFromSubview: $comeFromSubview, onSubmit: {
                            musicOptions[title] = url
                            selectedMusic = title
                        })
                    }
#else
                    .popover(isPresented: $addMusic) {
                        AddMusicPopup(key: $title, value: $url, isPresented: $addMusic, comeFromSubview: $comeFromSubview, onSubmit: {
                            musicOptions[title] = url
                            selectedMusic = title
                        })
                    }
#endif
            }
            Spacer()
            Button("update settings") {
                entitlementManager.baseURL = baseURL
                entitlementManager.apiKey = apiKey
                entitlementManager.slideShowOfThumbnails = slideShowOfThumbnails
                entitlementManager.playVideo = playVideo
                entitlementManager.timeinterval = timeinterval
                entitlementManager.groupByDay = groupByDay
                entitlementManager.timeinterval = timeinterval
                entitlementManager.selectedMusic = selectedMusic
                entitlementManager.musicOptions = musicOptions
                cameFromSetting = true
                dismiss()
            }.buttonStyle(ImmichTVButtonStyle(isFocused: focusedButton == "updatesettings"))
                .focused($focusedButton, equals: "updatesettings")
        }
    }
    
    var body: some View {
        VStack {
            ScrollView(.vertical, showsIndicators: false) {
                TextField("http://immich-server:2283", text: $baseURL).immichTVTestFieldStyle(isFocused: focusedButton == "server")
                    .focused($focusedButton, equals: "server")
                    .onAppear {
                        #if os(tvOS)
                        focusedButton = "server"
                        #endif
                        message = ""
                        if !comeFromSubview {
                            baseURL = entitlementManager.baseURL
                            apiKey = entitlementManager.apiKey
                            slideShowOfThumbnails = entitlementManager.slideShowOfThumbnails
                            playVideo = entitlementManager.playVideo
                            groupByDay = entitlementManager.groupByDay
                            timeinterval = entitlementManager.timeinterval
                            Task {@MainActor in
                                do {
                                    storage = try await immichService.getStorage()
                                } catch {
                                    print(error.localizedDescription)
                                }
                            }
                        } else {
                            comeFromSubview = false
                        }
                    }
                Text("persmission for api-key should be at least \"album.read\"")
                    .padding(.horizontal)
                    .cornerRadius(10)
                HStack {
                    SecureField("API key", text: $apiKey)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .immichTVTestFieldStyle(isFocused: focusedButton == "apikey")
                        .focused($focusedButton, equals: "apikey")
                    Button("generate api key") {
                        credentialPopup = true
                    }.buttonStyle(ImmichTVButtonStyle(isFocused: focusedButton == "generate"))
                        .focused($focusedButton, equals: "generate")
                        .disabled(baseURL == "")
#if os(tvOS)
                        .sheet(isPresented: $credentialPopup) {
                            CredentialsPopup(baseURL: $baseURL, username: $username, password: $password, isPresented: $credentialPopup, comeFromSubview: $comeFromSubview, onSubmit: {
                                Task { @MainActor in
                                    do {
                                        apiKey = try await immichService.createAPIKey(baseURL: baseURL, email: username, password: password)
                                        message = ""
                                    } catch let apiError as APIError {
                                        message = apiError.localizedDescription
                                    } catch {
                                        message = "Error: \(error.localizedDescription)"
                                    }
                                }
                            })
                        }
#else
                        .popover(isPresented: $credentialPopup) {
                            CredentialsPopup(baseURL: $baseURL, username: $username, password: $password, isPresented: $credentialPopup, comeFromSubview: $comeFromSubview, onSubmit: {
                                Task { @MainActor in
                                    do {
                                        apiKey = try await immichService.createAPIKey(baseURL: baseURL, email: username, password: password)
                                        message = ""
                                    } catch let apiError as APIError {
                                        message = apiError.localizedDescription
                                    } catch {
                                        message = "Error: \(error.localizedDescription)"
                                    }
                                }
                            })
                        }
#endif
                }
                Text(message)
                    .padding(.horizontal)
                    .cornerRadius(10)
                Toggle("Slide Show with Thumbnails", isOn: $slideShowOfThumbnails)
                    .immichTVTestFieldStyle(isFocused: focusedButton == "toggle")
                    .focused($focusedButton, equals: "toggle")
                Toggle("play videos", isOn: $playVideo)
                    .immichTVTestFieldStyle(isFocused: focusedButton == "video")
                    .focused($focusedButton, equals: "video")
                    .disabled(slideShowOfThumbnails)
                    .opacity(!slideShowOfThumbnails ? 1.0: 0.5)
                Toggle("group assets by day", isOn: $groupByDay)
                    .immichTVTestFieldStyle(isFocused: focusedButton == "groupby")
                    .focused($focusedButton, equals: "groupby")
                #if os(tvOS)
                HStack {
                    pickers
                }
                #else
                VStack {
                    pickers
                }
                #endif
                Spacer()
                if let storage = self.storage {
                    Divider()
                    Text("Storage Details of Immich Server").font(.headline).padding(.horizontal, 20)
                    Text("Disk Available: \(storage.diskAvailable)").font(.caption2).padding(.horizontal, 20)
                    Text("Disk Size: \(storage.diskSize)").font(.caption2).padding(.horizontal, 20)
                    Text("Disk Usage: \(storage.diskUsagePercentage) %").font(.caption2).padding(.horizontal, 20)
                    Text("Disk Use: \(storage.diskUse)").font(.caption2).padding(.horizontal, 20)
                }
            }
            #if os(tvOS)
            .onChange(of: timeinterval) { _, _ in
                focusedButton = "updateButton"
            }
            #endif
        }.padding(20)
        .navigationTitle("Settings")
        .blur(radius: credentialPopup ? 10 : 0)
        .onDisappear {
            playModel.playerMusic.pause()
        }
    }
}

struct CredentialsPopup: View {
    @Binding var baseURL: String
    @Binding var username: String
    @Binding var password: String
    @Binding var isPresented: Bool
    @Binding var comeFromSubview: Bool
    var onSubmit: () -> Void
    @FocusState private var focusedButton: String?
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Enter Credentials for")
                .font(.headline)
            Text(baseURL)
                .font(.caption)
            
            TextField("Username (Email)", text: $username)
                .autocapitalization(.none)
                .immichTVTestFieldStyle(isFocused: focusedButton == "email")
                .focused($focusedButton, equals: "email")
            
            SecureField("Password", text: $password)
                .immichTVTestFieldStyle(isFocused: focusedButton == "password")
                .focused($focusedButton, equals: "password")
            
            HStack(spacing: 20) {
                Button("Cancel") {
                    isPresented = false
                }.buttonStyle(ImmichTVButtonStyle(isFocused: focusedButton == "cancel"))
                    .focused($focusedButton, equals: "cancel")
                
                Button("genarate api key") {
                    if !username.isEmpty && !password.isEmpty {
                        onSubmit()
                        isPresented = false
                    }
                }.buttonStyle(ImmichTVButtonStyle(isFocused: focusedButton == "ok"))
                    .focused($focusedButton, equals: "ok")
                .disabled(username.isEmpty || password.isEmpty)
            }
            Spacer()
        }
        .padding(20)
        .cornerRadius(12)
        .shadow(radius: 10)
        .onAppear{
            comeFromSubview = true
        }
    }
}

struct AddMusicPopup: View {
    @Binding var key: String
    @Binding var value: String
    @Binding var isPresented: Bool
    @Binding var comeFromSubview: Bool
    var onSubmit: () -> Void
    @FocusState private var focusedButton: String?
    @State private var isShowingMP3Picker = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("add a link to a mp3 for the slideshow background music")
                .font(.headline)
            TextField("title", text: $key)
                .autocapitalization(.none)
                .immichTVTestFieldStyle(isFocused: focusedButton == "key")
                .focused($focusedButton, equals: "key")
            TextField("url", text: $value)
                .autocapitalization(.none)
                .immichTVTestFieldStyle(isFocused: focusedButton == "value")
                .focused($focusedButton, equals: "value")
            #if os(tvOS)
            #else
            Button("choose MP3") {
                isShowingMP3Picker = true
            }.immichTVTestFieldStyle(isFocused: focusedButton == "mp3")
                .focused($focusedButton, equals: "mp3")
            #if targetEnvironment(macCatalyst)
                .background(isShowingMP3Picker ? DocumentPicker {
                    key = $0.lastPathComponent
                    value = $0.absoluteString
                    print(key)
                    print(value)
                   // isShowingMP3Picker = false
                } : nil)
    #else
                .sheet(isPresented: $isShowingMP3Picker) {
                    DocumentPicker(title: $key, selectedURL: $value)
                }
            #endif
            #endif
            HStack(spacing: 20) {
                Button("Cancel") {
                    isPresented = false
                }.buttonStyle(ImmichTVButtonStyle(isFocused: focusedButton == "cancel"))
                    .focused($focusedButton, equals: "cancel")
                
                Button("add music") {
                    if !key.isEmpty && !value.isEmpty {
                        onSubmit()
                        isPresented = false
                    }
                }.buttonStyle(ImmichTVButtonStyle(isFocused: focusedButton == "ok"))
                    .focused($focusedButton, equals: "ok")
                    .disabled(key.isEmpty || value.isEmpty)
            }
            Spacer()
        }
        .padding(20)
        .cornerRadius(12)
        .shadow(radius: 10)
        .onAppear{
            comeFromSubview = true
        }
    }
}

#if os(tvOS)
#else
// UIViewControllerRepresentable for UIDocumentPickerViewController
struct DocumentPicker: UIViewControllerRepresentable {
    #if targetEnvironment(macCatalyst)
    var callback: (URL) -> Void
    #else
    @Binding var title: String
    @Binding var selectedURL: String
    #endif
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.mp3], asCopy: true)
        picker.allowsMultipleSelection = false // Set to true if you want multiple files
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {
        // No updates needed
    }
    
#if targetEnvironment(macCatalyst)
    func makeUIViewController(context: Context) -> UIViewController {
      let controller = UIViewController()
      controller.view.backgroundColor = .clear // invisible dummy controller

      // Present after slight delay to ensure hierarchy is ready
      DispatchQueue.main.async {
          let types = [UTType.mp3]
          let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
          picker.delegate = context.coordinator

          if let root = UIApplication.shared.connectedScenes
              .compactMap({ ($0 as? UIWindowScene)?.keyWindow })
              .first?.rootViewController {
              root.present(picker, animated: true, completion: nil)
          }
      }

      return controller
  }
    #endif
    
    func makeCoordinator() -> Coordinator {
#if targetEnvironment(macCatalyst)
        Coordinator(callback: callback)
        #else
        Coordinator(self)
        #endif
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        #if targetEnvironment(macCatalyst)
        var callback: (URL) -> Void
        #else
        let parent: DocumentPicker
        #endif
        
        #if targetEnvironment(macCatalyst)
        init(callback: @escaping (URL) -> Void) {
           self.callback = callback
        }
        #else
        init(_ parent: DocumentPicker) {
            self.parent = parent
        }
        #endif
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            #if targetEnvironment(macCatalyst)
            print(url)
            callback(url)
            #else
            // Security-scoped resource access
            let shouldStopAccessing = url.startAccessingSecurityScopedResource()
            defer {
                if shouldStopAccessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            
            // Copy the file to a permanent location
            if let permanentURL = copyFileToDocumentsDirectory(from: url) {
                parent.title = permanentURL.lastPathComponent
                parent.selectedURL = permanentURL.lastPathComponent
            }
            #endif
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {}
        
        // Function to copy the file to the Documents directory
        private func copyFileToDocumentsDirectory(from sourceURL: URL) -> URL? {
            let fileManager = FileManager.default
            let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let destinationURL = documentsDirectory.appendingPathComponent(sourceURL.lastPathComponent)
            
            do {
                // Remove existing file at destination if it exists
                if fileManager.fileExists(atPath: destinationURL.path) {
                    try fileManager.removeItem(at: destinationURL)
                }
                // Copy the file to the Documents directory
                try fileManager.copyItem(at: sourceURL, to: destinationURL)
                return destinationURL
            } catch {
                print("Failed to copy file: \(error.localizedDescription)")
                return nil
            }
        }
    }
}
#endif
