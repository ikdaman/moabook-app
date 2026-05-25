package project.side.ikdaman

internal object JwtUtils {
    fun extractSub(idToken: String): String {
        return try {
            val payload = idToken.split(".")[1]
            val json = String(java.util.Base64.getUrlDecoder().decode(payload), Charsets.UTF_8)
            Regex(""""sub"\s*:\s*"([^"]+)"""").find(json)?.groupValues?.get(1) ?: ""
        } catch (e: Exception) {
            ""
        }
    }
}
