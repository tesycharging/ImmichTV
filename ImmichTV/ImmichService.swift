//
//  ImmichService.swift
//  ImmichTV
//
//  Created by David Lüthi on 17.03.2025.
//

import Foundation

class ImmichService: ObservableObject {
    private var entitlementManager: EntitlementManager
    @Published var albumsGrouped: [Date: [Album]] = [:]
    @Published var assetItems: [AssetItem] = []
    @Published var assetItemsGrouped: [Date: [AssetItem]] = [:]
    
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
    
    @MainActor
    func fetchAlbums() async throws {
        if entitlementManager.demo {
            try? await Task.sleep(nanoseconds: UInt64(2 * 1000000000)) // Convert seconds to nanoseconds
            albumsGrouped = groupAlbums(albums: [Album(albumName: "Beaches", description: "", albumThumbnailAssetId: "1_thumb.jpg", id: "1", startDate: "2009-08-08T10:14:13.000Z", endDate: "2015-08-06T17:46:11.000Z"), Album(albumName: "Cars", description: "", albumThumbnailAssetId: "11_thumb.jpg", id: "2", startDate: "2011-02-14T14:09:47.230Z", endDate: "2017-05-02T11:08:34.740Z")])
        } else {
            guard let url = URL(string: "\(entitlementManager.baseURL)/api/albums?apiKey=\(entitlementManager.apiKey)") else {
                throw NSError(domain: "url doesn't work", code: 100)
            }
            let (data, _) = try await URLSession.shared.data(from: url)
            if data.count == 2 {
                throw NSError(domain: "no albums found", code: 100)
            }
            albumsGrouped = groupAlbums(albums: try JSONDecoder().decode([Album].self, from: data))
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
            let asset = try JSONDecoder().decode(Asset.self, from: data)
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
 
        return try JSONDecoder().decode(AssetItem.self, from: data)
    }
    
    func getMyUser() async throws -> String {
        if entitlementManager.demo {
            return "demo"
        } else {
            guard let url = URL(string: "\(entitlementManager.baseURL)/api/users/me?apiKey=\(entitlementManager.apiKey)") else {
                throw NSError(domain: "url doesn't work", code: 100)
            }
            let (data, _) = try await URLSession.shared.data(from: url)
            // Assuming the API returns an array of asset objects with id and path
            let user = try JSONDecoder().decode(User.self, from: data)
            return user.name
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
            return try JSONDecoder().decode(Storage.self, from: data)
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
        let assetItem = try JSONDecoder().decode(AssetItem.self, from: data)
        return assetItem
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
        let loginResponse = try JSONDecoder().decode(LoginResponse.self, from: data)
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
            let apiKeyResponse = try JSONDecoder().decode(APIRequestResponse.self, from: data)
            return apiKeyResponse.apiKey.id
        }
    }
}
