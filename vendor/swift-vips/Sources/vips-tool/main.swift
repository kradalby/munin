import VIPS
import Cvips
import Foundation

guard CommandLine.arguments.count > 2 else {
    print("Usage: \(CommandLine.arguments[0]) PATH TEXT")
    exit(1)
}


let im = try VIPSImage(fromFilePath: CommandLine.arguments[1])

var text = try VIPSImage.text(CommandLine.arguments[2], font: "sans bold 12", align: .centre, dpi: 72)

print(text.size)


text = try (text * 0.4).cast(format: .uchar)
try Data(try text.pngsave()).write(to: URL(fileURLWithPath: "/tmp/swift-vips/out_text_test.png"))
text = try text
            .rotate(angle: -45)
            .gravity(direction: .centre, width: 300, height: 300)
            .replicate(across: 1 + im.size.width / text.size.width, down: 1 + im.size.height / text.size.height)
            .crop(left: 0, top: 0, width: im.size.width, height: im.size.height)

let overlay = try text.new([255, 128, 128])
    .copy(interpretation: .srgb)
    

let out = try im.composite2(overlay: overlay, mode: .over)

let jpeg = try out.pngsave()
try Data(jpeg).write(to: URL(fileURLWithPath: "/tmp/swift-vips/out_text_exported.jpg"))

