package project.side.widget.glance.theme

import androidx.compose.ui.graphics.Color
import project.side.widget.theme.ColorVariant

data class WidgetColors(
    val background: Color,
    val text: Color,
    val accent: Color,
    val dummyText: Color,
    val indicatorActive: Color,
    val indicatorInactive: Color,
    val refreshTint: Color,
    val refreshAlpha: Float,
)

fun colorsFor(variant: ColorVariant): WidgetColors = when (variant) {
    ColorVariant.WHITE -> WidgetColors(
        background = Color(0xFFF6F9FF),
        text = Color(0xFF333333),
        accent = Color(0xFF010196),
        dummyText = Color(0xFFA7A7A7),
        indicatorActive = Color(0xFF747474),
        indicatorInactive = Color(0xFFD9D9D9),
        refreshTint = Color(0xFF333333),
        refreshAlpha = 0.6f,
    )
    ColorVariant.BLUE -> WidgetColors(
        background = Color(0xFF010196),
        text = Color(0xFFFFFFFF),
        accent = Color(0xFFFFFFFF),
        dummyText = Color(0xFFFFFFFF).copy(alpha = 0.6f),
        indicatorActive = Color(0xFFFFFFFF),
        indicatorInactive = Color(0xFFFFFFFF).copy(alpha = 0.3f),
        refreshTint = Color(0xFFFFFFFF),
        refreshAlpha = 0.6f,
    )
}
