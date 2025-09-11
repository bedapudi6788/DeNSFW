//
//  ContentView.swift
//  DeNSFW
//
//  Created by Bedapudi Praneeth on 09/09/25.
//

import SwiftUI
import Photos

struct ContentView: View {
    @StateObject private var photoManager = PhotoLibraryManager()
    @StateObject private var modelLoader = ModelLoader()
    @State private var showScanning = false
    @State private var showPermissionAlert = false
    
    var body: some View {
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
            
            VStack(spacing: 40) {
                Spacer()
                
                VStack(spacing: 20) {
                    Image(systemName: "photo.badge.exclamationmark")
                        .font(.system(size: 80))
                        .foregroundColor(Color(red: 1.0, green: 0.4, blue: 0.4))
                        .shadow(color: .black.opacity(0.3), radius: 5)
                    
                    Text("DeNSFW")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Scan and remove NSFW content\nfrom your photo library")
                        .font(.caption)
                        .foregroundColor(Color.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 30)
                
                    HStack(spacing: 8) {
                        if modelLoader.isModelLoaded {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(Color(red: 0.4, green: 1.0, blue: 0.6))
                                .font(.system(size: 14))
                            Text("On-device AI model ready")
                                .font(.caption)
                                .foregroundColor(Color(red: 0.4, green: 1.0, blue: 0.6))
                        } else if modelLoader.loadingError != nil {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(Color(red: 1.0, green: 0.8, blue: 0.4))
                                .font(.system(size: 14))
                            Text("Model loading failed")
                                .font(.caption)
                                .foregroundColor(Color(red: 1.0, green: 0.8, blue: 0.4))
                        } else {
                            ProgressView()
                                .scaleEffect(0.7)
                                .tint(.white)
                            Text("Loading AI model...")
                                .font(.caption)
                                .foregroundColor(Color.white.opacity(0.6))
                        }
                    }
                    .padding(.top, 5)
                }
                
                Spacer()
                
                VStack(spacing: 12) {
                    HStack(spacing: 10) {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 20))
                            .foregroundColor(Color(red: 0.4, green: 0.8, blue: 1.0))
                        Text("Fully on-device processing. Your photos never leave your device.")
                            .font(.caption)
                            .foregroundColor(Color.white.opacity(0.9))
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    HStack(spacing: 10) {
                        Image(systemName: "wifi.slash")
                            .font(.system(size: 20))
                            .foregroundColor(Color(red: 0.4, green: 0.8, blue: 1.0))
                        Text("Works completely offline. No WiFi or mobile data required.")
                            .font(.caption)
                            .foregroundColor(Color.white.opacity(0.9))
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    HStack(spacing: 10) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 20))
                            .foregroundColor(Color(red: 0.4, green: 0.8, blue: 1.0))
                        Text("Lightning fast scanning with optimized AI model.")
                            .font(.caption)
                            .foregroundColor(Color.white.opacity(0.9))
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, 40)
                .padding(.vertical, 20)
                
                Button(action: handleScanButtonTap) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                        Text("Scan Gallery")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        modelLoader.isModelLoaded ? 
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 0.2, green: 0.6, blue: 1.0),
                                Color(red: 0.3, green: 0.7, blue: 1.0)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        ) : 
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.gray.opacity(0.3),
                                Color.gray.opacity(0.4)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .font(.headline)
                    .shadow(color: .black.opacity(0.3), radius: 5)
                }
                .padding(.horizontal, 40)
                .disabled(!modelLoader.isModelLoaded)
                
                Spacer()
            }
        }
        .fullScreenCover(isPresented: $showScanning) {
            ScanningView(photoManager: photoManager, modelLoader: modelLoader, isPresented: $showScanning)
        }
        .onAppear {
            photoManager.modelLoader = modelLoader
        }
        .alert("Permission Required", isPresented: $showPermissionAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("DeNSFW needs permission to scan your photo library for NSFW content. Please grant access in Settings.")
        }
    }
    
    private func handleScanButtonTap() {
        Task {
            photoManager.checkPhotoLibraryPermission()
            
            switch photoManager.authorizationStatus {
            case .authorized, .limited:
                showScanning = true
            case .notDetermined:
                await photoManager.requestPhotoLibraryPermission()
                if photoManager.authorizationStatus == .authorized || photoManager.authorizationStatus == .limited {
                    showScanning = true
                }
            case .denied, .restricted:
                showPermissionAlert = true
            @unknown default:
                break
            }
        }
    }
}

#Preview {
    ContentView()
}
