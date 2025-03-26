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
    @State private var timeinterval = "5"
    @State var storage: Storage?
    @State var username = ""
    @State var password = ""
    @State private var credentialPopup = false
    @State var message = ""
    @Environment(\.dismiss) private var dismiss // For dismissing the full-screen view
    
    var body: some View {
        VStack {
            TextField("http://immich-server:2283", text: $baseURL)
                .textFieldStyle(PlainTextFieldStyle())
                .padding()
                .frame(width: UIScreen.main.bounds.width - 20)
                .onAppear {
                    message = ""
                    slideShowOfThumbnails = UserDefaults.standard.bool(forKey: "slideShowOfThumbnails")
                    timeinterval = UserDefaults.standard.string(forKey: "timeinterval") ?? "5"
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
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding()
                Button("generate api key") {
                    credentialPopup = true
                }.sheet(isPresented: $credentialPopup) {
                    CredentialsPopup(username: $username, password: $password, isPresented: $credentialPopup, onSubmit: {
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
            }.frame(width: UIScreen.main.bounds.width - 40)
            Text(message)
                .textFieldStyle(PlainTextFieldStyle())
                .padding()
                .frame(width: UIScreen.main.bounds.width - 20)
            Toggle("Slide Show with Thumbnails", isOn: $slideShowOfThumbnails)
                .padding()
                .frame(width: UIScreen.main.bounds.width - 20)
            TextField("time interval of slideshow", text: $timeinterval).keyboardType(.numberPad)
                .onChange(of: timeinterval) { newValue in
                                    let filtered = newValue.filter { $0.isNumber } // Allow only numbers
                                    if let number = Double(filtered) {
                                        if number < 3 {
                                            timeinterval = "3"
                                        } else if number > 10 {
                                            timeinterval = "10"
                                        } else {
                                            timeinterval = filtered
                                        }
                                    } else {
                                        timeinterval = "5" // Default if invalid input
                                    }
                                }
                .textFieldStyle(PlainTextFieldStyle())
                .padding()
                .frame(width: UIScreen.main.bounds.width - 20)
            
            Button("update settings") {
                UserDefaults.standard.set(baseURL, forKey: "baseURL")
                UserDefaults.standard.set(apikey, forKey: "apikey")
                UserDefaults.standard.set(slideShowOfThumbnails, forKey: "slideShowOfThumbnails")
                UserDefaults.standard.set(timeinterval, forKey: "timeinterval")
                immichService.loadSettings()
                dismiss()
            }.buttonStyle(DefaultButtonStyle())
            if let storage = self.storage {
                Divider()
                Text("Storage Details of Immich Server").font(.headline).padding(.horizontal, 20)
                Text("Disk Available: \(storage.diskAvailable)").font(.caption2).padding(.horizontal, 20)
                Text("Disk Size: \(storage.diskSize)").font(.caption2).padding(.horizontal, 20)
                Text("Disk Usage: \(storage.diskUsagePercentage) %").font(.caption2).padding(.horizontal, 20)
                Text("Disk Use: \(storage.diskUse)").font(.caption2).padding(.horizontal, 20)
            }
        }
        .navigationTitle("Settings")
    }
}

struct CredentialsPopup: View {
    @Binding var username: String
    @Binding var password: String
    @Binding var isPresented: Bool
    var onSubmit: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Enter Credentials")
                .font(.headline)
            
            TextField("Username (Email)", text: $username)
                .autocapitalization(.none)
                .padding(.horizontal)
            
            SecureField("Password", text: $password)
                .padding(.horizontal)
            
            HStack(spacing: 20) {
                Button("Cancel") {
                    isPresented = false
                }.buttonStyle(DefaultButtonStyle())
                
                Button("genarate api key") {
                    if !username.isEmpty && !password.isEmpty {
                        onSubmit()
                        isPresented = false
                    }
                }
                .padding()
                .buttonStyle(DefaultButtonStyle())
                .disabled(username.isEmpty || password.isEmpty)
            }
        }
        .padding()
        .frame(width: 800, height: 400)
        .background(Color.black)
        .cornerRadius(12)
        .shadow(radius: 10)
    }
}
