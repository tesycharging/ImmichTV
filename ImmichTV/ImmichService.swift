//
//  ImmichService.swift
//  ImmichTV
//
//  Created by David Lüthi on 17.03.2025.
//

import Foundation
#if os(tvOS)
#else
import Photos
import UIKit
#endif

class ImmichService: ObservableObject {
    private var entitlementManager: EntitlementManager
    @Published var albumsGrouped: [Date: [Album]] = [:]
    @Published var assetItems: [AssetItem] = []
    @Published var assetItemsGrouped: [Date: [AssetItem]] = [:]
    @Published var user: User = User(name: "", email: "")
    @Published var state: ToggleState = .all
    
    init(entitlementManager: EntitlementManager) {
        self.entitlementManager = entitlementManager
    }
    
    private func groupAlbums(albums: [Album]) -> [Date: [Album]] {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let isoFormatter2 = ISO8601DateFormatter()
        isoFormatter2.formatOptions = [.withInternetDateTime]
        let grouped = Dictionary(grouping: albums) { item in
            guard let date = isoFormatter.date(from: item.endDate) else {
                guard let date2 = isoFormatter2.date(from: item.endDate) else {
                    print("Warning: Failed to parse date '\(item.endDate)', using current date")
                    //   return Calendar.current.date(from: Calendar.current.dateComponents([.year, .month, .day], from: Date()))!
                    return Calendar.current.startOfDay(for: Date())
                }
                
                return Calendar.current.date(from: Calendar.current.dateComponents([.year], from: date2))!
                //return Calendar.current.startOfDay(for: date2)
            }
            return Calendar.current.date(from: Calendar.current.dateComponents([.year], from: date))!
            //return Calendar.current.startOfDay(for: date)
        }
        return Dictionary(uniqueKeysWithValues: grouped.sorted { $0.key > $1.key })
    }
    
    private func getAllAlbums(shared: Bool) async throws -> [Album] {
        guard let url = URL(string: "\(entitlementManager.baseURL)/api/albums?apiKey=\(entitlementManager.apiKey)&shared=\(shared)") else {
            throw NSError(domain: "url doesn't work", code: 100)
        }
        let (data, _) = try await URLSession.shared.data(from: url)
        if data.count == 2 {
            return []
        } else {
            return try decoder(data)
        }
    }
    
    @MainActor
    func fetchAlbums() async throws {
        if entitlementManager.demo {
            if state == .shared {
                albumsGrouped = [:]
            } else {
                try? await Task.sleep(nanoseconds: UInt64(2 * 1000000000)) // Convert seconds to nanoseconds
                albumsGrouped = groupAlbums(albums: [Album(albumName: "Beaches", description: "", albumThumbnailAssetId: "1_thumb.jpg", albumUsers: [], id: "1", startDate: "2009-08-08T10:14:13.000Z", endDate: "2015-08-06T17:46:11.000Z"), Album(albumName: "Cars", description: "", albumThumbnailAssetId: "11_thumb.jpg", albumUsers: [], id: "2", startDate: "2011-02-14T14:09:47.230Z", endDate: "2017-05-02T11:08:34.740Z")])
            }
        } else {
            var albums:[Album] = []
            var albumsShared:[Album] = []
            if state == .shared {
                albumsShared = try await getAllAlbums(shared: true)
            } else {
                albums = try await getAllAlbums(shared: false)
                albumsShared = try await getAllAlbums(shared: true)
            }
            if albums.isEmpty && albumsShared.isEmpty {
                throw NSError(domain: "no albums found", code: 100)
            }
            var resultAlbums: [Album] = []
            switch state {
            case .all:
                resultAlbums = [albums, albumsShared].flatMap { $0 }
            case .owned:
                let mergedAlbums = [albums, albumsShared].flatMap { $0 }
                resultAlbums = mergedAlbums.filter{ !$0.albumUsers.contains(where: { $0.user == user })}
            case .shared:
                resultAlbums = albumsShared.filter{ $0.albumUsers.contains(where: { $0.user == user })}
            }
            albumsGrouped = groupAlbums(albums: resultAlbums)
        }
    }
    
