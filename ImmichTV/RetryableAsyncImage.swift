//
//  RetryableAsyncImage.swift
//  ImmichTV
//
//  Created by David Lüthi on 14.04.2025.
//

import SwiftUI

struct RetryableAsyncImage: View {
    let url: URL?
    var tilewidth: CGFloat = 0
    @State private var retryCount = 0
    @Binding var imageSize: CGSize
    var video: Bool = false
    
    func isSlide(image: Image) -> Bool {
        imageSize = image.asUIImage()?.size ?? CGSizeZero
        return tilewidth == 0
    }
    
    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .empty:
                if retryCount < 10 {
                    ProgressView().progressViewStyle(CircularProgressViewStyle()).scaleEffect(1)
                } else {
                    VStack{
                        Text("error loading").font(.footnote).foregroundColor(.red)
                        Image(systemName: "exclamationmark.triangle").resizable().scaledToFit().frame(width: 50, height: 50).foregroundColor(.red)
                    }
                }
            case .success(let image):
                if tilewidth != 0 {
                    ZStack(alignment: .center) {
                        image.resizable().frame(width: tilewidth, height: tilewidth * 0.75).blur(radius: 10)
                        image.resizable().scaledToFit().frame(width: tilewidth - 4, height: (tilewidth * 0.75) - 3)
                    }
                } else {
                    image.resizable().scaledToFit().ignoresSafeArea().cornerRadius(15)
                        .background(.black)
                        .onAppear {
                            imageSize = image.asUIImage()?.size ?? CGSizeZero
                        }
                        .overlay(alignment: .bottomTrailing){
                            if video {
                                Image(systemName: "video").background(.black.opacity(0.5)).foregroundColor(.white.opacity(0.8))
                            }
                        }
                }
            case .failure(let error):
                if tilewidth == 0 {
                    VStack{
                        Text("\(tilewidth == 0 ? error.localizedDescription : "error loading")").font(.footnote).foregroundColor(.red)
                        Image(systemName: "exclamationmark.triangle").resizable().scaledToFit().frame(width: 50, height: 50).foregroundColor(.red)
                    }.onAppear{
                        print(error.localizedDescription)
                        if retryCount < 10 {
                            retryCount += 1
                        }
                    }
                } else {
                    VStack{
                        Text("\(tilewidth == 0 ? error.localizedDescription : "error loading")").font(.footnote).foregroundColor(.red)
                        Image(systemName: "exclamationmark.triangle").resizable().scaledToFit().frame(width: 50, height: 50).foregroundColor(.red)
                    }.frame(width: tilewidth == 0 ? .infinity : tilewidth, height: tilewidth == 0 ? .infinity : tilewidth * 0.75).onAppear{
                        if retryCount < 10 {
                            retryCount += 1
                        }
                    }
                }
            @unknown default:
                Color.gray.frame(width: tilewidth, height: tilewidth * 0.75)
            }
        }.id(retryCount)
    }
}


extension Image {
    func asUIImage() -> UIImage? {
        // Create a hosting controller to render the SwiftUI Image
        let controller = UIHostingController(rootView: self)
        
        // Ensure the view is laid out
        let view = controller.view
        let targetSize = controller.view.intrinsicContentSize
        view?.bounds = CGRect(origin: .zero, size: targetSize)
        view?.backgroundColor = .clear
        
        // Render the view to an image
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            view?.drawHierarchy(in: view!.bounds, afterScreenUpdates: true)
        }
    }
}
