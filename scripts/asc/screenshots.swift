import SwiftUI
import AppKit

let brand = LinearGradient(colors:[Color(red:0.36,green:0.56,blue:0.98),Color(red:0.62,green:0.40,blue:0.96)],startPoint:.leading,endPoint:.trailing)
let bg = LinearGradient(colors:[Color(red:0.93,green:0.95,blue:1.0),Color(red:0.90,green:0.92,blue:0.99)],startPoint:.top,endPoint:.bottom)

func wm(_ s:CGFloat)->some View{HStack(spacing:0){Text("do").foregroundStyle(Color(white:0.2));Text("ai").foregroundStyle(brand);Text("pm").foregroundStyle(Color(white:0.2));Text(".").foregroundStyle(brand)}.font(.system(size:s,weight:.heavy,design:.rounded))}

// --- guide overlay content (reuse from app geometry) ---
private enum Bust{static func nh(_ h:CGRect)->CGFloat{h.width*0.24};static func ny(_ h:CGRect)->CGFloat{h.maxY-h.height*0.02};static func ins(_ f:CGRect)->CGFloat{f.width*0.05}}
struct Shoulders:Shape{let hr:CGRect;let f:CGRect;func path(in r:CGRect)->Path{var p=Path();let nh=Bust.nh(hr),ny=Bust.ny(hr),b=f.maxY,d=b-ny,lx=f.minX+Bust.ins(f),rx=f.maxX-Bust.ins(f)
 p.move(to:CGPoint(x:hr.midX-nh,y:ny));p.addCurve(to:CGPoint(x:lx,y:b),control1:CGPoint(x:hr.midX-nh,y:ny+d*0.42),control2:CGPoint(x:lx,y:b-d*0.55))
 p.move(to:CGPoint(x:hr.midX+nh,y:ny));p.addCurve(to:CGPoint(x:rx,y:b),control1:CGPoint(x:hr.midX+nh,y:ny+d*0.42),control2:CGPoint(x:rx,y:b-d*0.55));return p}}
struct GuideContent:View{ var body:some View{
  GeometryReader{geo in
    let aspect=0.688, headFrac=0.635, eyeFB=0.656
    let fw=min(geo.size.width*0.82, geo.size.height*0.62*aspect); let fh=fw/aspect
    let fr=CGRect(x:(geo.size.width-fw)/2,y:geo.size.height*0.46-fh/2,width:fw,height:fh)
    let hh=fh*headFrac,hw=hh*0.74,eyeY=fr.maxY-fh*eyeFB,hcy=eyeY-hh*0.46+hh/2
    let hr=CGRect(x:fr.midX-hw/2,y:hcy-hh/2,width:hw,height:hh)
    let dash=StrokeStyle(lineWidth:4,lineCap:.round,lineJoin:.round,dash:[14,11])
    ZStack{
      Image(nsImage:NSImage(contentsOfFile:"/tmp/face2.jpg")!).resizable().scaledToFill().frame(width:geo.size.width,height:geo.size.height).clipped()
      Path{p in p.addRect(CGRect(origin:.zero,size:geo.size));p.addRoundedRect(in:fr,cornerSize:CGSize(width:20,height:20))}.fill(.black.opacity(0.45),style:FillStyle(eoFill:true))
      Ellipse().stroke(.white.opacity(0.95),style:dash).frame(width:hw,height:hh).position(x:hr.midX,y:hr.midY)
      Shoulders(hr:hr,f:fr).stroke(.white.opacity(0.95),style:dash)
      RoundedRectangle(cornerRadius:20).stroke(.white.opacity(0.9),lineWidth:3).frame(width:fw,height:fh).position(x:fr.midX,y:fr.midY)
    }
  }
}}

