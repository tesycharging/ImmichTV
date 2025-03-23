//
//  SettingView.swift
//  ImmichTV
//
//  Created by David Lüthi on 18.03.2025.
//

import SwiftUI

struct SettingView: View {
    var immichService: ImmichService
    @State var baseURL = ""
    @State var apikey = "" //mpFsRtifpNr8voop2uKKoMv4a1rPNwtw5lvzxuTGbY
    @State var slideShowOfThumbnails = false
    @State private var timeinterval = "5"
    @State var storage: Storage?
    @Environment(\.dismiss) private var dismiss // For dismissing the full-screen view
    
    var body: some View {
        VStack {
            TextField("http://immich-server:2283", text: $baseURL)
                .textFieldStyle(PlainTextFieldStyle())
                .padding()
                .frame(width: UIScreen.main.bounds.width - 20)
                .onAppear {
                    baseURL = UserDefaults.standard.string(forKey: "baseURL") ?? "https://demo.immich.app:2283"
                    apikey = UserDefaults.standard.string(forKey: "apikey") ?? ""
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
            SecureField("API key", text: $apikey)
                .autocapitalization(.none)
                .disableAutocorrection(true)
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

