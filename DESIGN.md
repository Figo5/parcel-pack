# Parcel Pack

Native SwiftUI puzzle for iPhone, iOS 17+, also compiled on macOS for verification. Primary action: fit all parcels into one box. Custom visual system inspired by cheerful packing labels and cardboard compartments. DESIGN_VARIANCE=6 MOTION_INTENSITY=3 VISUAL_DENSITY=3.

Signature: a warm cardboard grid filled with rounded, saturated parcel tiles, each carrying a small tape seam. Use SF Rounded for native legibility and friendly numerals, SF text for supporting copy; 14/16/20/28/36 point scale. Four-point spacing base, 12 and 24 point container radii; tile corners scale with cell size. One soft shadow only on lifted parcels.

Palette roles (sRGB equivalents for SwiftUI): background #F8F4EC, surface #FFFCF6, foreground #253D38, muted #5D7068, cardboard #E3D4BD, grid #D1BEA0, accent #267B61, accent foreground #FFFFFF. Parcel fills #D98765, #E5B74C, #70A69C, #8F9FC3, #A0AE77, #CB8EAD. Dark foreground on parcel fills. Invalid placement uses red outline plus unavailable icon, not color alone.

Portrait, thumb-friendly controls, safe-area aware; board is focal point. Top shows name, help and shipped count. Small/Medium/Large picker. Subtitle "A little room for everything." Board sits above tray and undo/rotate/hint. Select-and-tap is a full alternative to dragging, including VoiceOver labels. No countdown, ads, lives, accounts or network. Completion shows packed stamp and next box action. Respect Reduce Motion, large text and color differentiation. First box includes short inline instructions. Progress saved locally.

Verified native macOS renders at 430- and 375-point widths on October 8, 2026. The compact tray uses one row at ordinary text sizes, changing to a grid at accessibility text sizes. Physical iPhone and iOS SDK unavailable on this host; device verification remains pending.
