package project.side.widget.glance.components

import android.widget.RemoteViews
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.glance.GlanceModifier
import androidx.glance.LocalContext
import androidx.glance.action.Action
import androidx.glance.action.clickable
import androidx.glance.appwidget.AndroidRemoteViews
import androidx.glance.layout.fillMaxSize
import project.side.ikdaman.R
import project.side.widget.glance.util.renderDungGeunMoBitmap

@Composable
fun EmptyState(
    textColor: Color,
    onClick: Action,
    fontSizeSp: Int = 14,
    backgroundColor: Color = Color(0xFFF6F9FF),
) {
    val context = LocalContext.current
    val textArgb = textColor.toArgb()
    val bgArgb = backgroundColor.toArgb()
    val remoteViews = remember(textArgb, bgArgb, fontSizeSp) {
        RemoteViews(context.packageName, R.layout.widget_empty_state).apply {
            setInt(R.id.widget_empty_root, "setBackgroundColor", bgArgb)
            setImageViewBitmap(
                R.id.widget_empty_image,
                renderDungGeunMoBitmap(
                    context = context,
                    text = "읽고 싶은 책을 추가해 보세요 !",
                    textSizeSp = fontSizeSp.toFloat(),
                    color = textArgb,
                ),
            )
        }
    }
    AndroidRemoteViews(
        remoteViews = remoteViews,
        modifier = GlanceModifier
            .fillMaxSize()
            .clickable(onClick),
    )
}
