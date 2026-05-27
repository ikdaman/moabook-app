package project.side.widget.data

import android.content.Context
import project.side.widget.theme.ColorVariant

/**
 * appWidgetId 별 색상 설정 저장. SharedPreferences 사용 (별도 파일).
 */
class WidgetPreferences(private val context: Context) {

    fun colorFor(appWidgetId: Int): ColorVariant {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val saved = prefs.getString(colorKey(appWidgetId), null)
        if (saved != null) return ColorVariant.fromName(saved)
        val default = prefs.getString(KEY_LAST_DEFAULT, null)
        return ColorVariant.fromName(default)
    }

    fun setColor(appWidgetId: Int, variant: ColorVariant) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit()
            .putString(colorKey(appWidgetId), variant.name)
            .putString(KEY_LAST_DEFAULT, variant.name)
            .apply()
    }

    fun clear(appWidgetId: Int) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit().remove(colorKey(appWidgetId)).apply()
    }

    private fun colorKey(appWidgetId: Int) = "widget_color_$appWidgetId"

    companion object {
        const val PREFS_NAME = "widget_color_prefs"
        private const val KEY_LAST_DEFAULT = "widget_color_last_default"
    }
}
