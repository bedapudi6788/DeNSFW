//
//  PhotoLibraryManager.swift
//  DeNSFW
//
//  Created by Bedapudi Praneeth on 09/09/25.
//

import SwiftUI
import Photos

class PhotoLibraryManager: ObservableObject {
    @Published var authorizationStatus: PHAuthorizationStatus = .notDetermined
    @Published var scanProgress: Double = 0.0
    @Published var totalPhotos: Int = 0
    @Published var scannedPhotos: Int = 0
    @Published var nsfwPhotos: [PhotoItem] = []
    @Published var isScanning: Bool = false
    @Published var isLoadingModel: Bool = false
    @Published var modelLoader: ModelLoader?
    
    init() {
        checkPhotoLibraryPermission()
    }
    
    func checkPhotoLibraryPermission() {
        authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }
    
    func requestPhotoLibraryPermission() async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        await MainActor.run {
            self.authorizationStatus = status
        }
    }
    
    
    func scanPhotoLibrary() async {
        await MainActor.run {
            self.isScanning = true
            self.nsfwPhotos = []
            self.scanProgress = 0.0
            self.scannedPhotos = 0
        }
        
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let allPhotos = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        
        await MainActor.run {
            self.totalPhotos = allPhotos.count
        }
        
        var detectedPhotos: [PhotoItem] = []
        
        for index in 0..<allPhotos.count {
            let asset = allPhotos.object(at: index)
            
            // Load the actual image for classification
            let imageManager = PHImageManager.default()
            let options = PHImageRequestOptions()
            options.isSynchronous = true
            options.deliveryMode = .highQualityFormat
            
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                imageManager.requestImage(
                    for: asset,
                    targetSize: PHImageManagerMaximumSize,
                    contentMode: .aspectFit,
                    options: options
                ) { image, _ in
                    if let image = image {
                        // Use actual model classification
                        print("\n🔍 Scanning image \(index + 1)/\(allPhotos.count)")
                        
                        let result = self.modelLoader?.classifyImage(image) ?? (isNSFW: false, confidence: 0.0)
                        
                        if result.isNSFW {
                            print("⚠️ NSFW DETECTED - Confidence: \(String(format: "%.1f%%", result.confidence * 100))")
                            Task {
                                let photoItem = await self.loadPhotoItem(asset: asset)
                                detectedPhotos.append(photoItem)
                            }
                        } else {
                            print("✅ Safe image - NSFW score: \(String(format: "%.1f%%", result.confidence * 100))")
                        }
                    }
                    continuation.resume()
                }
            }
            
            // Small delay for UI responsiveness
            try? await Task.sleep(nanoseconds: 10_000_000)
            
            await MainActor.run {
                self.scannedPhotos = index + 1
                self.scanProgress = Double(self.scannedPhotos) / Double(self.totalPhotos)
            }
        }
        
        await MainActor.run {
            self.nsfwPhotos = detectedPhotos
            self.isScanning = false
        }
        
        // Final summary
        print("\n========================================")
        print("📊 SCAN COMPLETE SUMMARY:")
        print("  Total images scanned: \(allPhotos.count)")
        print("  NSFW images detected: \(detectedPhotos.count)")
        print("  Detection rate: \(String(format: "%.1f%%", Double(detectedPhotos.count) / Double(max(allPhotos.count, 1)) * 100))")
        print("========================================\n")
    }
    
    
    private func loadPhotoItem(asset: PHAsset) async -> PhotoItem {
        var photoItem = PhotoItem(asset: asset)
        
        let options = PHImageRequestOptions()
        options.isSynchronous = true
        options.deliveryMode = .highQualityFormat
        
        let imageManager = PHImageManager.default()
        let targetSize = CGSize(width: 300, height: 300)
        
        await withCheckedContinuation { continuation in
            imageManager.requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                photoItem.image = image
                continuation.resume()
            }
        }
        
        return photoItem
    }
    
    func deleteSelectedPhotos(_ photos: [PhotoItem]) async throws {
        let assetsToDelete = photos.map { $0.asset }
        
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets(NSArray(array: assetsToDelete))
        }
        
        await MainActor.run {
            self.nsfwPhotos.removeAll { photo in
                photos.contains { $0.id == photo.id }
            }
        }
    }
    
    func movePhotosToSecureFolder(_ photos: [PhotoItem]) async throws {
        let fileManager = FileManager.default
        guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw NSError(domain: "DeNSFW", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not find documents directory"])
        }

        let secureFolderURL = documentsDirectory.appendingPathComponent("SecureFolder")

        if !fileManager.fileExists(atPath: secureFolderURL.path) {
            try fileManager.createDirectory(at: secureFolderURL, withIntermediateDirectories: true)
        }

        var assetsToDelete: [PHAsset] = []

        for photo in photos {
            let asset = photo.asset

            // Get image data
            let data = await withCheckedContinuation { (continuation: CheckedContinuation<Data?, Never>) in
                let options = PHImageRequestOptions()
                options.isSynchronous = false
                options.deliveryMode = .highQualityFormat
                options.version = .current
                options.isNetworkAccessAllowed = true

                PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { data, _, _, _ in
                    continuation.resume(returning: data)
                }
            }

            if let data = data {
                // Generate filename
                // Try to get original filename if possible, otherwise UUID
                let resources = PHAssetResource.assetResources(for: asset)
                let filename = resources.first?.originalFilename ?? "\(UUID().uuidString).jpg"
                let fileURL = secureFolderURL.appendingPathComponent(filename)

                // Handle duplicate filenames
                let finalFileURL: URL
                if fileManager.fileExists(atPath: fileURL.path) {
                     let newFilename = "\(UUID().uuidString)_\(filename)"
                     finalFileURL = secureFolderURL.appendingPathComponent(newFilename)
                } else {
                    finalFileURL = fileURL
                }

                do {
                    try data.write(to: finalFileURL)
                    assetsToDelete.append(asset)
                } catch {
                    print("Error saving file: \(error)")
                }
            }
        }

        // Delete original photos
        if !assetsToDelete.isEmpty {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.deleteAssets(NSArray(array: assetsToDelete))
            }

            await MainActor.run {
                self.nsfwPhotos.removeAll { photo in
                    assetsToDelete.contains(where: { $0.localIdentifier == photo.asset.localIdentifier })
                }
            }
        }
    }

    func togglePhotoSelection(at index: Int) {
        nsfwPhotos[index].isSelected.toggle()
    }
    
    func selectAllPhotos() {
        for index in nsfwPhotos.indices {
            nsfwPhotos[index].isSelected = true
        }
    }
    
    func deselectAllPhotos() {
        for index in nsfwPhotos.indices {
            nsfwPhotos[index].isSelected = false
        }
    }
    
    func getSelectedPhotos() -> [PhotoItem] {
        return nsfwPhotos.filter { $0.isSelected }
    }
}