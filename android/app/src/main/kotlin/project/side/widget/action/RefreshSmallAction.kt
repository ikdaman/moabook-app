package project.side.widget.action

import android.content.Context
import android.net.Uri
import androidx.glance.GlanceId
import androidx.glance.action.ActionParameters
import androidx.glance.appwidget.action.ActionCallback
import androidx.glance.appwidget.state.updateAppWidgetState
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import kotlin.random.Random
import project.side.widget.data.WidgetCache
import project.side.widget.glance.SmallWidget
import project.side.widget.state.WidgetStateKeys

/**
 * Small 위젯 refresh 아이콘 탭 시 호출.
 *
 * 1. Flutter Dart background isolate 깨우기 (home_widget 플러그인) → fetch + publish
 * 2. 현재 캐시에서 다음 책 1권 랜덤 픽 (이전 mybookId 제외)
 * 3. 위젯 즉시 업데이트 (Flutter publish 끝나면 다음 onUpdate 에서 새 데이터 반영)
 */
class RefreshSmallAction : ActionCallback {
    override suspend fun onAction(
        context: Context,
        glanceId: GlanceId,
        parameters: ActionParameters,
    ) {
        val pendingIntent = HomeWidgetBackgroundIntent.getBroadcast(
            context,
            Uri.parse("moabookwidget://refresh_small"),
        )
        pendingIntent.send()

        val books = WidgetCache(context).read()
        updateAppWidgetState(context, glanceId) { prefs ->
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
        SmallWidget().update(context, glanceId)
    }
}
