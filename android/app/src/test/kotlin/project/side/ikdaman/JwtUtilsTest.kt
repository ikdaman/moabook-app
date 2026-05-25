package project.side.ikdaman

import org.junit.Assert.assertEquals
import org.junit.Test
import java.util.Base64

class JwtUtilsTest {

    private fun buildFakeToken(payload: String): String {
        val encoded = Base64.getUrlEncoder().withoutPadding().encodeToString(payload.toByteArray())
        return "header.$encoded.signature"
    }

    @Test
    fun `extractSub - 유효한 토큰에서 sub 추출`() {
        val token = buildFakeToken("""{"sub":"user123456","email":"test@gmail.com"}""")
        assertEquals("user123456", JwtUtils.extractSub(token))
    }

    @Test
    fun `extractSub - sub가 숫자 문자열이어도 올바르게 추출`() {
        val token = buildFakeToken("""{"iss":"accounts.google.com","sub":"9876543210"}""")
        assertEquals("9876543210", JwtUtils.extractSub(token))
    }

    @Test
    fun `extractSub - sub가 없으면 빈 문자열 반환`() {
        val token = buildFakeToken("""{"email":"test@gmail.com"}""")
        assertEquals("", JwtUtils.extractSub(token))
    }

    @Test
    fun `extractSub - 잘못된 JWT 형식이면 빈 문자열 반환`() {
        assertEquals("", JwtUtils.extractSub("not-a-jwt"))
    }

    @Test
    fun `extractSub - 빈 문자열이면 빈 문자열 반환`() {
        assertEquals("", JwtUtils.extractSub(""))
    }

    @Test
    fun `extractSub - 파트가 2개 미만이면 빈 문자열 반환`() {
        assertEquals("", JwtUtils.extractSub("onlyone"))
    }
}
