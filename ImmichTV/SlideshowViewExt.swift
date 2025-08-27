//
//  SlideshowViewExt.swift
//  ImmichTV
//
//  Created by David Lüthi on 20.08.2025.
//

import SwiftUI
import Foundation
import Combine

extension View {
    func progressView(
        isPresented: Binding<Bool>,
        message: String
    ) -> some View {
        fullScreenCover(isPresented: isPresented) {
            VStack {
                ProgressView().progressViewStyle(CircularProgressViewStyle()).scaleEffect(1.5) // Optional: Adjust size
                    .tint(Color.primary)
                Text("\(message)").multilineTextAlignment(.center)
                
            }.padding()
                .frame(maxWidth: .infinity)
                .background(Color.secondary)
                .cornerRadius(35)
                .padding()
                .transition(.slide)
            .presentationBackground(.clear)
        }.transaction { transaction in
            if isPresented.wrappedValue {
                // disable the default FullScreenCover animation
                transaction.disablesAnimations = true
                
                // add custom animation for presenting and dismissing the FullScreenCover
                transaction.animation = .linear(duration: 0.1)
            }
        }
    }
}

extension View {
    func isMac() -> Bool {
        #if targetEnvironment(macCatalyst)
        return true
        #else
        return false
        #endif
    }
    
    func isTVOS() -> Bool {
        #if os(tvOS)
        return true
        #else
        return false
        #endif
    }
    
    func isIOS() -> Bool {
        #if os(tvOS)
        return false
        #else
        #if targetEnvironment(macCatalyst)
        return false
        #else
        return true
        #endif
        #endif
    }
}