    public func groupAssets(assetItems: [AssetItem], ascending: Bool) -> [Date: [AssetItem]] {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let isoFormatter2 = ISO8601DateFormatter()
        isoFormatter2.formatOptions = [.withInternetDateTime]
        let grouped = Dictionary(grouping: assetItems) { item in
            guard let date = isoFormatter.date(from: item.localDateTime) else {
                guard let date2 = isoFormatter2.date(from: item.localDateTime) else {
                    print("Warning: Failed to parse date '\(item.localDateTime)', using current date")
                    //   return Calendar.current.date(from: Calendar.current.dateComponents([.year, .month, .day], from: Date()))!
                    return Calendar.current.startOfDay(for: Date())
                }
                
                //return Calendar.current.date(from: Calendar.current.dateComponents([.year, .month, .day], from: date2))!
                return Calendar.current.startOfDay(for: date2)
            }
            //return Calendar.current.date(from: Calendar.current.dateComponents([.year, .month, .day], from: date))!
            return Calendar.current.startOfDay(for: date)
        }
        if ascending {
            return Dictionary(uniqueKeysWithValues: grouped.sorted { $0.key < $1.key }) // reversaed (earliest to latest
        } else {
            return Dictionary(uniqueKeysWithValues: grouped.sorted { $0.key > $1.key })
        }
    }
    
    func sortedGroupAssets(ascending: Bool) -> [Date] {
        assetItemsGrouped.keys.sorted { ascending ? $0 < $1 : $0 > $1 }
    }
    
