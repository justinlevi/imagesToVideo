//
//  TimeLapseBuilder.swift
//
//  Created by Adam Jensen on 5/10/15.
//  Copyright (c) 2015 Adam Jensen. All rights reserved.
//

import AVFoundation
import UIKit

let kErrorDomain = "TimeLapseBuilder"
let kFailedToStartAssetWriterError = 0
let kFailedToAppendPixelBufferError = 1

public class TimeLapseBuilder: NSObject {
  let photoURLs: [String]
  var videoWriter: AVAssetWriter?
  var outputSize = CGSizeMake(1920, 1080)
  
  public init(photoURLs: [String]) {
    self.photoURLs = photoURLs
    
    super.init()
  }
  
  public func build(outputSize outputSize: CGSize, progress: (NSProgress -> Void), success: (NSURL -> Void), failure: (NSError -> Void)) {

    self.outputSize = outputSize
    var error: NSError?
    
    let startTime = NSDate.timeIntervalSinceReferenceDate()
    
    let fileManager = NSFileManager.defaultManager()
    let urls = fileManager.URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask)
    guard let documentDirectory: NSURL = urls.first else {
      fatalError("documentDir Error")
    }
    
    let videoOutputURL = documentDirectory.URLByAppendingPathComponent("AssembledVideo.mov")
    
    if NSFileManager.defaultManager().fileExistsAtPath(videoOutputURL.path!) {
      do {
        try NSFileManager.defaultManager().removeItemAtPath(videoOutputURL.path!)
      }catch{
        fatalError("Unable to delete file: \(error) : \(__FUNCTION__).")
      }
    }
    
    guard let videoWriter = try? AVAssetWriter(URL: videoOutputURL, fileType: AVFileTypeQuickTimeMovie) else{
      fatalError("AVAssetWriter error")
    }
    
    let outputSettings = [
      AVVideoCodecKey  : AVVideoCodecH264,
      AVVideoWidthKey  : NSNumber(float: Float(outputSize.width)),
      AVVideoHeightKey : NSNumber(float: Float(outputSize.height)),
    ]
    
    guard videoWriter.canApplyOutputSettings(outputSettings, forMediaType: AVMediaTypeVideo) else {
      fatalError("Negative : Can't apply the Output settings...")
    }
    
    let videoWriterInput = AVAssetWriterInput(mediaType: AVMediaTypeVideo, outputSettings: outputSettings)
    
    let sourcePixelBufferAttributesDictionary = [
      kCVPixelBufferPixelFormatTypeKey as String: NSNumber(unsignedInt: kCVPixelFormatType_32ARGB),
      kCVPixelBufferWidthKey as String: NSNumber(float: Float(outputSize.width)),
      kCVPixelBufferHeightKey as String: NSNumber(float: Float(outputSize.height)),
    ]
    
