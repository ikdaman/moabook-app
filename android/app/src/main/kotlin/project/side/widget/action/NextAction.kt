package project.side.widget.action

import android.content.Context
import androidx.glance.GlanceId
import androidx.glance.action.ActionParameters
import androidx.glance.appwidget.action.ActionCallback
import androidx.glance.appwidget.state.updateAppWidgetState
import project.side.widget.data.WidgetCache
import project.side.widget.glance.MediumWidget
import project.side.widget.state.WidgetStateKeys

class NextAction : ActionCallback {
    override suspend fun onAction(
        context: Context, glanceId: GlanceId, parameters: ActionParameters,
    ) {
        val total = WidgetCache(context).read().take(5).size
        if (total == 0) return
        updateAppWidgetState(context, glanceId) { prefs ->
            val current = prefs[WidgetStateKeys.MEDIUM_CURRENT_INDEX] ?: 0
            prefs[WidgetStateKeys.MEDIUM_CURRENT_INDEX] = (current + 1) % total
        }
        MediumWidget().update(context, glanceId)
    }
}
