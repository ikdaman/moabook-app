package project.side.widget.receiver

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetManager
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.state.updateAppWidgetState
import androidx.glance.appwidget.updateAll
import kotlin.random.Random
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import project.side.widget.action.RefreshLogic
import project.side.widget.data.WidgetCache
import project.side.widget.glance.ACTION_REFRESH_SMALL
import project.side.widget.glance.SmallWidget
import project.side.widget.state.WidgetStateKeys

class SmallWidgetWhiteReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = SmallWidget()
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
        if (intent.action == ACTION_REFRESH_SMALL) {
            val pendingResult = goAsync()
            scope.launch {
                try {
                    handleSmallRefresh(context)
                } finally {
                    pendingResult?.finish()
                }
            }
        }
    }
}

internal suspend fun handleSmallRefresh(context: Context) {
    // cache 에서 다음 책 1권 랜덤 픽 후 위젯 즉시 업데이트 (서버 fetch 없음)
    val books = WidgetCache(context).read()
    val manager = GlanceAppWidgetManager(context)
    val widget = SmallWidget()
    val glanceIds = manager.getGlanceIds(SmallWidget::class.java)
    glanceIds.forEach { gid ->
        updateAppWidgetState(context, gid) { prefs ->
            val currentMybookId = prefs[WidgetStateKeys.SMALL_CURRENT_MYBOOK_ID]
            val pickedBook = RefreshLogic.pickNextByMybookId(books, currentMybookId) {
                Random.nextInt(it)
            }
            if (pickedBook != null) {
                val newIndex = books.indexOf(pickedBook).coerceAtLeast(0)
                prefs[WidgetStateKeys.SMALL_CURRENT_INDEX] = newIndex
                prefs[WidgetStateKeys.SMALL_CURRENT_MYBOOK_ID] = pickedBook.mybookId
            }
        }
        widget.update(context, gid)
    }
}