    @MainActor
    func fetchAssets(albumId: String, ascending: Bool = false) async throws {
        if entitlementManager.demo {
            try? await Task.sleep(nanoseconds: UInt64(2 * 1000000000)) // Convert seconds to nanoseconds
            if albumId == "1" {
                assetItems = [AssetItem(id: "1.jpg", deviceAssetId: "web-Carrelet,_Esnandes,_Charente-Maritime,_august_2015.jpg-1673438566000", ownerId: "5b48c453-d55f-4cc2-a585-ce406ea8e3d6", deviceId: "WEB", type: .image, originalPath: "upload/library/5b48c453-d55f-4cc2-a585-ce406ea8e3d6/2015/2015-08-06/Carrelet,_Esnandes,_Charente-Maritime,_august_2015.jpg", originalFileName: "Carrelet,_Esnandes,_Charente-Maritime,_august_2015.jpg", originalMimeType: "image/jpeg", isFavorite: false, exifInfo: nil, localDateTime: "2015-08-06T17:46:11.000Z"),
                        AssetItem(id: "2.jpg", deviceAssetId: "web-Fishing_boats,_morning,_Beach,_Rincon_de_la_Victoria,_Andalusia,_Spain.jpg-1673438646000", ownerId: "5b48c453-d55f-4cc2-a585-ce406ea8e3d6", deviceId: "WEB", type: .image, originalPath: "upload/library/5b48c453-d55f-4cc2-a585-ce406ea8e3d6/2014/2014-08-01/Fishing_boats,_morning,_Beach,_Rincon_de_la_Victoria,_Andalusia,_Spain.jpg", originalFileName: "Fishing_boats,_morning,_Beach,_Rincon_de_la_Victoria,_Andalusia,_Spain.jpg", originalMimeType: "image/jpeg", isFavorite: false, exifInfo: nil, localDateTime: "2014-08-06T17:46:11.000Z"),
                        AssetItem(id: "3.jpg", deviceAssetId: "web-Donax_striatus_Linnaeus,_1767_in_Margarita_Island_2.jpg-1673438622000", ownerId: "5b48c453-d55f-4cc2-a585-ce406ea8e3d6", deviceId: "WEB", type: .image, originalPath: "upload/library/5b48c453-d55f-4cc2-a585-ce406ea8e3d6/2013/2013-05-20/Donax_striatus_Linnaeus,_1767_in_Margarita_Island_2.jpg", originalFileName: "Donax_striatus_Linnaeus,_1767_in_Margarita_Island_2.jpg", originalMimeType: "image/jpeg", isFavorite: false, exifInfo: nil, localDateTime: "2014-08-06T17:46:11.000Z"),
                        AssetItem(id: "4.jpg", deviceAssetId: "web-La_Restinga_Beach_3.jpg-1673438706000", ownerId: "5b48c453-d55f-4cc2-a585-ce406ea8e3d6", deviceId: "WEB", type: .image, originalPath: "upload/library/5b48c453-d55f-4cc2-a585-ce406ea8e3d6/2013/2013-01-06/La_Restinga_Beach_3.jpg", originalFileName: "La_Restinga_Beach_3.jpg", originalMimeType: "image/jpeg", isFavorite: false, exifInfo: nil, localDateTime: "2014-08-06T17:46:11.000Z"),
                        AssetItem(id: "5.jpg", deviceAssetId: "web-Panoramic_view_of_San_Carlos_Island,_Zulia_State.jpg-1673438804000", ownerId: "5b48c453-d55f-4cc2-a585-ce406ea8e3d6", deviceId: "WEB", type: .image, originalPath: "upload/library/5b48c453-d55f-4cc2-a585-ce406ea8e3d6/2012/2012-10-12/Panoramic_view_of_San_Carlos_Island,_Zulia_State.jpg", originalFileName: "Panoramic_view_of_San_Carlos_Island,_Zulia_State.jpg", originalMimeType: "image/jpeg", isFavorite: false, exifInfo: nil, localDateTime: "2014-08-06T17:46:11.000Z"),
                        AssetItem(id: "6.jpg", deviceAssetId: "web-Strandkörbe_in_Kühlungsborn-3-.jpg-1673438900000", ownerId: "5b48c453-d55f-4cc2-a585-ce406ea8e3d6", deviceId: "WEB", type: .image, originalPath: "upload/library/5b48c453-d55f-4cc2-a585-ce406ea8e3d6/2012/2012-06-08/Strandkörbe_in_Kühlungsborn-3-.jpg", originalFileName: "Strandkörbe_in_Kühlungsborn-3-.jpg", originalMimeType: "image/jpeg", isFavorite: false, exifInfo: nil, localDateTime: "2013-08-06T17:46:11.000Z"),
                        AssetItem(id: "7.jpg", deviceAssetId: "web-Eublepharis_macularius_2009_G7.jpg-1673438640000", ownerId: "5b48c453-d55f-4cc2-a585-ce406ea8e3d6", deviceId: "WEB", type: .image, originalPath: "upload/library/5b48c453-d55f-4cc2-a585-ce406ea8e3d6/2009/2009-08-09/Eublepharis_macularius_2009_G7.jpg", originalFileName: "Eublepharis_macularius_2009_G7.jpg", originalMimeType: "image/jpeg", isFavorite: false, exifInfo: nil, localDateTime: "2013-08-06T17:46:11.000Z"),
                        AssetItem(id: "8.jpg", deviceAssetId: "web-Pogona_vitticeps_2009_G4.jpg-1673438828000", ownerId: "5b48c453-d55f-4cc2-a585-ce406ea8e3d6", deviceId: "WEB", type: .image, originalPath: "upload/library/5b48c453-d55f-4cc2-a585-ce406ea8e3d6/2009/2009-08-08/Pogona_vitticeps_2009_G4.jpg", originalFileName: "Pogona_vitticeps_2009_G4.jpg", originalMimeType: "image/jpeg", isFavorite: false, exifInfo: nil, localDateTime: "2013-08-06T17:46:11.000Z"),
                        AssetItem(id: "9.jpg", deviceAssetId: "web-Brachypelma_klaasi_2009_G12.jpg-1673438550000", ownerId: "5b48c453-d55f-4cc2-a585-ce406ea8e3d6", deviceId: "WEB", type: .image, originalPath: "upload/library/5b48c453-d55f-4cc2-a585-ce406ea8e3d6/2009/2009-08-08/Brachypelma_klaasi_2009_G12.jpg", originalFileName: "Brachypelma_klaasi_2009_G12.jpg", originalMimeType: "image/jpeg", isFavorite: false, exifInfo: nil, localDateTime: "2013-08-06T17:46:11.000Z")]
                if ascending {
                    assetItems = assetItems.reversed()
                }
                if entitlementManager.groupByDay {
                    assetItemsGrouped = groupAssets(assetItems: assetItems, ascending: ascending)
                }
            } else {
                assetItems = [AssetItem(id: "11.jpg", deviceAssetId: "web-Telega_in_Sosonka_2017_G1.jpg-1673438906000", ownerId: "5b48c453-d55f-4cc2-a585-ce406ea8e3d6", deviceId: "WEB", type: .image, originalPath: "upload/library/5b48c453-d55f-4cc2-a585-ce406ea8e3d6/2017/2017-05-02/Telega_in_Sosonka_2017_G1.jpg", originalFileName: "Telega_in_Sosonka_2017_G1.jpg", originalMimeType: "image/jpeg", isFavorite: false, exifInfo: nil, localDateTime: "2017-08-06T17:46:11.000Z"),
                        AssetItem(id: "12.jpg", deviceAssetId: "web-Chevrolet_Master_Special_Eagle_1933_-_Z16725_-_front.jpg-1673438582000", ownerId: "5b48c453-d55f-4cc2-a585-ce406ea8e3d6", deviceId: "WEB", type: .image, originalPath: "upload/library/5b48c453-d55f-4cc2-a585-ce406ea8e3d6/2017/2017-04-21/Chevrolet_Master_Special_Eagle_1933_-_Z16725_-_front.jpg", originalFileName: "Chevrolet_Master_Special_Eagle_1933_-_Z16725_-_front.jpg", originalMimeType: "image/jpeg", isFavorite: false, exifInfo: nil, localDateTime: "2017-08-06T17:46:11.000Z"),
                        AssetItem(id: "13.jpg", deviceAssetId: "web-Calle_en_centro_de_Maracaibo.jpg-1673438560000", ownerId: "5b48c453-d55f-4cc2-a585-ce406ea8e3d6", deviceId: "WEB", type: .image, originalPath: "upload/library/5b48c453-d55f-4cc2-a585-ce406ea8e3d6/2013/2013-02-23/Calle_en_centro_de_Maracaibo.jpg", originalFileName: "Calle_en_centro_de_Maracaibo.jpg", originalMimeType: "image/jpeg", isFavorite: false, exifInfo: nil, localDateTime: "2017-08-06T17:46:11.000Z"),
                        AssetItem(id: "14.jpg", deviceAssetId: "web-Police_car_Vienna_Volkswagen_Touran.jpg-1673438830000", ownerId: "5b48c453-d55f-4cc2-a585-ce406ea8e3d6", deviceId: "WEB", type: .image, originalPath: "upload/library/5b48c453-d55f-4cc2-a585-ce406ea8e3d6/2012/2012-02-20/Police_car_Vienna_Volkswagen_Touran.jpg", originalFileName: "Police_car_Vienna_Volkswagen_Touran.jpg", originalMimeType: "image/jpeg", isFavorite: false, exifInfo: nil, localDateTime: "2015-08-06T17:46:11.000Z"),
                        AssetItem(id: "15.jpg", deviceAssetId: "web-S-3D_cycle-car_2011_G1.jpg-1673438864000", ownerId: "5b48c453-d55f-4cc2-a585-ce406ea8e3d6", deviceId: "WEB", type: .image, originalPath: "upload/library/5b48c453-d55f-4cc2-a585-ce406ea8e3d6/2011/2011-02-14/S-3D_cycle-car_2011_G1.jpg", originalFileName: "S-3D_cycle-car_2011_G1.jpg", originalMimeType: "image/jpeg", isFavorite: false, exifInfo: nil, localDateTime: "2015-08-06T17:46:11.000Z")]
                if ascending {
                    assetItems = assetItems.reversed()
                }
                if entitlementManager.groupByDay {
                    assetItemsGrouped = groupAssets(assetItems: assetItems, ascending: ascending)
                }
            }
        } else {
            guard let url = URL(string: "\(entitlementManager.baseURL)/api/albums/\(albumId)?apiKey=\(entitlementManager.apiKey)") else {
                throw NSError(domain: "url doesn't work", code: 100)
            }
            let (data, _) = try await URLSession.shared.data(from: url)
            // Assuming the API returns an array of asset objects with id and path
            let asset: Asset = try decoder(data)
            if ascending {
                assetItems = asset.assets.reversed()
            } else {
                assetItems = asset.assets
            }
            if entitlementManager.groupByDay {
                assetItemsGrouped = groupAssets(assetItems: assetItems, ascending: ascending)
            }
        }
    }
    
