package project.side.widget.glance

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.LocalContext
import androidx.glance.action.actionParametersOf
import androidx.glance.action.clickable
import androidx.glance.appwidget.AndroidRemoteViews
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetManager
import androidx.glance.appwidget.SizeMode
import androidx.glance.appwidget.action.actionRunCallback
import androidx.glance.appwidget.action.actionStartActivity
import androidx.glance.appwidget.provideContent
import androidx.glance.currentState
import androidx.glance.layout.fillMaxSize
import project.side.ikdaman.R
import project.side.widget.action.OpenBookAction
import project.side.widget.data.WidgetCache
import project.side.widget.data.WidgetPreferences
import project.side.widget.data.WidgetUiBook
import project.side.widget.domain.DateLabel
import project.side.widget.glance.components.EmptyState
import project.side.widget.glance.theme.colorsFor
import project.side.widget.glance.util.renderDungGeunMoBitmap
import project.side.widget.intent.WidgetIntents
import project.side.widget.receiver.SmallWidgetBlueReceiver
import project.side.widget.receiver.SmallWidgetWhiteReceiver
import project.side.widget.state.WidgetStateKeys
import project.side.widget.theme.ColorVariant

const val ACTION_REFRESH_SMALL = "project.side.widget.ACTION_REFRESH_SMALL"

class SmallWidget : GlanceAppWidget() {

    override val sizeMode: SizeMode = SizeMode.Single

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val cache = WidgetCache(context)
        val prefs = WidgetPreferences(context)
        val books = cache.read()
        val manager = GlanceAppWidgetManager(context)
        val appWidgetId = manager.getAppWidgetId(id)
        val variant = resolveVariant(context, appWidgetId, prefs)
        if (books.isNotEmpty()) {
            androidx.glance.appwidget.state.updateAppWidgetState(context, id) { state ->
                if (state[WidgetStateKeys.SMALL_CURRENT_MYBOOK_ID] == null) {
                    val safeIndex = (state[WidgetStateKeys.SMALL_CURRENT_INDEX] ?: 0)
                        .coerceIn(0, books.size - 1)
                    state[WidgetStateKeys.SMALL_CURRENT_MYBOOK_ID] = books[safeIndex].mybookId
                    state[WidgetStateKeys.SMALL_CURRENT_INDEX] = safeIndex
                }
            }
        }
        provideContent { SmallContent(books, variant, appWidgetId) }
    }

    private fun resolveVariant(
        context: Context,
        appWidgetId: Int,
        prefs: WidgetPreferences,
    ): ColorVariant {
        val providerClass = AppWidgetManager.getInstance(context)
            .getAppWidgetInfo(appWidgetId)
            ?.provider
            ?.className
        return when (providerClass) {
            SmallWidgetWhiteReceiver::class.java.name -> ColorVariant.WHITE
            SmallWidgetBlueReceiver::class.java.name -> ColorVariant.BLUE
            else -> prefs.colorFor(appWidgetId)
        }
    }
}

@Composable
private fun SmallContent(books: List<WidgetUiBook>, variant: ColorVariant, appWidgetId: Int) {
    val context = LocalContext.current

    if (books.isEmpty()) {
        val colors = colorsFor(variant)
        EmptyState(
            textColor = colors.text,
            onClick = actionStartActivity(WidgetIntents.openApp(context)),
            fontSizeSp = 14,
            backgroundColor = colors.background,
        )
        return
    }

    val state = currentState<androidx.datastore.preferences.core.Preferences>()
    val rawIndex = state[WidgetStateKeys.SMALL_CURRENT_INDEX] ?: 0
    val safeIndex = rawIndex.coerceIn(0, books.size - 1)
    val book = books[safeIndex]

    val remoteViews = remember(book, variant, appWidgetId) {
        buildSmallRemoteViews(context, book, variant, appWidgetId)
    }
    AndroidRemoteViews(
        remoteViews = remoteViews,
        modifier = GlanceModifier
            .fillMaxSize()
            .clickable(
                actionRunCallback<OpenBookAction>(
                    actionParametersOf(OpenBookAction.mybookIdKey to book.mybookId)
                )
            ),
    )
}

private fun buildSmallRemoteViews(
    context: Context,
    book: WidgetUiBook,
    variant: ColorVariant,
    appWidgetId: Int,
): RemoteViews {
    val isWhite = variant == ColorVariant.WHITE
    val bgRes = if (isWhite) R.drawable.widget_bg_white else R.drawable.widget_bg_blue
    val iconRes = if (isWhite) R.drawable.ic_book_heart_navy else R.drawable.ic_book_heart_pure
    val refreshRes = if (isWhite) R.drawable.ic_widget_refresh_dark else R.drawable.ic_widget_refresh_light
    val textColor = if (isWhite) 0xFF333333.toInt() else 0xFFFFFFFF.toInt()
    val accentColor = if (isWhite) 0xFF010196.toInt() else 0xFFFFFFFF.toInt()
    val receiverClass = if (isWhite) SmallWidgetWhiteReceiver::class.java else SmallWidgetBlueReceiver::class.java

    val refreshIntent = Intent(context, receiverClass).apply {
        action = ACTION_REFRESH_SMALL
    }
    val refreshPendingIntent = PendingIntent.getBroadcast(
        context,
        appWidgetId,
        refreshIntent,
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )

    return RemoteViews(context.packageName, R.layout.widget_small_content).apply {
        setInt(R.id.widget_small_root, "setBackgroundResource", bgRes)
        setImageViewResource(R.id.widget_small_icon, iconRes)
        setImageViewResource(R.id.widget_small_refresh, refreshRes)
        setTextViewText(R.id.widget_small_title, book.title)
        setTextColor(R.id.widget_small_title, textColor)
        setImageViewBitmap(
            R.id.widget_small_date,
            renderDungGeunMoBitmap(context, DateLabel.format(book.createdDate), 11f, accentColor),
        )
        setOnClickPendingIntent(R.id.widget_small_refresh, refreshPendingIntent)
    }
}
