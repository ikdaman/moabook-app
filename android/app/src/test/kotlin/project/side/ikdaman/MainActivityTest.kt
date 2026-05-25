package project.side.ikdaman

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * MainActivity의 MethodChannel 이름 등 상수를 검증합니다.
 * CredentialManager 동작은 기기/에뮬레이터가 필요한 Instrumented Test 대상입니다.
 * extractSub 로직 검증은 JwtUtilsTest에서 수행합니다.
 */
class MainActivityTest {

    @Test
    fun `GOOGLE_AUTH_CHANNEL 상수가 Flutter 채널명과 일치`() {
        assertEquals("project.side.ikdaman/google_auth", MainActivity.GOOGLE_AUTH_CHANNEL)
    }
}
