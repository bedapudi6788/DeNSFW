//
//  ResultsView.swift
//  DeNSFW
//
//  Created by Bedapudi Praneeth on 09/09/25.
//

import SwiftUI

struct ResultsView: View {
    @ObservedObject var photoManager: PhotoLibraryManager
    @Binding var isPresented: Bool
    @State private var showDeleteConfirmation = false
    @State private var allSelected = false
    
    let columns = [
        GridItem(.adaptive(minimum: 100, maximum: 150))
    ]
    
    var selectedCount: Int {
        photoManager.getSelectedPhotos().count
    }
    
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
                
                VStack {
                    if photoManager.nsfwPhotos.isEmpty {
                        VStack(spacing: 20) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(Color(red: 0.4, green: 1.0, blue: 0.6))
                                .shadow(color: .black.opacity(0.3), radius: 5)
                            
                            Text("All NSFW photos have been removed")
                                .font(.title3)
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(photoManager.nsfwPhotos.indices, id: \.self) { index in
                                PhotoGridItem(
                                    photo: photoManager.nsfwPhotos[index],
                                    isSelected: photoManager.nsfwPhotos[index].isSelected
                                ) {
                                    photoManager.togglePhotoSelection(at: index)
                                    updateSelectAllState()
                                }
                            }
                        }
                        .padding()
                    }
                    
                    VStack(spacing: 15) {
                        HStack {
                            Button(action: toggleSelectAll) {
                                HStack {
                                    Image(systemName: allSelected ? "checkmark.square.fill" : "square")
                                    Text("Select All")
                                }
                            }
                            .foregroundColor(Color(red: 0.4, green: 0.8, blue: 1.0))
                            
                            Spacer()
                            
                            if selectedCount > 0 {
                                Text("\(selectedCount) selected")
                                    .foregroundColor(Color.white.opacity(0.7))
                            }
                        }
                        
                        Button(action: {
                            if selectedCount > 0 {
                                showDeleteConfirmation = true
                            }
                        }) {
                            HStack {
                                Image(systemName: "trash")
                                Text("Delete Selected (\(selectedCount))")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                selectedCount > 0 ? 
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color(red: 0.8, green: 0.3, blue: 0.3),
                                        Color(red: 0.9, green: 0.4, blue: 0.4)
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ) : 
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.gray.opacity(0.2),
                                        Color.gray.opacity(0.3)
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .shadow(color: .black.opacity(0.3), radius: 3)
                        }
                        .disabled(selectedCount == 0)
                    }
                    .padding()
                    .background(Color(red: 0.1, green: 0.15, blue: 0.25).opacity(0.8))
                    .shadow(radius: 5)
                }
                }
            }
            .navigationTitle("NSFW Photos Detected")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        isPresented = false
                    }
                    .foregroundColor(Color(red: 0.4, green: 0.8, blue: 1.0))
                }
            }
            .toolbarBackground(Color(red: 0.07, green: 0.13, blue: 0.26), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .alert("Delete Photos", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    Task {
                        await deleteSelectedPhotos()
                    }
                }
            } message: {
                Text("Are you sure you want to permanently delete \(selectedCount) photo(s)? This action cannot be undone.")
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    private func toggleSelectAll() {
        if allSelected {
            photoManager.deselectAllPhotos()
        } else {
            photoManager.selectAllPhotos()
        }
        allSelected.toggle()
    }
    
    private func updateSelectAllState() {
        allSelected = photoManager.nsfwPhotos.allSatisfy { $0.isSelected }
    }
    
    private func deleteSelectedPhotos() async {
        let photosToDelete = photoManager.getSelectedPhotos()
        do {
            try await photoManager.deleteSelectedPhotos(photosToDelete)
            allSelected = false
        } catch {
            print("Error deleting photos: \(error)")
        }
    }
}

struct PhotoGridItem: View {
    let photo: PhotoItem
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            if let image = photo.image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 100, height: 100)
                    .clipped()
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? Color(red: 0.4, green: 0.8, blue: 1.0) : Color.clear, lineWidth: 3)
                    )
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 100, height: 100)
            }
            
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isSelected ? Color(red: 0.4, green: 0.8, blue: 1.0) : .white)
                .background(Circle().fill(Color.black.opacity(0.5)))
                .padding(5)
        }
        .onTapGesture {
            action()
        }
    }
}