struct ColorsContent:View{ var body:some View{
  VStack(spacing:22){
    HStack(spacing:14){
      ForEach(["/tmp/out_cn.jpg","/tmp/bg_blue.jpg","/tmp/bg_red.jpg"],id:\.self){f in
        Image(nsImage:NSImage(contentsOfFile:f)!).resizable().scaledToFit().frame(width:150).clipShape(RoundedRectangle(cornerRadius:10)).shadow(radius:6)
      }
    }
    HStack(spacing:26){ ForEach([Color.white,Color(red:0.26,green:0.56,blue:0.86),Color(red:0.85,green:0,blue:0.1)],id:\.self){c in Circle().fill(c).frame(width:34,height:34).overlay(Circle().stroke(.gray.opacity(0.4))) } }
  }
}}

struct SpecsContent:View{
  let rows=[("🇨🇳","中国护照 / 一寸 / 二寸"),("🇺🇸","美国护照 / 签证 2×2"),("🇬🇧","英国护照"),("🇪🇺","申根签证"),("🇯🇵","日本签证"),("🇰🇷","韩国护照"),("🇮🇳","印度护照 / 签证"),("🇸🇬","新加坡护照")]
  var body:some View{
    VStack(spacing:0){
      ForEach(rows,id:\.1){r in
        HStack{Text(r.0).font(.system(size:30));Text(r.1).font(.system(size:26,weight:.medium)).foregroundStyle(Color(white:0.15));Spacer();Image(systemName:"checkmark.circle.fill").foregroundStyle(.green)}
          .padding(.vertical,16).padding(.horizontal,22)
        Divider()
      }
    }.background(.white).clipShape(RoundedRectangle(cornerRadius:22)).shadow(radius:8).padding(.horizontal,30)
  }
}

struct Shot<Content:View>:View{
  let head:String; let sub:String; let content:Content
  init(_ h:String,_ s:String,@ViewBuilder _ c:()->Content){head=h;sub=s;content=c()}
  var body:some View{
    ZStack{ bg
      VStack(spacing:0){
        Spacer().frame(height:90)
        Text(head).font(.system(size:62,weight:.heavy,design:.rounded)).foregroundStyle(Color(white:0.12)).multilineTextAlignment(.center).padding(.horizontal,40).fixedSize(horizontal:false,vertical:true)
        Text(sub).font(.system(size:30,weight:.medium)).foregroundStyle(brand).padding(.top,14).multilineTextAlignment(.center).padding(.horizontal,40)
        Spacer().frame(height:40)
        content.frame(maxWidth:.infinity,maxHeight:.infinity)
        Spacer().frame(height:30)
        wm(30).opacity(0.6).padding(.bottom,40)
      }
    }.frame(width:645,height:1398)
  }
}

@MainActor func snap<X:View>(_ v:X,_ p:String){let r=ImageRenderer(content:v);r.scale=2;if let i=r.nsImage,let t=i.tiffRepresentation,let b=NSBitmapImageRep(data:t),let png=b.representation(using:.png,properties:[:]){try? png.write(to:URL(fileURLWithPath:p));print("wrote",p)}}
MainActor.assumeIsolated{
  snap(Shot("真正免费的\n证件照","对准头肩 · 一拍即合规"){GuideContent()},"/tmp/ss_zh_1.png")
  snap(Shot("一键换底色","白 / 蓝 / 红 · 符合各国标准"){ColorsContent()},"/tmp/ss_zh_2.png")
  snap(Shot("10 国 · 16 种规格","全程本地处理 · 不上传"){SpecsContent()},"/tmp/ss_zh_3.png")
  snap(Shot("Truly free\nID photos","Line up · shoot · compliant"){GuideContent()},"/tmp/ss_en_1.png")
  snap(Shot("Swap the\nbackground","White / Blue / Red · per spec"){ColorsContent()},"/tmp/ss_en_2.png")
  snap(Shot("10 countries\n16 specs","All on-device · nothing uploaded"){SpecsContent()},"/tmp/ss_en_3.png")
}