    func getImageUrl(id: String, thumbnail: Bool = true, video: Bool = false) -> URL? {
        if entitlementManager.demo {
            return URL(string: "\(entitlementManager.baseURL)/api/assets/\(id)")
        } else {
            if thumbnail || video {
                return URL(string: "\(entitlementManager.baseURL)/api/assets/\(id)/thumbnail/?apiKey=\(entitlementManager.apiKey)")
            } else {
                return URL(string: "\(entitlementManager.baseURL)/api/assets/\(id)/original/?apiKey=\(entitlementManager.apiKey)")
            }
        }
    }
    
    func getVideoUrl(id: String) -> URL? {
        return URL(string: "\(entitlementManager.baseURL)/api/assets/\(id)/video/playback/?apiKey=\(entitlementManager.apiKey)")
    }
    
    @MainActor
    func searchAssets(query: Query) async throws -> Int? {
        if entitlementManager.demo {
            try? await Task.sleep(nanoseconds: UInt64(2 * 1000000000)) // Convert seconds to nanoseconds
            assetItems = [AssetItem(id: "1.jpg", deviceAssetId: "web-Brachypelma_klaasi_2009_G12.jpg-1673438550000", ownerId: "5b48c453-d55f-4cc2-a585-ce406ea8e3d6", deviceId: "WEB", type: .image, originalPath: "upload/library/5b48c453-d55f-4cc2-a585-ce406ea8e3d6/2009/2009-08-08/Brachypelma_klaasi_2009_G12.jpg", originalFileName: "Brachypelma_klaasi_2009_G12.jpg", originalMimeType: "image/jpeg", isFavorite: false, exifInfo: nil, localDateTime: "2015-08-06T17:46:11.000Z"),
                     AssetItem(id: "2.jpg", deviceAssetId: "web-Pogona_vitticeps_2009_G4.jpg-1673438828000", ownerId: "5b48c453-d55f-4cc2-a585-ce406ea8e3d6", deviceId: "WEB", type: .image, originalPath: "upload/library/5b48c453-d55f-4cc2-a585-ce406ea8e3d6/2009/2009-08-08/Pogona_vitticeps_2009_G4.jpg", originalFileName: "Pogona_vitticeps_2009_G4.jpg", originalMimeType: "image/jpeg", isFavorite: false, exifInfo: nil, localDateTime: "2015-08-06T17:46:11.000Z"),
                     AssetItem(id: "3.jpg", deviceAssetId: "web-Police_car_Vienna_Volkswagen_Touran.jpg-1673438830000", ownerId: "5b48c453-d55f-4cc2-a585-ce406ea8e3d6", deviceId: "WEB", type: .image, originalPath: "upload/library/5b48c453-d55f-4cc2-a585-ce406ea8e3d6/2012/2012-02-20/Police_car_Vienna_Volkswagen_Touran.jpg", originalFileName: "Police_car_Vienna_Volkswagen_Touran.jpg", originalMimeType: "image/jpeg", isFavorite: false, exifInfo: nil, localDateTime: "2015-08-06T17:46:11.000Z"),
                     AssetItem(id: "4.jpg", deviceAssetId: "web-Eublepharis_macularius_2009_G7.jpg-1673438640000", ownerId: "5b48c453-d55f-4cc2-a585-ce406ea8e3d6", deviceId: "WEB", type: .image, originalPath: "upload/library/5b48c453-d55f-4cc2-a585-ce406ea8e3d6/2009/2009-08-09/Eublepharis_macularius_2009_G7.jpg", originalFileName: "Eublepharis_macularius_2009_G7.jpg", originalMimeType: "image/jpeg", isFavorite: false, exifInfo: nil, localDateTime: "2015-08-06T17:46:11.000Z"),
                     AssetItem(id: "5.jpg", deviceAssetId: "web-Donax_striatus_Linnaeus,_1767_in_Margarita_Island_2.jpg-1673438622000", ownerId: "5b48c453-d55f-4cc2-a585-ce406ea8e3d6", deviceId: "WEB", type: .image, originalPath: "upload/library/5b48c453-d55f-4cc2-a585-ce406ea8e3d6/2013/2013-05-20/Donax_striatus_Linnaeus,_1767_in_Margarita_Island_2.jpg", originalFileName: "Donax_striatus_Linnaeus,_1767_in_Margarita_Island_2.jpg", originalMimeType: "image/jpeg", isFavorite: false, exifInfo: nil, localDateTime: "2015-08-06T17:46:11.000Z"),
                     AssetItem(id: "6.jpg", deviceAssetId: "web-Telega_in_Sosonka_2017_G1.jpg-1673438906000", ownerId: "5b48c453-d55f-4cc2-a585-ce406ea8e3d6", deviceId: "WEB", type: .image, originalPath: "upload/library/5b48c453-d55f-4cc2-a585-ce406ea8e3d6/2017/2017-05-02/Telega_in_Sosonka_2017_G1.jpg", originalFileName: "Telega_in_Sosonka_2017_G1.jpg", originalMimeType: "image/jpeg", isFavorite: false, exifInfo: nil, localDateTime: "2015-08-06T17:46:11.000Z"),
                     AssetItem(id: "7.jpg", deviceAssetId: "web-S-3D_cycle-car_2011_G1.jpg-1673438864000", ownerId: "5b48c453-d55f-4cc2-a585-ce406ea8e3d6", deviceId: "WEB", type: .image, originalPath: "upload/library/5b48c453-d55f-4cc2-a585-ce406ea8e3d6/2011/2011-02-14/S-3D_cycle-car_2011_G1.jpg", originalFileName: "S-3D_cycle-car_2011_G1.jpg", originalMimeType: "image/jpeg", isFavorite: false, exifInfo: nil, localDateTime: "2015-08-06T17:46:11.000Z"),
                     AssetItem(id: "8.jpg", deviceAssetId: "web-Panoramic_view_of_San_Carlos_Island,_Zulia_State.jpg-1673438804000", ownerId: "5b48c453-d55f-4cc2-a585-ce406ea8e3d6", deviceId: "WEB", type: .image, originalPath: "upload/library/5b48c453-d55f-4cc2-a585-ce406ea8e3d6/2012/2012-10-12/Panoramic_view_of_San_Carlos_Island,_Zulia_State.jpg", originalFileName: "Panoramic_view_of_San_Carlos_Island,_Zulia_State.jpg", originalMimeType: "image/jpeg", isFavorite: false, exifInfo: nil, localDateTime: "2015-08-06T17:46:11.000Z"),
                     AssetItem(id: "9.jpg", deviceAssetId: "web-Chevrolet_Master_Special_Eagle_1933_-_Z16725_-_front.jpg-1673438582000", ownerId: "5b48c453-d55f-4cc2-a585-ce406ea8e3d6", deviceId: "WEB", type: .image, originalPath: "upload/library/5b48c453-d55f-4cc2-a585-ce406ea8e3d6/2017/2017-04-21/Chevrolet_Master_Special_Eagle_1933_-_Z16725_-_front.jpg", originalFileName: "Chevrolet_Master_Special_Eagle_1933_-_Z16725_-_front.jpg", originalMimeType: "image/jpeg", isFavorite: false, exifInfo: nil, localDateTime: "2015-08-06T17:46:11.000Z"),
                     AssetItem(id: "11.jpg", deviceAssetId: "web-Calle_en_centro_de_Maracaibo.jpg-1673438560000", ownerId: "5b48c453-d55f-4cc2-a585-ce406ea8e3d6", deviceId: "WEB", type: .image, originalPath: "upload/library/5b48c453-d55f-4cc2-a585-ce406ea8e3d6/2013/2013-02-23/Calle_en_centro_de_Maracaibo.jpg", originalFileName: "Calle_en_centro_de_Maracaibo.jpg", originalMimeType: "image/jpeg", isFavorite: false, exifInfo: nil, localDateTime: "2017-08-06T17:46:11.000Z"),
                     AssetItem(id: "12.jpg", deviceAssetId: "web-Fishing_boats,_morning,_Beach,_Rincon_de_la_Victoria,_Andalusia,_Spain.jpg-1673438646000", ownerId: "5b48c453-d55f-4cc2-a585-ce406ea8e3d6", deviceId: "WEB", type: .image, originalPath: "upload/library/5b48c453-d55f-4cc2-a585-ce406ea8e3d6/2014/2014-08-01/Fishing_boats,_morning,_Beach,_Rincon_de_la_Victoria,_Andalusia,_Spain.jpg", originalFileName: "Fishing_boats,_morning,_Beach,_Rincon_de_la_Victoria,_Andalusia,_Spain.jpg", originalMimeType: "image/jpeg", isFavorite: false, exifInfo: nil, localDateTime: "2017-08-06T17:46:11.000Z"),
                     AssetItem(id: "13.jpg", deviceAssetId: "web-Carrelet,_Esnandes,_Charente-Maritime,_august_2015.jpg-1673438566000", ownerId: "5b48c453-d55f-4cc2-a585-ce406ea8e3d6", deviceId: "WEB", type: .image, originalPath: "upload/library/5b48c453-d55f-4cc2-a585-ce406ea8e3d6/2015/2015-08-06/Carrelet,_Esnandes,_Charente-Maritime,_august_2015.jpg", originalFileName: "Carrelet,_Esnandes,_Charente-Maritime,_august_2015.jpg", originalMimeType: "image/jpeg", isFavorite: false, exifInfo: nil, localDateTime: "2017-08-06T17:46:11.000Z"),
                     AssetItem(id: "14.jpg", deviceAssetId: "web-Strandkörbe_in_Kühlungsborn-3-.jpg-1673438900000", ownerId: "5b48c453-d55f-4cc2-a585-ce406ea8e3d6", deviceId: "WEB", type: .image, originalPath: "upload/library/5b48c453-d55f-4cc2-a585-ce406ea8e3d6/2012/2012-06-08/Strandkörbe_in_Kühlungsborn-3-.jpg", originalFileName: "Strandkörbe_in_Kühlungsborn-3-.jpg", originalMimeType: "image/jpeg", isFavorite: false, exifInfo: nil, localDateTime: "2017-08-06T17:46:11.000Z"),
                     AssetItem(id: "15.jpg", deviceAssetId: "web-La_Restinga_Beach_3.jpg-1673438706000", ownerId: "5b48c453-d55f-4cc2-a585-ce406ea8e3d6", deviceId: "WEB", type: .image, originalPath: "upload/library/5b48c453-d55f-4cc2-a585-ce406ea8e3d6/2013/2013-01-06/La_Restinga_Beach_3.jpg", originalFileName: "La_Restinga_Beach_3.jpg", originalMimeType: "image/jpeg", isFavorite: false, exifInfo: nil, localDateTime: "2017-08-06T17:46:11.000Z")]
            let ascending = ((query.body["order"] as? String) ?? "") == "asc"
            if ascending {
                assetItems = assetItems.reversed()
            }
            if entitlementManager.groupByDay {
                assetItemsGrouped = groupAssets(assetItems: assetItems, ascending: ascending)
            }
            return nil
        } else {
            let url = query.isSmartSearch ? URL(string: "\(entitlementManager.baseURL)/api/search/smart")! : URL(string: "\(entitlementManager.baseURL)/api/search/metadata")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue(entitlementManager.apiKey, forHTTPHeaderField: "x-api-key")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            request.httpBody = try JSONSerialization.data(withJSONObject: query.body)
            
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
           
            assetItems = response.assets.items
            if entitlementManager.groupByDay {
                assetItemsGrouped = groupAssets(assetItems: assetItems, ascending: false)
            }
            return nextPage
        }
    }
    
