import Cvips
import CvipsShim

public typealias VipsCompassDirection = Cvips.VipsCompassDirection

extension VipsCompassDirection {
    public static var centre: Self { VIPS_COMPASS_DIRECTION_CENTRE }
    public static var north: Self { VIPS_COMPASS_DIRECTION_NORTH }
    public static var east: Self { VIPS_COMPASS_DIRECTION_EAST }
    public static var south: Self { VIPS_COMPASS_DIRECTION_SOUTH }
    public static var west: Self { VIPS_COMPASS_DIRECTION_WEST }
    public static var northEast: Self { VIPS_COMPASS_DIRECTION_NORTH_EAST }
    public static var southEast: Self { VIPS_COMPASS_DIRECTION_SOUTH_EAST }
    public static var southWest: Self { VIPS_COMPASS_DIRECTION_SOUTH_WEST }
    public static var northWest: Self { VIPS_COMPASS_DIRECTION_NORTH_WEST }
    public static var last: Self { VIPS_COMPASS_DIRECTION_LAST }
}