package project.side.widget.data

import android.content.Context
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.json.Json

/**
 * Flutter 의 `home_widget` 플러그인이 기록한 SharedPreferences("HomeWidgetPreferences") 에서
 * 위젯 데이터를 읽는다. native 는 read-only. fetch 는 Flutter 가 담당.
 *
 * key/JSON 포맷은 Android 원본(`recent_store_books_json`) 과 동일하게 유지해
 * 기존 사용자의 cold-start 호환을 보장한다.
 */
class WidgetCache(private val context: Context) {

    fun read(): List<WidgetUiBook> {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val raw = prefs.getString(KEY_BOOKS_JSON, null) ?: return emptyList()
        return runCatching { json.decodeFromString(LIST_SERIALIZER, raw) }.getOrElse { emptyList() }
    }

    fun lastFetchedAt(): Long {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        return prefs.getLong(KEY_LAST_FETCHED_AT, 0L)
    }

    companion object {
        const val PREFS_NAME = "HomeWidgetPreferences"
        const val KEY_BOOKS_JSON = "recent_store_books_json"
        const val KEY_LAST_FETCHED_AT = "last_fetched_at"
        const val MAX_ENTRIES = 9
        private val LIST_SERIALIZER = ListSerializer(WidgetUiBook.serializer())
        private val json = Json { ignoreUnknownKeys = true }
    }
}
