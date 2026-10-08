import AppKit
let side = 1024
let image = NSImage(size: NSSize(width: side, height: side))
image.lockFocus()
func color(_ hex: UInt32) -> NSColor { NSColor(srgbRed: CGFloat((hex >> 16) & 255)/255, green: CGFloat((hex >> 8) & 255)/255, blue: CGFloat(hex & 255)/255, alpha: 1) }
color(0xF8F4EC).setFill()
NSBezierPath(rect: NSRect(x:0,y:0,width:1024,height:1024)).fill()
color(0x253D38).setFill()
NSBezierPath(roundedRect:NSRect(x:160,y:160,width:704,height:704),xRadius:100,yRadius:100).fill()
let fills:[UInt32] = [0xD98765,0xE5B74C,0x70A69C,0x8F9FC3]
for row in 0..<2 { for col in 0..<2 {
 let rect = NSRect(x:200+col*320,y:200+row*320,width:304,height:304)
 color(fills[row*2+col]).setFill()
 NSBezierPath(roundedRect:rect,xRadius:36,yRadius:36).fill()
 color(0xFFFCF6).withAlphaComponent(0.52).setFill()
 NSBezierPath(rect:NSRect(x:rect.midX-24,y:rect.minY,width:48,height:rect.height)).fill()
} }
image.unlockFocus()
let context = CGContext(data:nil,width:side,height:side,bitsPerComponent:8,bytesPerRow:0,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.noneSkipLast.rawValue)!
context.draw(image.cgImage(forProposedRect:nil,context:nil,hints:nil)!,in:CGRect(x:0,y:0,width:side,height:side))
let bitmap=NSBitmapImageRep(cgImage:context.makeImage()!)
try bitmap.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:CommandLine.arguments[1]))
