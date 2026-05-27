package project.side.widget.glance

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.view.View
import android.widget.RemoteViews
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.LocalContext
import androidx.glance.action.clickable
import androidx.glance.appwidget.AndroidRemoteViews
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetManager
import androidx.glance.appwidget.action.actionStartActivity
import androidx.glance.appwidget.provideContent
import androidx.glance.currentState
import androidx.glance.layout.fillMaxSize
import project.side.ikdaman.R
import project.side.widget.data.WidgetCache
import project.side.widget.data.WidgetPreferences
import project.side.widget.data.WidgetUiBook
import project.side.widget.domain.DateLabel
import project.side.widget.glance.components.EmptyState
import project.side.widget.glance.theme.colorsFor
import project.side.widget.glance.util.renderDungGeunMoBitmap
import project.side.widget.intent.WidgetIntents
import project.side.widget.receiver.MediumWidgetBlueReceiver
import project.side.widget.receiver.MediumWidgetWhiteReceiver
import project.side.widget.state.WidgetStateKeys
import project.side.widget.theme.ColorVariant

const val ACTION_MEDIUM_PAGE = "project.side.widget.ACTION_MEDIUM_PAGE"
const val EXTRA_TARGET_INDEX = "target_index"

private const val MAX_PAGES = 5

class MediumWidget : GlanceAppWidget() {

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val books = WidgetCache(context).read().take(MAX_PAGES)
        val manager = GlanceAppWidgetManager(context)
        val appWidgetId = manager.getAppWidgetId(id)
        val variant = resolveVariant(context, appWidgetId, WidgetPreferences(context))
        provideContent { MediumContent(books, variant, appWidgetId) }
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
            MediumWidgetWhiteReceiver::class.java.name -> ColorVariant.WHITE
            MediumWidgetBlueReceiver::class.java.name -> ColorVariant.BLUE
            else -> prefs.colorFor(appWidgetId)
        }
    }
}

@Composable
private fun MediumContent(books: List<WidgetUiBook>, variant: ColorVariant, appWidgetId: Int) {
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
    val rawIndex = state[WidgetStateKeys.MEDIUM_CURRENT_INDEX] ?: 0
    val current = rawIndex.coerceIn(0, books.size - 1)

    val remoteViews = remember(books, variant, current, appWidgetId) {
        buildMediumRemoteViews(context, books, variant, current, appWidgetId)
    }
    AndroidRemoteViews(
        remoteViews = remoteViews,
        modifier = GlanceModifier.fillMaxSize().clickable(
            actionStartActivity(WidgetIntents.openBook(context, books[current].mybookId))
        ),
    )
}

private fun buildMediumRemoteViews(
    context: Context,
    books: List<WidgetUiBook>,
    variant: ColorVariant,
    current: Int,
    appWidgetId: Int,
): RemoteViews {
    val isWhite = variant == ColorVariant.WHITE
    val bgRes = if (isWhite) R.drawable.widget_bg_white else R.drawable.widget_bg_blue
    val receiverClass = if (isWhite) MediumWidgetWhiteReceiver::class.java else MediumWidgetBlueReceiver::class.java
    val paginationColor = if (isWhite) 0xFF010196.toInt() else 0xFFFFFFFF.toInt()
    val total = books.size

    return RemoteViews(context.packageName, R.layout.widget_medium_content).apply {
        setInt(R.id.widget_medium_root, "setBackgroundResource", bgRes)

        removeAllViews(R.id.widget_medium_flipper)
        books.forEach { book ->
            addView(R.id.widget_medium_flipper, buildMediumPageRemoteViews(context, book, variant))
        }
        setDisplayedChild(R.id.widget_medium_flipper, current)

        setImageViewBitmap(
            R.id.widget_medium_prev_zone,
            renderDungGeunMoBitmap(context, "이전", 12f, paginationColor),
        )
        setImageViewBitmap(
            R.id.widget_medium_divider,
            renderDungGeunMoBitmap(context, "|", 12f, paginationColor),
        )
        setImageViewBitmap(
            R.id.widget_medium_next_zone,
            renderDungGeunMoBitmap(context, "다음", 12f, paginationColor),
        )

        if (total > 1) {
            val prevIndex = (current - 1 + total) % total
            val nextIndex = (current + 1) % total
            setOnClickPendingIntent(
                R.id.widget_medium_prev_zone,
                buildPagePendingIntent(context, receiverClass, appWidgetId, prevIndex, code = 50),
            )
            setOnClickPendingIntent(
                R.id.widget_medium_next_zone,
                buildPagePendingIntent(context, receiverClass, appWidgetId, nextIndex, code = 51),
            )
            setViewVisibility(R.id.widget_medium_prev_zone, View.VISIBLE)
            setViewVisibility(R.id.widget_medium_divider, View.VISIBLE)
            setViewVisibility(R.id.widget_medium_next_zone, View.VISIBLE)
        } else {
            setViewVisibility(R.id.widget_medium_prev_zone, View.GONE)
            setViewVisibility(R.id.widget_medium_divider, View.GONE)
            setViewVisibility(R.id.widget_medium_next_zone, View.GONE)
        }
    }
}

private fun buildMediumPageRemoteViews(
    context: Context,
    book: WidgetUiBook,
    variant: ColorVariant,
): RemoteViews {
    val isWhite = variant == ColorVariant.WHITE
    val iconRes = if (isWhite) R.drawable.ic_book_heart_navy else R.drawable.ic_book_heart_pure
    val textColor = if (isWhite) 0xFF333333.toInt() else 0xFFFFFFFF.toInt()
    val accentColor = if (isWhite) 0xFF010196.toInt() else 0xFFFFFFFF.toInt()
    val dummyColor = if (isWhite) 0xFFA7A7A7.toInt() else 0x99FFFFFF.toInt()

    return RemoteViews(context.packageName, R.layout.widget_medium_page).apply {
        setImageViewResource(R.id.widget_medium_page_icon, iconRes)
        setTextViewText(R.id.widget_medium_page_title, book.title)
        setTextColor(R.id.widget_medium_page_title, textColor)

        val reasonRaw = book.reason?.takeIf { it.isNotBlank() }
        setTextViewText(R.id.widget_medium_page_reason, reasonRaw ?: "읽고 싶은 이유를 추가해 주세요.")
        setTextColor(R.id.widget_medium_page_reason, if (reasonRaw == null) dummyColor else textColor)

        setImageViewBitmap(
            R.id.widget_medium_page_date,
            renderDungGeunMoBitmap(context, DateLabel.formatDisplay(book.createdDate), 12f, accentColor),
        )
    }
}

private fun buildPagePendingIntent(
    context: Context,
    receiverClass: Class<*>,
    appWidgetId: Int,
    targetIndex: Int,
    code: Int,
): PendingIntent {
    val intent = Intent(context, receiverClass).apply {
        action = ACTION_MEDIUM_PAGE
        putExtra(EXTRA_TARGET_INDEX, targetIndex)
    }
    return PendingIntent.getBroadcast(
        context,
        appWidgetId * 100 + code,
        intent,
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )
}
