import SwiftUI
import WidgetKit

@main
struct MoabookWidgetBundle: WidgetBundle {
    var body: some Widget {
        MoabookSmallWhiteWidget()
        MoabookSmallBlueWidget()
        MoabookMediumWhiteWidget()
        MoabookMediumBlueWidget()
        MoabookLargeWidget()
    }
}