    func getAsset(id: String) async throws -> AssetItem {
        guard let url = URL(string: "\(entitlementManager.baseURL)/api/assets/\(id)?apiKey=\(entitlementManager.apiKey)") else {
            throw NSError(domain: "url doesn't work", code: 100)
        }
        let (data, _) = try await URLSession.shared.data(from: url)
        return try decoder(data)
    }
    
    @MainActor
    func getMyUser() async throws {
        if entitlementManager.demo {
            user = User(name: "demo", email: "demo@demo.com")
        } else {
            guard let url = URL(string: "\(entitlementManager.baseURL)/api/users/me?apiKey=\(entitlementManager.apiKey)") else {
                throw NSError(domain: "url doesn't work", code: 100)
            }
            let (data, _) = try await URLSession.shared.data(from: url)
            // Assuming the API returns an array of asset objects with id and path
            user = try decoder(data)
        }
    }
    
    func getStorage() async throws -> Storage{
        if entitlementManager.demo {
            return Storage(diskAvailable: "10.0 TiB", diskAvailableRaw: 10993775525888, diskSize: "10.5 TiB", diskSizeRaw: 11490240110592, diskUsagePercentage: 4.32, diskUse: "462.4 GiB", diskUseRaw: 496464584704)
        } else {
            guard let url = URL(string: "\(entitlementManager.baseURL)/api/server/storage?apiKey=\(entitlementManager.apiKey)") else {
                throw NSError(domain: "url doesn't work", code: 100)
            }
            let (data, _) = try await URLSession.shared.data(from: url)
            return try decoder(data)
        }
    }
    
