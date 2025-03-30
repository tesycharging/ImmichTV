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
    var playVideo = false
    var timeinterval = 5.0
    var demo = false
    
    init() {
        loadSettings()
    }
    
    func loadSettings() {
        baseURL = (UserDefaults.standard.string(forKey: "baseURL") ?? "http://immich-server:2283") + "/api"
        apiKey = UserDefaults.standard.string(forKey: "apikey") ?? ""
        slideShowOfThumbnails = UserDefaults.standard.bool(forKey: "slideShowOfThumbnails")
        playVideo = UserDefaults.standard.bool(forKey: "playVideo")
        demo = (baseURL == "http://tesycharging.ch/api" || baseURL == "https://tesycharging.ch/api") && apiKey == "demo"
        timeinterval = UserDefaults.standard.double(forKey: "timeinterval")
        if timeinterval < 3 {
            timeinterval = 5
        }
    }

    func fetchAlbums() async throws -> Bool {
        if demo {
            self.albumsByYear = ["2015": [Album(albumName: "Beaches", description: "", albumThumbnailAssetId: "1_thumb.jpg", id: "1", startDate: "2009-08-08T10:14:13.000Z", endDate: "2015-08-06T17:46:11.000Z")], "2017":[Album(albumName: "Cars", description: "", albumThumbnailAssetId: "11_thumb.jpg", id: "2", startDate: "2011-02-14T14:09:47.230Z", endDate: "2017-05-02T11:08:34.740Z")]]
            return true
        } else {
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
    }
    
    @MainActor
    func fetchAssets(for albumId: String) async throws -> [AssetItem] {
        if demo {
            if albumId == "1" {
                return [AssetItem(id: "1.jpg", deviceAssetId: "web-Carrelet,_Esnandes,_Charente-Maritime,_august_2015.jpg-1673438566000", ownerId: "5b48c453-d55f-4cc2-a585-ce406ea8e3d6", deviceId: "WEB", type: .image, originalPath: "upload/library/5b48c453-d55f-4cc2-a585-ce406ea8e3d6/2015/2015-08-06/Carrelet,_Esnandes,_Charente-Maritime,_august_2015.jpg", originalFileName: "Carrelet,_Esnandes,_Charente-Maritime,_august_2015.jpg", originalMimeType: "image/jpeg", isFavorite: false, exifInfo: nil),
                        AssetItem(id: "2.jpg", deviceAssetId: "web-Fishing_boats,_morning,_Beach,_Rincon_de_la_Victoria,_Andalusia,_Spain.jpg-1673438646000", ownerId: "5b48c453-d55f-4cc2-a585-ce406ea8e3d6", deviceId: "WEB", type: .image, originalPath: "upload/library/5b48c453-d55f-4cc2-a585-ce406ea8e3d6/2014/2014-08-01/Fishing_boats,_morning,_Beach,_Rincon_de_la_Victoria,_Andalusia,_Spain.jpg", originalFileName: "Fishing_boats,_morning,_Beach,_Rincon_de_la_Victoria,_Andalusia,_Spain.jpg", originalMimeType: "image/jpeg", isFavorite: false, exifInfo: nil),
                        AssetItem(id: "3.jpg", deviceAssetId: "web-Donax_striatus_Linnaeus,_1767_in_Margarita_Island_2.jpg-1673438622000", ownerId: "5b48c453-d55f-4cc2-a585-ce406ea8e3d6", deviceId: "WEB", type: .image, originalPath: "upload/library/5b48c453-d55f-4cc2-a585-ce406ea8e3d6/2013/2013-05-20/Donax_striatus_Linnaeus,_1767_in_Margarita_Island_2.jpg", originalFileName: "Donax_striatus_Linnaeus,_1767_in_Margarita_Island_2.jpg", originalMimeType: "image/jpeg", isFavorite: false, exifInfo: nil),
                        AssetItem(id: "4.jpg", deviceAssetId: "web-La_Restinga_Beach_3.jpg-1673438706000", ownerId: "5b48c453-d55f-4cc2-a585-ce406ea8e3d6", deviceId: "WEB", type: .image, originalPath: "upload/library/5b48c453-d55f-4cc2-a585-ce406ea8e3d6/2013/2013-01-06/La_Restinga_Beach_3.jpg", originalFileName: "La_Restinga_Beach_3.jpg", originalMimeType: "image/jpeg", isFavorite: false, exifInfo: nil),
                        AssetItem(id: "5.jpg", deviceAssetId: "web-Panoramic_view_of_San_Carlos_Island,_Zulia_State.jpg-1673438804000", ownerId: "5b48c453-d55f-4cc2-a585-ce406ea8e3d6", deviceId: "WEB", type: .image, originalPath: "upload/library/5b48c453-d55f-4cc2-a585-ce406ea8e3d6/2012/2012-10-12/Panoramic_view_of_San_Carlos_Island,_Zulia_State.jpg", originalFileName: "Panoramic_view_of_San_Carlos_Island,_Zulia_State.jpg", originalMimeType: "image/jpeg", isFavorite: false, exifInfo: nil),
                        AssetItem(id: "6.jpg", deviceAssetId: "web-Strandkörbe_in_Kühlungsborn-3-.jpg-1673438900000", ownerId: "5b48c453-d55f-4cc2-a585-ce406ea8e3d6", deviceId: "WEB", type: .image, originalPath: "upload/library/5b48c453-d55f-4cc2-a585-ce406ea8e3d6/2012/2012-06-08/Strandkörbe_in_Kühlungsborn-3-.jpg", originalFileName: "Strandkörbe_in_Kühlungsborn-3-.jpg", originalMimeType: "image/jpeg", isFavorite: false, exifInfo: nil),
                        AssetItem(id: "7.jpg", deviceAssetId: "web-Eublepharis_macularius_2009_G7.jpg-1673438640000", ownerId: "5b48c453-d55f-4cc2-a585-ce406ea8e3d6", deviceId: "WEB", type: .image, originalPath: "upload/library/5b48c453-d55f-4cc2-a585-ce406ea8e3d6/2009/2009-08-09/Eublepharis_macularius_2009_G7.jpg", originalFileName: "Eublepharis_macularius_2009_G7.jpg", originalMimeType: "image/jpeg", isFavorite: false, exifInfo: nil),
                        AssetItem(id: "8.jpg", deviceAssetId: "web-Pogona_vitticeps_2009_G4.jpg-1673438828000", ownerId: "5b48c453-d55f-4cc2-a585-ce406ea8e3d6", deviceId: "WEB", type: .image, originalPath: "upload/library/5b48c453-d55f-4cc2-a585-ce406ea8e3d6/2009/2009-08-08/Pogona_vitticeps_2009_G4.jpg", originalFileName: "Pogona_vitticeps_2009_G4.jpg", originalMimeType: "image/jpeg", isFavorite: false, exifInfo: nil),
                        AssetItem(id: "9.jpg", deviceAssetId: "web-Brachypelma_klaasi_2009_G12.jpg-1673438550000", ownerId: "5b48c453-d55f-4cc2-a585-ce406ea8e3d6", deviceId: "WEB", type: .image, originalPath: "upload/library/5b48c453-d55f-4cc2-a585-ce406ea8e3d6/2009/2009-08-08/Brachypelma_klaasi_2009_G12.jpg", originalFileName: "Brachypelma_klaasi_2009_G12.jpg", originalMimeType: "image/jpeg", isFavorite: false, exifInfo: nil)]
            } else {
                return [AssetItem(id: "11.jpg", deviceAssetId: "web-Telega_in_Sosonka_2017_G1.jpg-1673438906000", ownerId: "5b48c453-d55f-4cc2-a585-ce406ea8e3d6", deviceId: "WEB", type: .image, originalPath: "upload/library/5b48c453-d55f-4cc2-a585-ce406ea8e3d6/2017/2017-05-02/Telega_in_Sosonka_2017_G1.jpg", originalFileName: "Telega_in_Sosonka_2017_G1.jpg", originalMimeType: "image/jpeg", isFavorite: false, exifInfo: nil),
                        AssetItem(id: "12.jpg", deviceAssetId: "web-Chevrolet_Master_Special_Eagle_1933_-_Z16725_-_front.jpg-1673438582000", ownerId: "5b48c453-d55f-4cc2-a585-ce406ea8e3d6", deviceId: "WEB", type: .image, originalPath: "upload/library/5b48c453-d55f-4cc2-a585-ce406ea8e3d6/2017/2017-04-21/Chevrolet_Master_Special_Eagle_1933_-_Z16725_-_front.jpg", originalFileName: "Chevrolet_Master_Special_Eagle_1933_-_Z16725_-_front.jpg", originalMimeType: "image/jpeg", isFavorite: false, exifInfo: nil),
                        AssetItem(id: "13.jpg", deviceAssetId: "web-Calle_en_centro_de_Maracaibo.jpg-1673438560000", ownerId: "5b48c453-d55f-4cc2-a585-ce406ea8e3d6", deviceId: "WEB", type: .image, originalPath: "upload/library/5b48c453-d55f-4cc2-a585-ce406ea8e3d6/2013/2013-02-23/Calle_en_centro_de_Maracaibo.jpg", originalFileName: "Calle_en_centro_de_Maracaibo.jpg", originalMimeType: "image/jpeg", isFavorite: false, exifInfo: nil),
                        AssetItem(id: "14.jpg", deviceAssetId: "web-Police_car_Vienna_Volkswagen_Touran.jpg-1673438830000", ownerId: "5b48c453-d55f-4cc2-a585-ce406ea8e3d6", deviceId: "WEB", type: .image, originalPath: "upload/library/5b48c453-d55f-4cc2-a585-ce406ea8e3d6/2012/2012-02-20/Police_car_Vienna_Volkswagen_Touran.jpg", originalFileName: "Police_car_Vienna_Volkswagen_Touran.jpg", originalMimeType: "image/jpeg", isFavorite: false, exifInfo: nil),
                        AssetItem(id: "15.jpg", deviceAssetId: "web-S-3D_cycle-car_2011_G1.jpg-1673438864000", ownerId: "5b48c453-d55f-4cc2-a585-ce406ea8e3d6", deviceId: "WEB", type: .image, originalPath: "upload/library/5b48c453-d55f-4cc2-a585-ce406ea8e3d6/2011/2011-02-14/S-3D_cycle-car_2011_G1.jpg", originalFileName: "S-3D_cycle-car_2011_G1.jpg", originalMimeType: "image/jpeg", isFavorite: false, exifInfo: nil)]
            }
        } else {
            guard let url = URL(string: "\(baseURL)/albums/\(albumId)?apiKey=\(apiKey)") else {
                return []
            }
            let (data, _) = try await URLSession.shared.data(from: url)
            // Assuming the API returns an array of asset objects with id and path
            let asset = try JSONDecoder().decode(Asset.self, from: data)
            return asset.assets//.filter{ $0.type == .image}
        }
    }
    
    func getImageUrl(id: String, thumbnail: Bool = true, video: Bool = false) -> URL? {
        if demo {
            return URL(string: "\(baseURL)/assets/\(id)")
        } else {
            if thumbnail || video {
                return URL(string: "\(baseURL)/assets/\(id)/thumbnail/?apiKey=\(apiKey)")
            } else {
                return URL(string: "\(baseURL)/assets/\(id)/original/?apiKey=\(apiKey)")
            }
        }
    }
    
    func getVideoUrl(id: String) -> URL? {
        return URL(string: "\(baseURL)/assets/\(id)/video/playback/?apiKey=\(apiKey)")
    }
    
    func searchSmartAssets(query: String, page: Int? = nil) async throws -> ([AssetItem], Int?) {
        if demo {
            return ([AssetItem(id: "1.jpg", deviceAssetId: "web-Brachypelma_klaasi_2009_G12.jpg-1673438550000", ownerId: "5b48c453-d55f-4cc2-a585-ce406ea8e3d6", deviceId: "WEB", type: .image, originalPath: "upload/library/5b48c453-d55f-4cc2-a585-ce406ea8e3d6/2009/2009-08-08/Brachypelma_klaasi_2009_G12.jpg", originalFileName: "Brachypelma_klaasi_2009_G12.jpg", originalMimeType: "image/jpeg", isFavorite: false, exifInfo: nil),
                     AssetItem(id: "2.jpg", deviceAssetId: "web-Pogona_vitticeps_2009_G4.jpg-1673438828000", ownerId: "5b48c453-d55f-4cc2-a585-ce406ea8e3d6", deviceId: "WEB", type: .image, originalPath: "upload/library/5b48c453-d55f-4cc2-a585-ce406ea8e3d6/2009/2009-08-08/Pogona_vitticeps_2009_G4.jpg", originalFileName: "Pogona_vitticeps_2009_G4.jpg", originalMimeType: "image/jpeg", isFavorite: false, exifInfo: nil),
                     AssetItem(id: "3.jpg", deviceAssetId: "web-Police_car_Vienna_Volkswagen_Touran.jpg-1673438830000", ownerId: "5b48c453-d55f-4cc2-a585-ce406ea8e3d6", deviceId: "WEB", type: .image, originalPath: "upload/library/5b48c453-d55f-4cc2-a585-ce406ea8e3d6/2012/2012-02-20/Police_car_Vienna_Volkswagen_Touran.jpg", originalFileName: "Police_car_Vienna_Volkswagen_Touran.jpg", originalMimeType: "image/jpeg", isFavorite: false, exifInfo: nil),
                     AssetItem(id: "4.jpg", deviceAssetId: "web-Eublepharis_macularius_2009_G7.jpg-1673438640000", ownerId: "5b48c453-d55f-4cc2-a585-ce406ea8e3d6", deviceId: "WEB", type: .image, originalPath: "upload/library/5b48c453-d55f-4cc2-a585-ce406ea8e3d6/2009/2009-08-09/Eublepharis_macularius_2009_G7.jpg", originalFileName: "Eublepharis_macularius_2009_G7.jpg", originalMimeType: "image/jpeg", isFavorite: false, exifInfo: nil),
                     AssetItem(id: "5.jpg", deviceAssetId: "web-Donax_striatus_Linnaeus,_1767_in_Margarita_Island_2.jpg-1673438622000", ownerId: "5b48c453-d55f-4cc2-a585-ce406ea8e3d6", deviceId: "WEB", type: .image, originalPath: "upload/library/5b48c453-d55f-4cc2-a585-ce406ea8e3d6/2013/2013-05-20/Donax_striatus_Linnaeus,_1767_in_Margarita_Island_2.jpg", originalFileName: "Donax_striatus_Linnaeus,_1767_in_Margarita_Island_2.jpg", originalMimeType: "image/jpeg", isFavorite: false, exifInfo: nil),
                     AssetItem(id: "6.jpg", deviceAssetId: "web-Telega_in_Sosonka_2017_G1.jpg-1673438906000", ownerId: "5b48c453-d55f-4cc2-a585-ce406ea8e3d6", deviceId: "WEB", type: .image, originalPath: "upload/library/5b48c453-d55f-4cc2-a585-ce406ea8e3d6/2017/2017-05-02/Telega_in_Sosonka_2017_G1.jpg", originalFileName: "Telega_in_Sosonka_2017_G1.jpg", originalMimeType: "image/jpeg", isFavorite: false, exifInfo: nil),
                     AssetItem(id: "7.jpg", deviceAssetId: "web-S-3D_cycle-car_2011_G1.jpg-1673438864000", ownerId: "5b48c453-d55f-4cc2-a585-ce406ea8e3d6", deviceId: "WEB", type: .image, originalPath: "upload/library/5b48c453-d55f-4cc2-a585-ce406ea8e3d6/2011/2011-02-14/S-3D_cycle-car_2011_G1.jpg", originalFileName: "S-3D_cycle-car_2011_G1.jpg", originalMimeType: "image/jpeg", isFavorite: false, exifInfo: nil),
                     AssetItem(id: "8.jpg", deviceAssetId: "web-Panoramic_view_of_San_Carlos_Island,_Zulia_State.jpg-1673438804000", ownerId: "5b48c453-d55f-4cc2-a585-ce406ea8e3d6", deviceId: "WEB", type: .image, originalPath: "upload/library/5b48c453-d55f-4cc2-a585-ce406ea8e3d6/2012/2012-10-12/Panoramic_view_of_San_Carlos_Island,_Zulia_State.jpg", originalFileName: "Panoramic_view_of_San_Carlos_Island,_Zulia_State.jpg", originalMimeType: "image/jpeg", isFavorite: false, exifInfo: nil),
                     AssetItem(id: "9.jpg", deviceAssetId: "web-Chevrolet_Master_Special_Eagle_1933_-_Z16725_-_front.jpg-1673438582000", ownerId: "5b48c453-d55f-4cc2-a585-ce406ea8e3d6", deviceId: "WEB", type: .image, originalPath: "upload/library/5b48c453-d55f-4cc2-a585-ce406ea8e3d6/2017/2017-04-21/Chevrolet_Master_Special_Eagle_1933_-_Z16725_-_front.jpg", originalFileName: "Chevrolet_Master_Special_Eagle_1933_-_Z16725_-_front.jpg", originalMimeType: "image/jpeg", isFavorite: false, exifInfo: nil),
                     AssetItem(id: "11.jpg", deviceAssetId: "web-Calle_en_centro_de_Maracaibo.jpg-1673438560000", ownerId: "5b48c453-d55f-4cc2-a585-ce406ea8e3d6", deviceId: "WEB", type: .image, originalPath: "upload/library/5b48c453-d55f-4cc2-a585-ce406ea8e3d6/2013/2013-02-23/Calle_en_centro_de_Maracaibo.jpg", originalFileName: "Calle_en_centro_de_Maracaibo.jpg", originalMimeType: "image/jpeg", isFavorite: false, exifInfo: nil),
                     AssetItem(id: "12.jpg", deviceAssetId: "web-Fishing_boats,_morning,_Beach,_Rincon_de_la_Victoria,_Andalusia,_Spain.jpg-1673438646000", ownerId: "5b48c453-d55f-4cc2-a585-ce406ea8e3d6", deviceId: "WEB", type: .image, originalPath: "upload/library/5b48c453-d55f-4cc2-a585-ce406ea8e3d6/2014/2014-08-01/Fishing_boats,_morning,_Beach,_Rincon_de_la_Victoria,_Andalusia,_Spain.jpg", originalFileName: "Fishing_boats,_morning,_Beach,_Rincon_de_la_Victoria,_Andalusia,_Spain.jpg", originalMimeType: "image/jpeg", isFavorite: false, exifInfo: nil),
                     AssetItem(id: "13.jpg", deviceAssetId: "web-Carrelet,_Esnandes,_Charente-Maritime,_august_2015.jpg-1673438566000", ownerId: "5b48c453-d55f-4cc2-a585-ce406ea8e3d6", deviceId: "WEB", type: .image, originalPath: "upload/library/5b48c453-d55f-4cc2-a585-ce406ea8e3d6/2015/2015-08-06/Carrelet,_Esnandes,_Charente-Maritime,_august_2015.jpg", originalFileName: "Carrelet,_Esnandes,_Charente-Maritime,_august_2015.jpg", originalMimeType: "image/jpeg", isFavorite: false, exifInfo: nil),
                     AssetItem(id: "14.jpg", deviceAssetId: "web-Strandkörbe_in_Kühlungsborn-3-.jpg-1673438900000", ownerId: "5b48c453-d55f-4cc2-a585-ce406ea8e3d6", deviceId: "WEB", type: .image, originalPath: "upload/library/5b48c453-d55f-4cc2-a585-ce406ea8e3d6/2012/2012-06-08/Strandkörbe_in_Kühlungsborn-3-.jpg", originalFileName: "Strandkörbe_in_Kühlungsborn-3-.jpg", originalMimeType: "image/jpeg", isFavorite: false, exifInfo: nil),
                     AssetItem(id: "15.jpg", deviceAssetId: "web-La_Restinga_Beach_3.jpg-1673438706000", ownerId: "5b48c453-d55f-4cc2-a585-ce406ea8e3d6", deviceId: "WEB", type: .image, originalPath: "upload/library/5b48c453-d55f-4cc2-a585-ce406ea8e3d6/2013/2013-01-06/La_Restinga_Beach_3.jpg", originalFileName: "La_Restinga_Beach_3.jpg", originalMimeType: "image/jpeg", isFavorite: false, exifInfo: nil)], nil)
        } else {
            let url = URL(string: "\(baseURL)/search/smart")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let body: [String: Any] = [
                "query": query,
                "page": page ?? 1
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
            let nextPage: Int? = Int(response.assets.nextPage ?? "")
            return (response.assets.items, nextPage) //.filter{ $0.type == .image
        }
    }
    
    func searchAssets(isFavorite: Bool? = nil, page: Int? = nil) async throws -> ([AssetItem], Int?) {
        let url = URL(string: "\(baseURL)/search/metadata")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = isFavorite != nil ? [
            "isFavorite": isFavorite!,
            "page": page ?? 1
        ] :  [
            "page": page ?? 1
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let response = try decoder.decode(SearchResponse.self, from: data)
        let nextPage: Int? = Int(response.assets.nextPage ?? "")
        return (response.assets.items, nextPage) //.filter{ $0.type == .image}
    }
    
    @MainActor
    func getMyUser() async throws -> String {
        if demo {
            return "demo"
        } else {
            guard let url = URL(string: "\(baseURL)/users/me?apiKey=\(apiKey)") else {
                return "-"
            }
            let (data, _) = try await URLSession.shared.data(from: url)
            // Assuming the API returns an array of asset objects with id and path
            let user = try JSONDecoder().decode(User.self, from: data)
            return user.name
        }
    }
    
    @MainActor
    func getStorage() async throws -> Storage{
        if demo {
            return Storage(diskAvailable: "10.0 TiB", diskAvailableRaw: 10993775525888, diskSize: "10.5 TiB", diskSizeRaw: 11490240110592, diskUsagePercentage: 4.32, diskUse: "462.4 GiB", diskUseRaw: 496464584704)
        } else {
            guard let url = URL(string: "\(baseURL)/server/storage?apiKey=\(apiKey)") else {
                throw NSError(domain: "url doesn't work", code: 100)
            }
            let (data, _) = try await URLSession.shared.data(from: url)
            return try JSONDecoder().decode(Storage.self, from: data)
        }
    }
    
    func updateAssets(id: String, favorite: Bool) async throws -> AssetItem {
        guard let url = URL(string: "\(baseURL)/assets/\(id)") else {
            throw NSError(domain: "url doesn't work", code: 100)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let body: [String: Any] = [
            "isFavorite": favorite
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, _) = try await URLSession.shared.data(for: request)
        let assetItem = try JSONDecoder().decode(AssetItem.self, from: data)
        return assetItem
    }
}

extension ImmichService {
    // Login function
    private func login(baseURL: String, email: String, password: String) async throws -> String {
        guard let url = URL(string: "\(baseURL)/auth/login") else {
            throw NSError(domain: "url doesn't work", code: 100)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "email": email,
            "password": password
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let loginResponse = try JSONDecoder().decode(LoginResponse.self, from: data)
        return loginResponse.accessToken
    }
    
    // Create API key function
    @MainActor
    func createAPIKey(baseURL: String, email: String, password: String) async throws -> String {
        if email == "demo" && password == "demo" {
            return "demo"
        } else {
            let accessToken = try await login(baseURL: baseURL, email: email, password: password)
            guard let url = URL(string: "\(baseURL)/api-keys") else {
                throw NSError(domain: "url doesn't work", code: 100)
            }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            
            let body: [String: Any] = [
                "name": "ImmichTV Generated Key",
                "permissions": ["all"]
            ]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            
            let (data, _) = try await URLSession.shared.data(for: request)
            let apiKeyResponse = try JSONDecoder().decode(APIRequestResponse.self, from: data)
            return apiKeyResponse.apiKey.id
        }
    }
}
