//
//  ScanningView.swift
//  DeNSFW
//
//  Created by Bedapudi Praneeth on 09/09/25.
//

import SwiftUI

struct ScanningView: View {
    @ObservedObject var photoManager: PhotoLibraryManager
    @ObservedObject var modelLoader: ModelLoader
    @Binding var isPresented: Bool
    @State private var showResults = false
    @State private var scanCompleted = false
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.07, green: 0.13, blue: 0.26),
                        Color(red: 0.13, green: 0.20, blue: 0.35)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 30) {
                    Spacer()
                    
                    if scanCompleted && photoManager.nsfwPhotos.isEmpty {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(Color(red: 0.4, green: 1.0, blue: 0.6))
                            .shadow(color: .black.opacity(0.3), radius: 5)
                        
                        Text("No NSFW Content Found")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        
                        Text("Your photo library is clean!")
                            .font(.body)
                            .foregroundColor(Color.white.opacity(0.8))
                    } else {
                        Image(systemName: "photo.stack")
                            .font(.system(size: 60))
                            .foregroundColor(Color(red: 0.4, green: 0.8, blue: 1.0))
                            .shadow(color: .black.opacity(0.3), radius: 5)
                        
                        Text("Scanning Photo Library")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        
                        VStack(spacing: 10) {
                            ProgressView(value: photoManager.scanProgress)
                                .progressViewStyle(LinearProgressViewStyle())
                                .scaleEffect(x: 1, y: 2, anchor: .center)
                                .tint(Color(red: 0.4, green: 0.8, blue: 1.0))
                            
                            Text("\(photoManager.scannedPhotos) of \(photoManager.totalPhotos) photos scanned")
                                .font(.caption)
                                .foregroundColor(Color.white.opacity(0.7))
                            
                            if photoManager.nsfwPhotos.count > 0 {
                                Text("\(photoManager.nsfwPhotos.count) NSFW photos detected")
                                    .font(.caption)
                                    .foregroundColor(Color(red: 1.0, green: 0.6, blue: 0.6))
                            }
                        }
                        .padding(.horizontal, 40)
                    }
                    
                    Spacer()
                    
                    Button(action: { isPresented = false }) {
                        Text(scanCompleted && photoManager.nsfwPhotos.isEmpty ? "Done" : "Cancel")
                            .padding(.horizontal, 30)
                            .padding(.vertical, 12)
                            .background(
                                scanCompleted && photoManager.nsfwPhotos.isEmpty ?
                                Color(red: 0.2, green: 0.6, blue: 1.0) :
                                Color(red: 0.8, green: 0.3, blue: 0.3)
                            )
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .shadow(color: .black.opacity(0.3), radius: 3)
                    }
                }
                .padding()
            }
            .navigationBarHidden(true)
            .task {
                await photoManager.scanPhotoLibrary()
                scanCompleted = true
                if !photoManager.nsfwPhotos.isEmpty {
                    showResults = true
                }
            }
            .fullScreenCover(isPresented: $showResults) {
                ResultsView(photoManager: photoManager, isPresented: $isPresented)
            }
        }
    }
}