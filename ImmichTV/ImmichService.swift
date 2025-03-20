//
//  ImmichService.swift
//  ImmichTV
//
//  Created by David Lüthi on 17.03.2025.
//

import Foundation

class ImmichService: ObservableObject {
    @Published var albumsByYear: [String: [Album]] = [:]
    var baseURL = "" // Replace with your Immich server URL
    var apiKey = "" // Replace with your Immich API key
    var slideShowOfThumbnails = false
    
    init() {
        loadSettings()
    }
    
    func loadSettings() {
        baseURL = (UserDefaults.standard.string(forKey: "baseURL") ?? "http://immich-server:2283") + "/api"
        apiKey = UserDefaults.standard.string(forKey: "apikey") ?? ""
        slideShowOfThumbnails = UserDefaults.standard.bool(forKey: "slideShowOfThumbnails")
    }

    func fetchAlbums() async throws -> Bool {
        guard let url = URL(string: "\(baseURL)/albums?apiKey=\(apiKey)") else {
            throw NSError(domain: "url doesn't work", code: 100)
        }
        let (data, _) = try await URLSession.shared.data(from: url)
        if data.count == 2 {
            throw NSError(domain: "no albums found", code: 100)
        }
        let albums = try JSONDecoder().decode([Album].self, from: data).sorted { item1, item2 in
            guard let date1 = Int(item1.endDate.replacingOccurrences(of: "-", with: "").prefix(8)),
                  let date2 = Int(item2.endDate.replacingOccurrences(of: "-", with: "").prefix(8)) else {
                return false // Fallback if parsing fails
            }
            return date1 > date2 // Ascending order
        }
        await MainActor.run {
            self.albumsByYear = Dictionary(grouping: albums, by: { String($0.endDate.prefix(4)) })
        }
        return !albums.isEmpty
    }
    
    @MainActor
    func fetchAssets(for albumId: String) async throws -> [AssetItem] {
        guard let url = URL(string: "\(baseURL)/albums/\(albumId)?apiKey=\(apiKey)") else {
            return []
        }
        let (data, _) = try await URLSession.shared.data(from: url)
        // Assuming the API returns an array of asset objects with id and path
        let asset = try JSONDecoder().decode(Asset.self, from: data)
        return asset.assets//.filter{ $0.type == .image}
    }
    
    func getImageUrl(id: String, thumbnail: Bool = true, video: Bool = false) -> URL? {
        if !thumbnail {
            return URL(string: "\(baseURL)/assets/\(id)/\(video ? "video/playback" : "original")/?apiKey=\(apiKey)")
        } else {
            return URL(string: "\(baseURL)/assets/\(id)/thumbnail/?apiKey=\(apiKey)")
        }
    }
    
    func searchAssets(query: String) async throws -> [AssetItem] {
        let url = URL(string: "\(baseURL)/search/smart")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "query": query,
            "page": 1
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)
        /*// Convert bytes to readable string
        if let utf8String = String(data: data, encoding: .utf8) {
            print("Received UTF-8 String (\(data.count) bytes): \(utf8String)")
        } else {
            print("Failed to convert bytes to UTF-8 string")
        }*/
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let response = try decoder.decode(SearchResponse.self, from: data)
        return response.assets.items//.filter{ $0.type == .image}
    }
    
    @MainActor
    func getMyUser() async throws -> String {
        guard let url = URL(string: "\(baseURL)/users/me?apiKey=\(apiKey)") else {
            return "-"
        }
        let (data, _) = try await URLSession.shared.data(from: url)
        // Assuming the API returns an array of asset objects with id and path
        let user = try JSONDecoder().decode(User.self, from: data)
        return user.name
    }
    
    @MainActor
    func getStorage() async throws -> Storage{
        guard let url = URL(string: "\(baseURL)/server/storage?apiKey=\(apiKey)") else {
            throw NSError(domain: "url doesn't work", code: 100)
        }
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(Storage.self, from: data)
    }
}
