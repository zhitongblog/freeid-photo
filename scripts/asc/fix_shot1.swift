import SwiftUI
import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// Re-renders ONLY the headline band of screenshot #1 to remove the price
// reference ("Truly free" / "真正免费") flagged under App Store guideline 2.3.7.
// The face/photo pixels below the band are copied verbatim from the original,
// so the marketing image is unchanged except for the headline text.

let brand = LinearGradient(colors:[Color(red:0.36,green:0.56,blue:0.98),Color(red:0.62,green:0.40,blue:0.96)],startPoint:.leading,endPoint:.trailing)
let bg = LinearGradient(colors:[Color(red:0.93,green:0.95,blue:1.0),Color(red:0.90,green:0.92,blue:0.99)],startPoint:.top,endPoint:.bottom)

// Same top layout as the original Shot (screenshots.swift), content/watermark dropped.
struct TopShot: View {
  let head:String; let sub:String
  var body: some View {
    ZStack { bg
      VStack(spacing:0){
        Spacer().frame(height:90)
        Text(head).font(.system(size:62,weight:.heavy,design:.rounded)).foregroundStyle(Color(white:0.12)).multilineTextAlignment(.center).padding(.horizontal,40).fixedSize(horizontal:false,vertical:true)
        Text(sub).font(.system(size:30,weight:.medium)).foregroundStyle(brand).padding(.top,14).multilineTextAlignment(.center).padding(.horizontal,40)
        Spacer()
      }
    }.frame(width:645,height:1398)
  }
}

let bandTopPx = 760  // rows [0, bandTopPx) replaced; face/photo starts below this

func loadCG(_ p:String) -> CGImage {
  let src = CGImageSourceCreateWithURL(URL(fileURLWithPath:p) as CFURL, nil)!
  return CGImageSourceCreateImageAtIndex(src, 0, nil)!
}

@MainActor func render(_ v: some View) -> CGImage {
  let r = ImageRenderer(content: v); r.scale = 2
  return r.nsImage!.cgImage(forProposedRect: nil, context: nil, hints: nil)!
}

func writePNG(_ img: CGImage, _ p:String) {
  let dst = CGImageDestinationCreateWithURL(URL(fileURLWithPath:p) as CFURL, UTType.png.identifier as CFString, 1, nil)!
  CGImageDestinationAddImage(dst, img, nil)
  CGImageDestinationFinalize(dst)
  print("wrote", p)
}

@MainActor func fix(orig path:String, head:String, sub:String) {
  let original = loadCG(path)
  let W = original.width, H = original.height          // 1290 x 2796
  let top = render(TopShot(head:head, sub:sub))        // 1290 x 2796 full render
  // crop the band (top-left origin for CGImage cropping)
  let band = top.cropping(to: CGRect(x:0,y:0,width:W,height:bandTopPx))!

  let cs = CGColorSpaceCreateDeviceRGB()
  let ctx = CGContext(data:nil,width:W,height:H,bitsPerComponent:8,bytesPerRow:0,
                      space:cs,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
  // CG context origin is bottom-left.
  ctx.draw(original, in: CGRect(x:0,y:0,width:W,height:H))
  // place band at the TOP of the image
  ctx.draw(band, in: CGRect(x:0, y:H-bandTopPx, width:W, height:bandTopPx))
  let out = ctx.makeImage()!
  writePNG(out, path)
}

MainActor.assumeIsolated {
  let dir = CommandLine.arguments[1]
  fix(orig: dir+"/ss_en_1.png", head:"Framed right,\nevery time", sub:"Line up · shoot · compliant")
  fix(orig: dir+"/ss_zh_1.png", head:"精准取景\n合规证件照",        sub:"对准头肩 · 一拍即合规")
}
