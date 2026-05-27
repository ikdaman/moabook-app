package project.side.widget.theme

enum class ColorVariant {
    WHITE, BLUE;

    companion object {
        fun fromName(name: String?): ColorVariant =
            values().firstOrNull { it.name == name } ?: WHITE
    }
}
