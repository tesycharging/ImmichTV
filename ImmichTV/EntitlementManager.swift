//
//  EntitlementManager.swift
//  ImmichTV
//
//  Created by David Lüthi on 09.04.2025.
//

import Foundation
import SwiftUI

class EntitlementManager: ObservableObject {
    @AppStorage("processCompletedCount", store: UserDefaults.group)
    var processCompletedCount = 0
    
    @AppStorage("lastVersionPromptedForReview", store: UserDefaults.group)
    var lastVersionPromptedForReview: String?

    var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: kCFBundleVersionKey as String) as? String ?? "1.0"
    }
    
    // Dynamically retrieve App Store ID from Info.plist
    var appStoreID: String? {
        Bundle.main.infoDictionary?["CFBundleAppStoreID"] as? String
    }

    // Construct review URL dynamically
    var reviewURL: String {
        return "https://apps.apple.com/app/6743646520?action=write-review"
        //guard let appStoreID = appStoreID else { return nil }
        //return URL(string: "https://apps.apple.com/app/\(appStoreID)?action=write-review")
    }

    @AppStorage("baseURL", store: UserDefaults.group)
    var baseURL = "" // Replace with your Immich server URL
    
    @AppStorage("apiKey", store: UserDefaults.group)
    var apiKey = "" // Replace with your Immich API key
    
    @AppStorage("slideShowOfThumbnails", store: UserDefaults.group)
    var slideShowOfThumbnails = false
    
    @AppStorage("playVideo", store: UserDefaults.group)
    var playVideo = false
    
    @AppStorage("groupByDay", store: UserDefaults.group)
    var groupByDay = false
    
    @AppStorage("timeinterval", store: UserDefaults.group)
    var timeinterval = 5.0
    
    var demo: Bool {
        (baseURL == "http://tesycharging.ch" || baseURL == "https://tesycharging.ch") && apiKey == "demo"
    }
    
    var musicOptions: Dictionary<String, String> {
        get {
            return UserDefaults.group.loadOptions() ??
            ["Song-1": "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3",
             "Song-2": "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3",
             "Song-3": "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3",
             "Song-4": "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-4.mp3",
             "Song-5": "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-5.mp3",
             "no sound": ""]
        }
        set {
            UserDefaults.group.saveOptions(newValue)
        }
    }
    
    @AppStorage("selectedMusic", store: UserDefaults.group)
    var selectedMusic = ""
    
    var musicURL: URL? {
        let value = musicOptions[selectedMusic] ?? ""
        if URL(string: value)?.scheme?.lowercased() == nil {
            let fileManager = FileManager.default
            let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            return documentsDirectory.appendingPathComponent(musicOptions[selectedMusic] ?? "")
        } else {
            return URL(string: value)
        }
    }
    
    var notConfigured: Bool {
        baseURL == "" || apiKey == ""
    }
}

// UserDefaults extension for convenience
extension UserDefaults {
    static let group = UserDefaults(suiteName: "group.com.ImmichTV")!
    
    // Save the array to UserDefaults
    func saveOptions(_ musicOptions: Dictionary<String, String>) {
        do {
            let data = try JSONEncoder().encode(musicOptions)
            set(data, forKey: "musicOptions")
        } catch {
            print("Failed to encode options: \(error)")
        }
    }
    
    // Load the array from UserDefaults
    func loadOptions() -> Dictionary<String, String>? {
        guard let data = data(forKey: "musicOptions") else { return nil }
        do {
            var options = try JSONDecoder().decode(Dictionary<String, String>.self, from: data)
            let fileManager = FileManager.default
            let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            for (key, value) in options {
                if URL(string: value)?.scheme?.lowercased() == nil {
                    let url = documentsDirectory.appendingPathComponent(value)
                    do {
                        // Check if the file doesn't exist
                        if !fileManager.fileExists(atPath: url.path) {
                            options.removeValue(forKey: key)
                        }
                    }
                }
            }
            return options
        } catch {
            print("Failed to decode options: \(error)")
            return nil
        }
    }
}
