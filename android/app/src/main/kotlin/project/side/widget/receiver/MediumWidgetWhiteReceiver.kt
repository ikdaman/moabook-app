package project.side.widget.receiver

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetManager
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.state.updateAppWidgetState
import androidx.glance.appwidget.updateAll
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import project.side.widget.glance.ACTION_MEDIUM_PAGE
import project.side.widget.glance.EXTRA_TARGET_INDEX
import project.side.widget.glance.MediumWidget
import project.side.widget.state.WidgetStateKeys

class MediumWidgetWhiteReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = MediumWidget()
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        super.onUpdate(context, appWidgetManager, appWidgetIds)
        val pendingResult = goAsync()
        scope.launch {
            try {
                glanceAppWidget.updateAll(context)
            } finally {
                pendingResult?.finish()
            }
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == ACTION_MEDIUM_PAGE) {
            val targetIndex = intent.getIntExtra(EXTRA_TARGET_INDEX, 0)
            val pendingResult = goAsync()
            scope.launch {
                try {
                    handleMediumPage(context, targetIndex)
                } finally {
                    pendingResult?.finish()
                }
            }
        }
    }
}

internal suspend fun handleMediumPage(context: Context, targetIndex: Int) {
    val manager = GlanceAppWidgetManager(context)
    val widget = MediumWidget()
    val glanceIds = manager.getGlanceIds(MediumWidget::class.java)
    glanceIds.forEach { gid ->
        updateAppWidgetState(context, gid) { prefs ->
            prefs[WidgetStateKeys.MEDIUM_CURRENT_INDEX] = targetIndex
        }
        widget.update(context, gid)
    }
}
