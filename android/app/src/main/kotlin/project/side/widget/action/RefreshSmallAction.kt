package project.side.widget.action

import android.content.Context
import androidx.glance.GlanceId
import androidx.glance.action.ActionParameters
import androidx.glance.appwidget.action.ActionCallback
import androidx.glance.appwidget.state.updateAppWidgetState
import kotlin.random.Random
import project.side.widget.data.WidgetCache
import project.side.widget.glance.SmallWidget
import project.side.widget.state.WidgetStateKeys

/**
 * Small 위젯 refresh 아이콘 탭 시 호출.
 * 서버 fetch 안 함 — cache 에서 현재 mybookId 제외하고 다음 책 1권 랜덤 픽.
 */
class RefreshSmallAction : ActionCallback {
    override suspend fun onAction(
        context: Context,
        glanceId: GlanceId,
        parameters: ActionParameters,
    ) {
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
