package project.side.widget.action

import android.content.Context
import androidx.glance.GlanceId
import androidx.glance.action.ActionParameters
import androidx.glance.appwidget.action.ActionCallback
import project.side.widget.intent.WidgetIntents

class OpenBookAction : ActionCallback {
    override suspend fun onAction(
        context: Context,
        glanceId: GlanceId,
        parameters: ActionParameters,
    ) {
        val id = parameters[mybookIdKey] ?: return
        val intent = WidgetIntents.openBook(context, id)
        context.startActivity(intent)
    }

    companion object {
        val mybookIdKey = ActionParameters.Key<Int>("mybook_id")
    }
}
