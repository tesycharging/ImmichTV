//
//  SettingView.swift
//  ImmichTV
//
//  Created by David Lüthi on 18.03.2025.
//

import SwiftUI

struct SettingView: View {
    var immichService: ImmichService
    @State var baseURL: String
    @State var apikey: String
    @State var slideShowOfThumbnails = false
    @State var playVideo = false
    @State private var timeinterval = 5.0
    @State var storage: Storage?
    @State var username = ""
    @State var password = ""
    @State private var credentialPopup = false
    @State var message = ""
    @Environment(\.dismiss) private var dismiss // For dismissing the full-screen view
    @FocusState private var focusedButton: String? // Track which button is focused
    
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
                        slideShowOfThumbnails = UserDefaults.standard.bool(forKey: "slideShowOfThumbnails")
                        playVideo = UserDefaults.standard.bool(forKey: "playVideo")
                        timeinterval = UserDefaults.standard.double(forKey: "timeinterval")
                        if timeinterval < 3 {
                            timeinterval = 5
                        }
                        Task {@MainActor in
                            do {
                                storage = try await immichService.getStorage()
                            } catch {
                                print(error.localizedDescription)
                            }
                        }
                    }
                HStack {
                    SecureField("API key", text: $apikey)
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
                            CredentialsPopup(baseURL: $baseURL, username: $username, password: $password, isPresented: $credentialPopup, onSubmit: {
                                Task { @MainActor in
                                    do {
                                        apikey = try await immichService.createAPIKey(baseURL: baseURL + "/api", email: username, password: password)
                                        message = ""
                                    } catch {
                                        message = "Error: \(error.localizedDescription)"
                                    }
                                }
                            })
                        }
#else
                        .popover(isPresented: $credentialPopup) {
                            CredentialsPopup(baseURL: $baseURL, username: $username, password: $password, isPresented: $credentialPopup, onSubmit: {
                                Task { @MainActor in
                                    do {
                                        apikey = try await immichService.createAPIKey(baseURL: baseURL + "/api", email: username, password: password)
                                        message = ""
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
                HStack {
                    Text("time interval of slideshow")
                    Picker("Select a number", selection: $timeinterval) {
                        ForEach(Array(stride(from: 3.0, through: 10.0, by: 1.0)), id: \.self) { number in
                            Text("\(number, specifier: "%.1f")").tag(number)
                        }
                    }
                    .pickerStyle(.menu)
                    .immichTVTestFieldStyle(isFocused: focusedButton == "picker")
                    .focused($focusedButton, equals: "picker")
                    .id("picker") // Assign an ID
                    
                    Spacer()
                    Button("update settings") {
                        UserDefaults.standard.set(baseURL, forKey: "baseURL")
                        UserDefaults.standard.set(apikey, forKey: "apikey")
                        UserDefaults.standard.set(slideShowOfThumbnails, forKey: "slideShowOfThumbnails")
                        UserDefaults.standard.set(playVideo, forKey: "playVideo")
                        UserDefaults.standard.set(timeinterval, forKey: "timeinterval")
                        immichService.loadSettings()
                        dismiss()
                    }.buttonStyle(ImmichTVButtonStyle(isFocused: focusedButton == "updatesettings"))
                        .focused($focusedButton, equals: "updatesettings")
                        .id("updateButton") // Assign an ID
                }
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
        }.padding()
        .navigationTitle("Settings")
        .blur(radius: credentialPopup ? 10 : 0)
    }
}

struct CredentialsPopup: View {
    @Binding var baseURL: String
    @Binding var username: String
    @Binding var password: String
    @Binding var isPresented: Bool
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
        .padding()
        .cornerRadius(12)
        .shadow(radius: 10)
    }
}