    let pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
      assetWriterInput: videoWriterInput,
      sourcePixelBufferAttributes: sourcePixelBufferAttributesDictionary
    )
    
    assert(videoWriter.canAddInput(videoWriterInput))
    videoWriter.addInput(videoWriterInput)
    
    if videoWriter.startWriting() {
      videoWriter.startSessionAtSourceTime(kCMTimeZero)
      assert(pixelBufferAdaptor.pixelBufferPool != nil)
      
      let media_queue = dispatch_queue_create("mediaInputQueue", nil)
      
      videoWriterInput.requestMediaDataWhenReadyOnQueue(media_queue, usingBlock: { () -> Void in
        let fps: Int32 = 1
        let frameDuration = CMTimeMake(1, fps)
        let currentProgress = NSProgress(totalUnitCount: Int64(self.photoURLs.count))
        
        var frameCount: Int64 = 0
        var remainingPhotoURLs = [String](self.photoURLs)
        
        
        while (!remainingPhotoURLs.isEmpty) {
          //print("\(videoWriterInput.readyForMoreMediaData) : \(remainingPhotoURLs.count)")
          
          if (videoWriterInput.readyForMoreMediaData) {
            let nextPhotoURL = remainingPhotoURLs.removeAtIndex(0)
            let lastFrameTime = CMTimeMake(frameCount, fps)
            let presentationTime = frameCount == 0 ? lastFrameTime : CMTimeAdd(lastFrameTime, frameDuration)
            
            
            if !self.appendPixelBufferForImageAtURL(nextPhotoURL, pixelBufferAdaptor: pixelBufferAdaptor, presentationTime: presentationTime) {
              error = NSError(domain: kErrorDomain, code: kFailedToAppendPixelBufferError,
                userInfo: [
                  "description": "AVAssetWriterInputPixelBufferAdapter failed to append pixel buffer",
                  "rawError": videoWriter.error ?? "(none)"
                ])
              
              break
            }
            
            frameCount++
            
            //print("\(CMTimeGetSeconds(presentationTime)) : \(currentProgress.completedUnitCount)|\(currentProgress.totalUnitCount)")
            
            currentProgress.completedUnitCount = frameCount
            progress(currentProgress)
          }
        }
        
        let endTime = NSDate.timeIntervalSinceReferenceDate()
        let elapsedTime: NSTimeInterval = endTime - startTime
        
        print("rendering time \(self.stringFromTimeInterval(elapsedTime))")

        
        videoWriterInput.markAsFinished()
        videoWriter.finishWritingWithCompletionHandler { () -> Void in
          if error == nil {
            success(videoOutputURL)
          }
        }
      })
      

    } else {
      error = NSError(domain: kErrorDomain, code: kFailedToStartAssetWriterError,
        userInfo: ["description": "AVAssetWriter failed to start writing"]
      )
    }
    
    if let error = error {
      failure(error)
    }
  }
  
  public func appendPixelBufferForImageAtURL(urlString: String, pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor, presentationTime: CMTime) -> Bool {
    var appendSucceeded = true
    
    autoreleasepool {
      
      if let image = UIImage(contentsOfFile: urlString) {
        var pixelBuffer: CVPixelBuffer? = nil
        let status: CVReturn = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pixelBufferAdaptor.pixelBufferPool!, &pixelBuffer)

        if let pixelBuffer = pixelBuffer where status == 0 {
          let managedPixelBuffer = pixelBuffer

          fillPixelBufferFromImage(image, pixelBuffer: managedPixelBuffer, contentMode: UIViewContentMode.ScaleAspectFit)

          appendSucceeded = pixelBufferAdaptor.appendPixelBuffer(pixelBuffer, withPresentationTime: presentationTime)

        } else {
          NSLog("error: Failed to allocate pixel buffer from pool")
        }
      }
    }
    
    return appendSucceeded
  }
  
  // http://stackoverflow.com/questions/7645454

  func fillPixelBufferFromImage(image: UIImage, pixelBuffer: CVPixelBuffer, contentMode:UIViewContentMode){

    CVPixelBufferLockBaseAddress(pixelBuffer, 0)
    
    let data = CVPixelBufferGetBaseAddress(pixelBuffer)
    let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
    let context = CGBitmapContextCreate(data, Int(self.outputSize.width), Int(self.outputSize.height), 8, CVPixelBufferGetBytesPerRow(pixelBuffer), rgbColorSpace, CGImageAlphaInfo.PremultipliedFirst.rawValue)
    
    CGContextClearRect(context, CGRectMake(0, 0, CGFloat(self.outputSize.width), CGFloat(self.outputSize.height)))
    
    let horizontalRatio = CGFloat(self.outputSize.width) / image.size.width
    let verticalRatio = CGFloat(self.outputSize.height) / image.size.height
    var ratio: CGFloat = 1
    
    switch(contentMode) {
    case .ScaleAspectFill:
      ratio = max(horizontalRatio, verticalRatio)
    case .ScaleAspectFit:
      ratio = min(horizontalRatio, verticalRatio)
    default:
      ratio = min(horizontalRatio, verticalRatio)
    }
    
    let newSize:CGSize = CGSizeMake(image.size.width * ratio, image.size.height * ratio)
    
    let x = newSize.width < self.outputSize.width ? (self.outputSize.width - newSize.width) / 2 : 0
    let y = newSize.height < self.outputSize.height ? (self.outputSize.height - newSize.height) / 2 : 0
    
    CGContextDrawImage(context, CGRectMake(x, y, newSize.width, newSize.height), image.CGImage)
    
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0)
  }
  
  
  func stringFromTimeInterval(interval: NSTimeInterval) -> String {
    let ti = NSInteger(interval)
    let ms = Int((interval % 1) * 1000)
    let seconds = ti % 60
    let minutes = (ti / 60) % 60
    let hours = (ti / 3600)
    
    if hours > 0 {
      return NSString(format: "%0.2d:%0.2d:%0.2d.%0.2d", hours, minutes, seconds, ms) as String
    }else if minutes > 0 {
      return NSString(format: "%0.2d:%0.2d.%0.2d", minutes, seconds, ms) as String
    }else {
      return NSString(format: "%0.2d.%0.2d", seconds, ms) as String
    }
  }

}
