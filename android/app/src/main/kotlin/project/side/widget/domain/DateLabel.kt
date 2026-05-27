package project.side.widget.domain

import java.time.LocalDate
import java.time.temporal.ChronoUnit

object DateLabel {
    private const val DUST_THRESHOLD_DAYS = 100L
    private const val DUST_MESSAGE = "책에 먼지가 쌓였어요..."
    private const val TODAY_LABEL = "오늘 저장"

    fun format(createdDate: String, today: LocalDate = LocalDate.now()): String {
        val parsed = parseLocalDate(createdDate) ?: return TODAY_LABEL
        val daysSince = ChronoUnit.DAYS.between(parsed, today)
        return when {
            daysSince <= 0L -> TODAY_LABEL
            daysSince <= DUST_THRESHOLD_DAYS -> "${daysSince}일 전 저장"
            else -> DUST_MESSAGE
        }
    }

    fun formatDisplay(createdDate: String): String {
        val parsed = parseLocalDate(createdDate) ?: return ""
        return "%04d.%02d.%02d".format(parsed.year, parsed.monthValue, parsed.dayOfMonth)
    }

    private fun parseLocalDate(input: String): LocalDate? {
        val datePart = input.substringBefore('T').trim()
        return runCatching { LocalDate.parse(datePart) }.getOrNull()
    }
}
