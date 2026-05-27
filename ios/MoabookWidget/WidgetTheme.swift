import SwiftUI

enum ColorVariant {
    case white, blue
}

struct WidgetPalette {
    let background: Color
    let text: Color
    let accent: Color
    let dummyText: Color

    static let white = WidgetPalette(
        background: Color(red: 0xF6/255, green: 0xF9/255, blue: 0xFF/255),
        text: Color(red: 0x33/255, green: 0x33/255, blue: 0x33/255),
        accent: Color(red: 0x01/255, green: 0x01/255, blue: 0x96/255),
        dummyText: Color(red: 0xA7/255, green: 0xA7/255, blue: 0xA7/255)
    )

    static let blue = WidgetPalette(
        background: Color(red: 0x01/255, green: 0x01/255, blue: 0x96/255),
        text: .white,
        accent: .white,
        dummyText: Color.white.opacity(0.6)
    )

    static func resolve(_ variant: ColorVariant) -> WidgetPalette {
        switch variant {
        case .white: return .white
        case .blue: return .blue
        }
    }
}
