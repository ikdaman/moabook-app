package project.side.widget.action

import project.side.widget.data.WidgetUiBook

object RefreshLogic {
    /**
     * 현재 mybookId 책을 제외하고 다음 책 1권 랜덤 픽.
     * - books 비면 null
     * - books 1권이면 그 책 그대로 반환 (변경 없음)
     * - 그 외엔 currentMybookId가 아닌 책 중 랜덤
     */
    fun pickNextByMybookId(
        books: List<WidgetUiBook>,
        currentMybookId: Int?,
        randomInt: (Int) -> Int,
    ): WidgetUiBook? {
        if (books.isEmpty()) return null
        if (books.size == 1) return books[0]
        val candidates = books.filter { it.mybookId != currentMybookId }
        if (candidates.isEmpty()) return books[0]
        return candidates[randomInt(candidates.size)]
    }
}
