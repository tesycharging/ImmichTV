//
//  ExifInfoView.swift
//  ImmichTV
//
//  Created by David Lüthi on 27.08.2025.
//

import SwiftUI
import Foundation
import Combine

struct ExifInfoView: View {
    var currentItem: AssetItem
    var exifInfo: ExifInfo?
    var index: Int
    var page: Int
    
    @FocusState private var focusedButton: String? // Track which button is focused
    @State private var comeFromSubview = false
    
    var body: some View {
        VStack(alignment: .center) {
            Text("Exif & Settings").font(.title)
            ScrollView(.vertical, showsIndicators: false) {
                if let exifInfo = exifInfo {
                    Text("\(currentItem.originalFileName) #\(index) of Page \(page)").font(.caption)//.foregroundColor(.white.opacity(0.8))
                    if let result = location(exifInfo: exifInfo) {
                        Text("\(result)").font(.caption)//.foregroundColor(.white.opacity(0.8))
                    }
                    if exifInfo.latitude != nil && exifInfo.longitude != nil {
                        Text("GPS: \(exifInfo.latitude!): \(exifInfo.longitude!)").font(.caption)//.foregroundColor(.white.opacity(0.8))
                    }
                    if exifInfo.dateTimeOriginal != nil {
                        Text("\(convertToDate(from: exifInfo.dateTimeOriginal!) ?? "")").font(.caption)//.foregroundColor(.white.opacity(0.8))
                    }
                    if let cam = camera(exifInfo: exifInfo) {
                        Text("\(cam)").font(.caption)//.foregroundColor(.white.opacity(0.8))
                    }
                }
                SlideShowSettingView(comeFromSubview: $comeFromSubview, onSubmit: {})
            }
        }.padding(20)
    }
    
    func location(exifInfo: ExifInfo) -> String? {
        var result: String?
        if let city = exifInfo.city {
            result = city
        }
        if let country = exifInfo.country {
            result = result == nil ? country : "\(result!), \(country)"
        }
        return result
    }
    
    func camera(exifInfo: ExifInfo) -> String? {
        var result: String?
        if let make = exifInfo.make {
            result = make
        }
        if let model = exifInfo.model {
            result = result == nil ? model : "\(result!), \(model)"
        }
        return result
    }
    
    func convertToDate(from dateString: String) -> String? {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date =  isoFormatter.date(from: dateString) else { return nil }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .long    // e.g., "March 15, 2025"
        formatter.timeStyle = .medium  // e.g., "4:45:11 PM"
        formatter.timeZone = TimeZone(identifier: "UTC") // Match the +00:00 offset
        return formatter.string(from: date)
    }
}
