//
//  ImmichTVApp.swift
//  ImmichTV
//
//  Created by David Lüthi on 17.03.2025.
//

import SwiftUI

@main
struct ImmichTVApp: App {
    @StateObject private var immichService: ImmichService
    @StateObject private var entitlementManager: EntitlementManager
    
    init() {
        let entitlementManager = EntitlementManager()
        let immichService = ImmichService(entitlementManager: entitlementManager)
        self._entitlementManager = StateObject(wrappedValue: entitlementManager)
        self._immichService = StateObject(wrappedValue: immichService)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(entitlementManager)
                .environmentObject(immichService)
        }
    }
}
