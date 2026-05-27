package project.side.widget.intent

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri

/**
 * 위젯 → MainActivity 라우팅 Intent.
 *
 * `home_widget` Flutter 플러그인의 `widgetClicked` Stream 과 호환되도록
 * action = `es.antonborri.home_widget.action.LAUNCH`, data = Uri 로 발사.
 *
 * Flutter 측에서 `HomeWidget.widgetClicked.listen(...)` 으로 수신해 라우팅.
 */
object WidgetIntents {
    const val MAIN_ACTIVITY_CLASS = "project.side.ikdaman.MainActivity"
    private const val LAUNCH_ACTION = "es.antonborri.home_widget.action.LAUNCH"

    fun openBook(context: Context, mybookId: Int): Intent =
        Intent().apply {
            component = ComponentName(context.packageName, MAIN_ACTIVITY_CLASS)
            action = LAUNCH_ACTION
            data = Uri.parse("moabookwidget://book?id=$mybookId")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }

    fun openApp(context: Context): Intent =
        Intent().apply {
            component = ComponentName(context.packageName, MAIN_ACTIVITY_CLASS)
            action = LAUNCH_ACTION
            data = Uri.parse("moabookwidget://home")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
}
