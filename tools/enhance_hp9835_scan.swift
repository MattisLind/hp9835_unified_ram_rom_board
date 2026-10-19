// Deterministic enhancement of the unmodified JPEG embedded in PDF page 1.
// Run from the project root with:
// swift -module-cache-path /tmp/hp9835-swift-cache tools/enhance_hp9835_scan.swift
import Foundation
import AppKit
let folder = "requirements/enhanced/HP9835_Schematics_1977_02_07"
let src = NSBitmapImageRep(data: try Data(contentsOf: URL(fileURLWithPath: "\(folder)/page1_embedded_original.jpg")))!
let w=src.pixelsWide, h=src.pixelsHigh
precondition(src.bitsPerSample==8 && !src.isPlanar && src.samplesPerPixel>=3)
print("Original raster: \(w)x\(h), \(src.samplesPerPixel) samples per pixel, \(src.bitsPerPixel) bits per pixel, row \(src.bytesPerRow)")
func save(_ cg: CGImage, _ name: String) throws {
 let rep=NSBitmapImageRep(cgImage:cg)
 try rep.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:"\(folder)/\(name).png"))
}
let crops:[(String,CGRect)]=[
 ("controls_tracing",CGRect(x:1050,y:800,width:1500,height:690)),
 ("connector_column",CGRect(x:2150,y:160,width:390,height:1350)),
 ("controls",CGRect(x:1880,y:780,width:650,height:710)),
 ("controls_close",CGRect(x:2140,y:820,width:390,height:650)),
 ("bus",CGRect(x:2150,y:160,width:390,height:670))]
try save(src.cgImage!, "page1_original_pixels")
for (name,rect) in crops { try save(src.cgImage!.cropping(to:rect)!,"\(name)_original_pixels") }
// Red-channel levels (also valid for grayscale source pixels). White stays white; all
// transformations are pointwise, with no denoising, inpainting or OCR redraw.
for (name,blackPoint) in [("red_moderate",190),("red_strong",225),("red_extreme",240)] {
 let dst=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:w,pixelsHigh:h,bitsPerSample:8,samplesPerPixel:1,hasAlpha:false,isPlanar:false,colorSpaceName:.deviceWhite,bytesPerRow:w,bitsPerPixel:8)!
 let input=src.bitmapData!,output=dst.bitmapData!
 for y in 0..<h {
  for x in 0..<w {
   let red=Int(input[y*src.bytesPerRow+x*(src.bitsPerPixel/8)])
   output[y*dst.bytesPerRow+x]=UInt8(max(0,min(255,(red-blackPoint)*255/(255-blackPoint))))
  }
 }
 try save(dst.cgImage!,"page1_\(name)")
 for (crop,rect) in crops { try save(dst.cgImage!.cropping(to:rect)!,"\(crop)_\(name)") }
}