    func updateAssets(id: String, favorite: Bool) async throws -> AssetItem {
        guard let url = URL(string: "\(entitlementManager.baseURL)/api/assets/\(id)") else {
            throw NSError(domain: "url doesn't work", code: 100)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue(entitlementManager.apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let body: [String: Any] = [
            "isFavorite": favorite
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, _) = try await URLSession.shared.data(for: request)
        return try decoder(data)
    }
}

extension ImmichService {
    // Login function
    private func login(baseURL: String, email: String, password: String) async throws -> String {
        guard let url = URL(string: "\(baseURL)/api/auth/login") else {
            throw NSError(domain: "url doesn't work", code: 100)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        //request.setValue(entitlementManager.apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "email": email,
            "password": password
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let loginResponse: LoginResponse = try decoder(data)
        return loginResponse.accessToken
    }
    
    // Create API key function
    func createAPIKey(baseURL: String, email: String, password: String) async throws -> String {
        if email == "demo" && password == "demo" {
            return "demo"
        } else {
            let accessToken = try await login(baseURL: baseURL, email: email, password: password)
            guard let url = URL(string: "\(baseURL)/api/api-keys") else {
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
            let apiKeyResponse: APIRequestResponse = try decoder(data)
            return apiKeyResponse.apiKey.id
        }
    }
}

extension ImmichService {
    func decoder<T: Decodable>(_ data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            let failure = try JSONDecoder().decode(ErrorMessage.self, from: data)
            throw NSError(domain: failure.error, code: failure.statusCode, userInfo: ["message":failure.message])
        }
    }
}

#if os(tvOS)
#else
public enum DownloadError: Error {
    case downloadError(msg: String)
    
    public var localizedDescription: String {
        switch self {
        case .downloadError(let msg): return "\(msg)"
        }
    }
}

extension ImmichService {
    // Find or create the album
    private func setupAlbum(albumName: String = "ImmichTV") async throws -> PHAssetCollection {
        return try await withCheckedThrowingContinuation { continuation in
            let fetchOptions = PHFetchOptions()
            fetchOptions.predicate = NSPredicate(format: "title = %@", albumName)
            let collection = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: fetchOptions)
            
            if let album = collection.firstObject {
                continuation.resume(returning: album)
            } else {
                PHPhotoLibrary.shared().performChanges({
                    PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: albumName)
                }) { success, error in
                    if success {
                        let newCollection = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: fetchOptions)
                        continuation.resume(returning: newCollection.firstObject!)
                    } else if let error = error {
                        continuation.resume(throwing: DownloadError.downloadError(msg: "Error creating album: \(error)"))
                    }
                }
            }
        }
    }
    
    
    @MainActor
    func downloadImage(currentIndex: Int) async throws -> String {
        // Ensure Photos permission
        try await requestPhotoLibraryPermission()
        // Get image URL
        guard let imageURL = getImageUrl(id: assetItems[currentIndex].id, thumbnail: false) else {
            throw DownloadError.downloadError(msg: "Invalid URL")
        }
        
        // Download image
        let (data, response) = try await Foundation.URLSession.shared.data(from: imageURL)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw DownloadError.downloadError(msg: "Invalid server response")
        }
        
