package project.side.widget.glance.util

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.text.TextPaint
import androidx.core.content.res.ResourcesCompat
import project.side.ikdaman.R

/**
 * 일부 OEM launcher (Samsung One UI 등) 는 RemoteViews TextView 의 fontFamily 를 무시하고
 * 시스템 기본 폰트로 fallback 한다. DungGeunMo 처럼 디자인 의도가 명확한 폰트는 Bitmap 으로
 * 직접 그려 ImageView 로 설정하면 모든 launcher 에서 폰트가 보장된다.
 */
fun renderDungGeunMoBitmap(
    context: Context,
    text: String,
    textSizeSp: Float,
    @androidx.annotation.ColorInt color: Int,
): Bitmap {
    val density = context.resources.displayMetrics.density
    val textSizePx = textSizeSp * density
    val typeface = ResourcesCompat.getFont(context, R.font.dunggeunmo)
    val paint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
        this.typeface = typeface
        this.textSize = textSizePx
        this.color = color
        this.letterSpacing = 0f
    }
    val safeText = text.ifEmpty { " " }
    val textWidth = paint.measureText(safeText)
    val fm = paint.fontMetrics
    val widthPx = (textWidth + 2f).toInt().coerceAtLeast(1)
    val heightPx = (fm.descent - fm.ascent + 2f).toInt().coerceAtLeast(1)
    val bitmap = Bitmap.createBitmap(widthPx, heightPx, Bitmap.Config.ARGB_8888)
    val canvas = Canvas(bitmap)
    val baselineY = -fm.ascent + 1f
    canvas.drawText(safeText, 1f, baselineY, paint)
    return bitmap
}
