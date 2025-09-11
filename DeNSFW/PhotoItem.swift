//
//  PhotoItem.swift
//  DeNSFW
//
//  Created by Bedapudi Praneeth on 09/09/25.
//

import SwiftUI
import Photos

struct PhotoItem: Identifiable {
    let id = UUID()
    let asset: PHAsset
    var isSelected: Bool = false
    var image: UIImage?
}