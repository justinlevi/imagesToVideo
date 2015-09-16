//
//  UIImageExtension.swift
//
//  Originally created by Trevor Harmon on 8/5/09
//  Translated to Swift by Daniel Park on 2/5/15.
//  Updated to Swift 2 by Justin Winter on 9/15/15.
//
//  Free for personal or commercial use, with or without modification
//  No warranty is expressed or implied

import Foundation
import UIKit
import AVFoundation

extension UIImage {

  // Returns a copy of this image that is cropped to the given bounds.
  // The bounds will be adjusted using CGRectIntegral.
  // This method ignores the image's imageOrientation setting.
  func croppedImage(bounds: CGRect) -> UIImage {
      let image = CGImageCreateWithImageInRect(self.CGImage, bounds)
      return UIImage(CGImage: image!)
  }

  func thumbnailImage(
      thumbnailSize: Int,
      transparentBorder borderSize:Int,
      cornerRadius:Int,
      interpolationQuality quality:CGInterpolationQuality
  ) -> UIImage {
      let resizedImage:UIImage = self.resizedImageWithContentMode(
          .ScaleAspectFill,
          bounds: CGSizeMake(CGFloat(thumbnailSize), CGFloat(thumbnailSize)),
          interpolationQuality: quality
      )
      let cropRect:CGRect = CGRectMake(
          round((resizedImage.size.width - CGFloat(thumbnailSize))/2),
          round((resizedImage.size.height - CGFloat(thumbnailSize))/2),
          CGFloat(thumbnailSize),
          CGFloat(thumbnailSize)
      )

      let croppedImage:UIImage = resizedImage.croppedImage(cropRect)
      return croppedImage
  }

  // Returns a rescaled copy of the image, taking into account its orientation
  // The image will be scaled disproportionately if necessary to fit the bounds specified by the parameter
  func resizedImage(newSize:CGSize, interpolationQuality quality:CGInterpolationQuality) -> UIImage {
    var drawTransposed:Bool

    switch(self.imageOrientation) {
    case .Left:
        fallthrough
    case .LeftMirrored:
        fallthrough
    case .Right:
        fallthrough
    case .RightMirrored:
        drawTransposed = true
        break
    default:
        drawTransposed = false
        break
    }

    return self.resizedImage(
        newSize,
        transform: self.transformForOrientation(newSize),
        drawTransposed: drawTransposed,
        interpolationQuality: quality
    )
  }

  func resizedImageWithContentMode(
    contentMode:UIViewContentMode,
    bounds:CGSize,
    interpolationQuality quality:CGInterpolationQuality
) -> UIImage {
    let horizontalRatio:CGFloat = bounds.width / self.size.width
    let verticalRatio:CGFloat = bounds.height / self.size.height
    var ratio:CGFloat = 1

    switch(contentMode) {
    case .ScaleAspectFill:
        ratio = max(horizontalRatio, verticalRatio)
        break
    case .ScaleAspectFit:
        ratio = min(horizontalRatio, verticalRatio)
        break
    default:
        print("Unsupported content mode \(contentMode)")
    }

    let newSize:CGSize = CGSizeMake(self.size.width * ratio, self.size.height * ratio)
    return self.resizedImage(newSize, interpolationQuality: quality)
  }

  func resizedImage(
    newSize:CGSize,
    transform:CGAffineTransform,
    drawTransposed transpose:Bool,
    interpolationQuality quality:CGInterpolationQuality
    ) -> UIImage {
        let newRect:CGRect = CGRectIntegral(CGRectMake(0, 0, newSize.width, newSize.height))
        let transposedRect:CGRect = CGRectMake(0, 0, newRect.size.height, newRect.size.width)
        let imageRef:CGImageRef = self.CGImage!

        // build a context that's the same dimensions as the new size
        let bitmap:CGContextRef = CGBitmapContextCreate(
            nil,
            Int(newRect.size.width),
            Int(newRect.size.height),
            CGImageGetBitsPerComponent(imageRef),
            0,
            CGImageGetColorSpace(imageRef),
            CGImageGetBitmapInfo(imageRef).rawValue
        )!

        // rotate and/or flip the image if required by its orientation
        CGContextConcatCTM(bitmap, transform)

        // set the quality level to use when rescaling
        CGContextSetInterpolationQuality(bitmap, quality)

        // draw into the context; this scales the image
        CGContextDrawImage(bitmap, transpose ? transposedRect : newRect, imageRef)

        // get the resized image from the context and a UIImage
        let newImageRef = CGBitmapContextCreateImage(bitmap)!
        let newImage:UIImage = UIImage(CGImage: newImageRef)

        return newImage
  }

  func transformForOrientation(newSize:CGSize) -> CGAffineTransform {
    var transform:CGAffineTransform = CGAffineTransformIdentity
    switch (self.imageOrientation) {
    case .Down:          // EXIF = 3
        fallthrough
    case .DownMirrored:  // EXIF = 4
        transform = CGAffineTransformTranslate(transform, newSize.width, newSize.height)
        transform = CGAffineTransformRotate(transform, CGFloat(M_PI))
        break
    case .Left:          // EXIF = 6
        fallthrough
    case .LeftMirrored:  // EXIF = 5
        transform = CGAffineTransformTranslate(transform, newSize.width, 0)
        transform = CGAffineTransformRotate(transform, CGFloat(M_PI_2))
        break
    case .Right:         // EXIF = 8
        fallthrough
    case .RightMirrored: // EXIF = 7
        transform = CGAffineTransformTranslate(transform, 0, newSize.height)
        transform = CGAffineTransformRotate(transform, -CGFloat(M_PI_2))
        break
    default:
        break
    }

    switch(self.imageOrientation) {
    case .UpMirrored:    // EXIF = 2
        fallthrough
    case .DownMirrored:  // EXIF = 4
        transform = CGAffineTransformTranslate(transform, newSize.width, 0)
        transform = CGAffineTransformScale(transform, -1, 1)
        break
    case .LeftMirrored:  // EXIF = 5
        fallthrough
    case .RightMirrored: // EXIF = 7
        transform = CGAffineTransformTranslate(transform, newSize.height, 0)
        transform = CGAffineTransformScale(transform, -1, 1)
        break
    default:
        break
    }

    return transform
  }
  
  func imageScaledToFitToSize(size:CGSize) -> UIImage {
    let scaledRect = AVMakeRectWithAspectRatioInsideRect(self.size, CGRectMake(0, 0, size.width, size.height))
    UIGraphicsBeginImageContextWithOptions(size, false, 0)
    self.drawInRect(scaledRect)
    let scaledImage = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    return scaledImage
  }

}
