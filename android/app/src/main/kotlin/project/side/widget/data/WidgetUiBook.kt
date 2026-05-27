package project.side.widget.data

import kotlinx.serialization.Serializable

@Serializable
data class WidgetUiBook(
    val mybookId: Int,
    val title: String,
    val reason: String?,
    val createdDate: String,
)
