//
//  Model.swift
//  ImmichTV
//
//  Created by David Lüthi on 17.03.2025.
//

import Foundation

struct Album: Hashable, Identifiable, Codable {
    let albumName: String
    let description: String
    let albumThumbnailAssetId: String
    let id: String
    let startDate: String
    let endDate: String
}

struct Asset: Identifiable, Codable {
    let id: String
    let albumName: String
    let assets: [AssetItem]
}



// Top-level search response
struct SearchResponse: Codable {
    let albums: Albums
    let assets: Assets
}

// Albums section
struct Albums: Codable {
    let total: Int
    let count: Int
}

// Assets section
struct Assets: Codable {
    let total: Int
    let count: Int
    let items: [AssetItem]
    //let facets: [Facet]
    let nextPage: String? // Optional, as it could be null
}

// Asset item (for both VIDEO and IMAGE types)
struct AssetItem: Identifiable, Hashable, Codable, Equatable {
    let id: String
    let deviceAssetId: String
    let ownerId: String
    let deviceId: String
    let type: AssetType
    let originalPath: String
    let originalFileName: String
    let originalMimeType: String
    let isFavorite: Bool
    let exifInfo: ExifInfo?
    /*let thumbhash: String
    let fileCreatedAt: Date
    let fileModifiedAt: Date
    let localDateTime: Date
    let updatedAt: Date
    let isArchived: Bool
    let isTrashed: Bool
    let duration: String
    let livePhotoVideoId: String? // Nullable
    //let people: [Person]          // Empty array; define as needed
    let checksum: String
    let isOffline: Bool
    let hasMetadata: Bool
    let duplicateId: String?      // Nullable
    let resized: Bool*/
    
    static func ==(lhs: AssetItem, rhs: AssetItem) -> Bool {
        return lhs.id == rhs.id
    }
}

// Asset type enum
enum AssetType: String, Codable {
    case video = "VIDEO"
    case image = "IMAGE"
}

struct ExifInfo: Codable, Hashable {
    let city: String?
    let country: String?
    let dateTimeOriginal: String?
    let latitude: Double?
    let longitude: Double?
}


struct User: Codable {
    let name: String
    let email: String
}

struct Storage: Codable {
    let diskAvailable: String
    let diskAvailableRaw: Int64
    let diskSize: String
    let diskSizeRaw: Int64
    let diskUsagePercentage: Double
    let diskUse: String
    let diskUseRaw: Int64
}

struct ServerStatistics: Codable {
    let photos: Int
    let usage: Int
}

// Login response
struct LoginResponse: Codable {
    let accessToken: String
    let userId: String
}

// API request reposnse
struct APIRequestResponse: Codable {
    let secret: String
    let apiKey: APIKeyResponse
}
// API key creation response
struct APIKeyResponse: Codable {
    let id: String
    let name: String
}
