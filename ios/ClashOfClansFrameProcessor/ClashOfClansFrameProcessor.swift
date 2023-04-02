import CoreML
import UIKit

@objc(ClashOfClansFrameProcessorPlugin)
public class ClashOfClansFrameProcessorPlugin: NSObject, FrameProcessorPluginBase {
  // Static variable to hold the coreml model
  static var coreMLModel: best!
  
  static func loadCoreMLModel() throws {
    let model = try best()
    self.coreMLModel = model
  }
  
  
  @objc public static func callback(_ frame: Frame!, withArgs _: [Any]!) -> Any! {
    if coreMLModel == nil {
      do {
        try loadCoreMLModel()
      } catch {
        print("Error loading coreml model: \(error.localizedDescription)")
        return ["Error loading coreml model: \(error.localizedDescription)"]
      }
    }
    
    let buffer = frame.buffer!
    let orientation = frame.orientation
    
    guard let imageBuffer = CMSampleBufferGetImageBuffer(buffer) else { return nil }
    
    let ciImage = CIImage(cvPixelBuffer: imageBuffer)
    let context = CIContext(options: nil)
    
    guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
    
    let image = UIImage(cgImage: cgImage)
    
    let resizedImage = image.resize(to: CGSize(width: 800, height: 800))
    
    guard let pixelBuffer = resizedImage.toCVPixelBuffer() else {
      print("Error: Failed to convert UIImage to CVPixelBuffer.")
      return nil
    }
    
    
    
    let results = try? self.coreMLModel.prediction(image: pixelBuffer, iouThreshold: 0.3, confidenceThreshold: 0.3)
    
    return convertToReactNativeCoordinates(mlMultiArray: results!.coordinates)
  }
  
  static func convertToReactNativeCoordinates(mlMultiArray: MLMultiArray) -> [[String: Float]] {
    let count = mlMultiArray.count / 4
    var coordinates = [[String: Float]]()
    
    for i in 0..<count {
      let x = mlMultiArray[i * 4].floatValue
      let y = mlMultiArray[i * 4 + 1].floatValue
      let width = mlMultiArray[i * 4 + 2].floatValue
      let height = mlMultiArray[i * 4 + 3].floatValue
      
      let coordinate = [
        "x": x,
        "y": y,
        "width": width,
        "height": height
      ]
      
      coordinates.append(coordinate)
    }
    
    return coordinates
  }
  
  static func saveSampleBufferAsJPEG(sampleBuffer: CMSampleBuffer) {
    let uuid = UUID().uuidString
    let documentsUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    let imageUrl = documentsUrl.appendingPathComponent("sample_image_\(uuid).jpg")
    
    guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
      print("Error getting pixel buffer from sample buffer")
      return
    }
    
    CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
    
    let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer)
    let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
    let width = CVPixelBufferGetWidth(pixelBuffer)
    let height = CVPixelBufferGetHeight(pixelBuffer)
    
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
    
    guard let context = CGContext(data: baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo.rawValue) else {
      print("Error creating CGContext from pixel buffer")
      return
    }
    
    guard let cgImage = context.makeImage() else {
      print("Error creating CGImage from CGContext")
      return
    }
    
    let image = UIImage(cgImage: cgImage)
    
    guard let imageData = image.jpegData(compressionQuality: 1.0) else {
      print("Error creating JPEG data from UIImage")
      return
    }
    
    do {
      try imageData.write(to: imageUrl)
      print("Saved JPEG image to \(imageUrl.absoluteString)")
    } catch {
      print("Error saving JPEG image: \(error.localizedDescription)")
    }
    
    CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
  }
  
  static func convertSampleBufferToPixelBuffer(sampleBuffer: CMSampleBuffer) -> CVPixelBuffer? {
    // Get the image buffer from the sample buffer
    guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
      return nil
    }
    
    // Lock the base address of the pixel buffer
    CVPixelBufferLockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: 0))
    
    // Get the base address of the pixel buffer
    let baseAddress = CVPixelBufferGetBaseAddress(imageBuffer)
    
    // Get the width and height of the pixel buffer
    let width = CVPixelBufferGetWidth(imageBuffer)
    let height = CVPixelBufferGetHeight(imageBuffer)
    
    // Get the bytes per row of the pixel buffer
    let bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer)
    
    // Create a pixel buffer with the same dimensions as the image buffer
    var pixelBuffer: CVPixelBuffer?
    let status = CVPixelBufferCreateWithBytes(nil, width, height, kCVPixelFormatType_32BGRA, baseAddress!, bytesPerRow, nil, nil, nil, &pixelBuffer)
    
    // Unlock the base address of the pixel buffer
    CVPixelBufferUnlockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: 0))
    
    // Return the pixel buffer
    return pixelBuffer
  }
  
  static func resizePixelBuffer(_ pixelBuffer: CVPixelBuffer, to size: CGSize) -> CVPixelBuffer? {
    let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
    let context = CIContext()
    let scaleX = size.width / CGFloat(CVPixelBufferGetWidth(pixelBuffer))
    let scaleY = size.height / CGFloat(CVPixelBufferGetHeight(pixelBuffer))
    let scale = min(scaleX, scaleY)
    let filter = CIFilter(name: "CILanczosScaleTransform")!
    filter.setValue(ciImage, forKey: kCIInputImageKey)
    filter.setValue(scale, forKey: kCIInputScaleKey)
    filter.setValue(1.0, forKey: kCIInputAspectRatioKey)
    var outputPixelBuffer: CVPixelBuffer?
    CVPixelBufferCreate(nil, Int(size.width), Int(size.height), CVPixelBufferGetPixelFormatType(pixelBuffer), nil, &outputPixelBuffer)
    guard let output = outputPixelBuffer else {
      return nil
    }
    context.render(filter.outputImage!, to: output)
    return output
  }
}

extension UIImage {
  func resize(to size: CGSize) -> UIImage {
    UIGraphicsBeginImageContextWithOptions(size, false, UIScreen.main.scale)
    self.draw(in: CGRect(origin: .zero, size: size))
    let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    return resizedImage ?? self
  }
  
  func toCVPixelBuffer() -> CVPixelBuffer? {
    let attrs = [
      kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
      kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue
    ] as CFDictionary
    
    var pixelBuffer: CVPixelBuffer?
    let status = CVPixelBufferCreate(kCFAllocatorDefault,
                                     Int(self.size.width),
                                     Int(self.size.height),
                                     kCVPixelFormatType_32ARGB,
                                     attrs,
                                     &pixelBuffer)
    
    guard let resultPixelBuffer = pixelBuffer, status == kCVReturnSuccess else {
      return nil
    }
    
    CVPixelBufferLockBaseAddress(resultPixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
    let pixelData = CVPixelBufferGetBaseAddress(resultPixelBuffer)
    
    let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
    guard let context = CGContext(data: pixelData,
                                  width: Int(self.size.width),
                                  height: Int(self.size.height),
                                  bitsPerComponent: 8,
                                  bytesPerRow: CVPixelBufferGetBytesPerRow(resultPixelBuffer),
                                  space: rgbColorSpace,
                                  bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)
    else {
      return nil
    }
    
    context.translateBy(x: 0, y: self.size.height)
    context.scaleBy(x: 1.0, y: -1.0)
    
    UIGraphicsPushContext(context)
    self.draw(in: CGRect(x: 0, y: 0, width: self.size.width, height: self.size.height))
    UIGraphicsPopContext()
    
    CVPixelBufferUnlockBaseAddress(resultPixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
    
    return resultPixelBuffer
  }
}
