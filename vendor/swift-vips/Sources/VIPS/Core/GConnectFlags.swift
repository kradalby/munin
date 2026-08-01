import Cvips
import CvipsShim

// Values come from CvipsShim rather than the G_CONNECT_* globals: glib >= 2.86
// tags GConnectFlags with __attribute__((flag_enum)) and Swift stops importing
// those enumerators as globals. The OptionSet conformance is gone for the same
// reason — on new glib the type arrives as an enum, which cannot conform. No
// caller does set algebra with it.
extension GConnectFlags {
    public static var `default`: Self {
        shim_G_CONNECT_DEFAULT()
    }

    public static var after: Self {
        shim_G_CONNECT_AFTER()
    }

    public static var swapped: Self {
        shim_G_CONNECT_SWAPPED()
    }
}