        guard let uiImage = UIImage(data: data) else {
            throw DownloadError.downloadError(msg: "Failed to create image from data")
        }
        
        let album = try await setupAlbum()
        
        // Save to Photos
        return try await withCheckedThrowingContinuation { continuation in
            PHPhotoLibrary.shared().performChanges({
                // Set up options with the desired filename
                let options = PHAssetResourceCreationOptions()
                options.originalFilename = self.assetItems[currentIndex].originalFileName
                
                let creationRequest = PHAssetCreationRequest.forAsset()
                creationRequest.addResource(with: .photo, data: uiImage.jpegData(compressionQuality: 1.0)!, options: nil)
                
                // Add asset to album
                if let asset = creationRequest.placeholderForCreatedAsset {
                    let albumChangeRequest = PHAssetCollectionChangeRequest(for: album)
                    albumChangeRequest?.addAssets([asset] as NSArray)
                }
            }) { success, error in
                if success {
                    continuation.resume(returning: "Image saved successfully!")
                } else {
                    continuation.resume(throwing: DownloadError.downloadError(msg: "Failed to save image: \(error?.localizedDescription ?? "Unknown error")"))
                }
            }
        }
    }
    
    func downloadVideo(currentIndex: Int) async throws -> String {
        // Ensure Photos permission
        try await requestPhotoLibraryPermission()
        // Get video URL
        guard let videoURL = getVideoUrl(id: assetItems[currentIndex].id) else {
            throw DownloadError.downloadError(msg: "Invalid URL")
        }
        
        // Download video
        let tempURL = try await downloadToTemp(videoURL: videoURL, filename: assetItems[currentIndex].originalFileName)
        
        let album = try await setupAlbum()
        
        return try await saveVideo(tempURL: tempURL, album: album)
    }
    
    private func downloadToTemp(videoURL: URL, filename: String) async throws -> URL {
        return try await withCheckedThrowingContinuation { continuation in
            let task = URLSession.shared.downloadTask(with: videoURL) { tempURL, response, error in
                guard let tempURL = tempURL else {
                    continuation.resume(throwing: DownloadError.downloadError(msg: "Failed to download video"))
                    return
                }
                
                // Verify the file exists
                guard FileManager.default.fileExists(atPath: tempURL.path) else {
                    continuation.resume(throwing: DownloadError.downloadError(msg: "Downloaded file does not exist at \(tempURL.path)"))
                    return
                }

                // Copy the file to a stable temporary location to prevent deletion
                let stableURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
                do {
                    try FileManager.default.copyItem(at: tempURL, to: stableURL)
                    continuation.resume(returning: stableURL)
                } catch {
                    continuation.resume(throwing: DownloadError.downloadError(msg: "Failed to copy file: \(error)"))
                }
            }
            // Start the download task
            task.resume()
        }
    }
    
    private func saveVideo(tempURL: URL, album: PHAssetCollection) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            PHPhotoLibrary.shared().performChanges({
                let creationRequest = PHAssetCreationRequest.forAsset()
                creationRequest.addResource(with: .video, fileURL: tempURL, options: nil)
                
                // Add asset to album
                if let asset = creationRequest.placeholderForCreatedAsset {
                    let albumChangeRequest = PHAssetCollectionChangeRequest(for: album)
                    albumChangeRequest?.addAssets([asset] as NSArray)
                }
            }) { success, error in
                if success {
                    continuation.resume(returning: "Video saved successfully!")
                } else {
                    continuation.resume(throwing: DownloadError.downloadError(msg: "Failed to save video: \(error?.localizedDescription ?? "Unknown error")"))
                }
                // Clean up temporary file
                try? FileManager.default.removeItem(at: tempURL)
            }
        }
    }
    
    // Helper function to request Photos permission
    @MainActor
    func requestPhotoLibraryPermission() async throws {
        try await withCheckedThrowingContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                DispatchQueue.main.async {
                    switch status {
                    case .authorized, .limited:
                        continuation.resume()
                    case .denied, .restricted:
                        continuation.resume(throwing: DownloadError.downloadError(msg: "Photo library permission denied"))
                    case .notDetermined:
                        continuation.resume(throwing: DownloadError.downloadError(msg: "Photo library access not determined"))
                    @unknown default:
                        continuation.resume(throwing: DownloadError.downloadError(msg: "Unknown authorization status"))
                    }
                }
            }
        }
    }
}

#endif
