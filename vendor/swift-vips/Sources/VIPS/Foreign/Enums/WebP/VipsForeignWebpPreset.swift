import Cvips
import CvipsShim

extension VipsForeignWebpPreset {
    public static var `default`: Self { VIPS_FOREIGN_WEBP_PRESET_DEFAULT }
    public static var picture: Self { VIPS_FOREIGN_WEBP_PRESET_PICTURE }
    public static var photo: Self { VIPS_FOREIGN_WEBP_PRESET_PHOTO }
    public static var drawing: Self { VIPS_FOREIGN_WEBP_PRESET_DRAWING }
    public static var icon: Self { VIPS_FOREIGN_WEBP_PRESET_ICON }
    public static var text: Self { VIPS_FOREIGN_WEBP_PRESET_TEXT }
    public static var last: Self { VIPS_FOREIGN_WEBP_PRESET_LAST }
}