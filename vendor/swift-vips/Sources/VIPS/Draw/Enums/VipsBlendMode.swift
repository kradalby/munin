import Cvips
import CvipsShim

public typealias VipsBlendMode = Cvips.VipsBlendMode

extension VipsBlendMode {
    public static var clear: Self { VIPS_BLEND_MODE_CLEAR }
    public static var source: Self { VIPS_BLEND_MODE_SOURCE }
    public static var over: Self { VIPS_BLEND_MODE_OVER }
    public static var `in`: Self { VIPS_BLEND_MODE_IN }
    public static var out: Self { VIPS_BLEND_MODE_OUT }
    public static var atop: Self { VIPS_BLEND_MODE_ATOP }
    public static var dest: Self { VIPS_BLEND_MODE_DEST }
    public static var destOver: Self { VIPS_BLEND_MODE_DEST_OVER }
    public static var destIn: Self { VIPS_BLEND_MODE_DEST_IN }
    public static var destOut: Self { VIPS_BLEND_MODE_DEST_OUT }
    public static var destAtop: Self { VIPS_BLEND_MODE_DEST_ATOP }
    public static var xor: Self { VIPS_BLEND_MODE_XOR }
    public static var add: Self { VIPS_BLEND_MODE_ADD }
    public static var saturate: Self { VIPS_BLEND_MODE_SATURATE }
    public static var multiply: Self { VIPS_BLEND_MODE_MULTIPLY }
    public static var screen: Self { VIPS_BLEND_MODE_SCREEN }
    public static var overlay: Self { VIPS_BLEND_MODE_OVERLAY }
    public static var darken: Self { VIPS_BLEND_MODE_DARKEN }
    public static var lighten: Self { VIPS_BLEND_MODE_LIGHTEN }
    public static var colourDodge: Self { VIPS_BLEND_MODE_COLOUR_DODGE }
    public static var colourBurn: Self { VIPS_BLEND_MODE_COLOUR_BURN }
    public static var hardLight: Self { VIPS_BLEND_MODE_HARD_LIGHT }
    public static var softLight: Self { VIPS_BLEND_MODE_SOFT_LIGHT }
    public static var difference: Self { VIPS_BLEND_MODE_DIFFERENCE }
    public static var exclusion: Self { VIPS_BLEND_MODE_EXCLUSION }
    public static var last: Self { VIPS_BLEND_MODE_LAST }
}