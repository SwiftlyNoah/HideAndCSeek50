//
//  UIImage+Compression.swift
//  HideAndCSeek50
//
//  Created by Noah Brauner on 11/29/25.
//

import UIKit

extension UIImage {
    /// Compress image to JPEG data with target file size
    /// - Parameters:
    ///   - maxSizeInMB: Maximum size in megabytes (default: 5MB)
    ///   - compressionQuality: Initial compression quality (0.0 to 1.0, default: 0.7)
    /// - Returns: Compressed JPEG data, or nil if compression fails
    func compressedJPEGData(maxSizeInMB: Double = 5.0, compressionQuality: CGFloat = 0.7) -> Data? {
        let maxSizeInBytes = Int(maxSizeInMB * 1024 * 1024)
        
        var currentQuality = compressionQuality
        var imageData = self.jpegData(compressionQuality: currentQuality)
        
        // If image is already under the size limit, return it
        if let data = imageData, data.count <= maxSizeInBytes {
            return data
        }
        
        // Iteratively reduce quality until under size limit
        var attempts = 0
        let maxAttempts = 10
        
        while attempts < maxAttempts {
            guard let data = imageData, data.count > maxSizeInBytes else {
                break
            }
            
            currentQuality -= 0.1
            
            if currentQuality < 0.1 {
                // If quality is too low, resize the image
                let scale = sqrt(Double(maxSizeInBytes) / Double(data.count))
                let newSize = CGSize(
                    width: size.width * scale,
                    height: size.height * scale
                )
                
                if let resizedImage = resize(to: newSize) {
                    imageData = resizedImage.jpegData(compressionQuality: 0.7)
                }
                break
            }
            
            imageData = self.jpegData(compressionQuality: currentQuality)
            attempts += 1
        }
        
        return imageData
    }
    
    /// Resize image to target size while maintaining aspect ratio
    /// - Parameter targetSize: The target size
    /// - Returns: Resized image, or nil if resize fails
    func resize(to targetSize: CGSize) -> UIImage? {
        let size = self.size
        
        let widthRatio  = targetSize.width  / size.width
        let heightRatio = targetSize.height / size.height
        
        // Determine which dimension to scale by
        let scaleFactor = min(widthRatio, heightRatio)
        
        let scaledSize = CGSize(
            width: size.width * scaleFactor,
            height: size.height * scaleFactor
        )
        
        let renderer = UIGraphicsImageRenderer(size: scaledSize)
        let scaledImage = renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: scaledSize))
        }
        
        return scaledImage
    }
    
    /// Get orientation-corrected image
    /// - Returns: Image with correct orientation
    func fixOrientation() -> UIImage {
        if imageOrientation == .up {
            return self
        }
        
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: CGRect(origin: .zero, size: size))
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return normalizedImage ?? self
    }
}
