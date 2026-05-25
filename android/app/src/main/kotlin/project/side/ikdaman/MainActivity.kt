package project.side.ikdaman

import androidx.credentials.ClearCredentialStateRequest
import androidx.credentials.CredentialManager
import androidx.credentials.CustomCredential
import androidx.credentials.GetCredentialRequest
import androidx.credentials.exceptions.GetCredentialException
import com.google.android.libraries.identity.googleid.GetSignInWithGoogleOption
import com.google.android.libraries.identity.googleid.GoogleIdTokenCredential
import com.google.android.libraries.identity.googleid.GoogleIdTokenParsingException
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class MainActivity : FlutterFragmentActivity() {

    companion object {
        const val GOOGLE_AUTH_CHANNEL = "project.side.ikdaman/google_auth"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, GOOGLE_AUTH_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "login" -> googleLogin(result)
                "logout" -> googleLogout(result)
                else -> result.notImplemented()
            }
        }
    }

    private fun googleLogin(result: MethodChannel.Result) {
        val clientId = BuildConfig.GOOGLE_CLIENT_ID
        if (clientId.isEmpty()) {
            result.error("CONFIG_ERROR", "GOOGLE_CLIENT_ID가 설정되지 않았습니다.", null)
            return
        }

        val option = GetSignInWithGoogleOption.Builder(clientId).build()
        val request = GetCredentialRequest.Builder().addCredentialOption(option).build()
        val credentialManager = CredentialManager.create(this)

        CoroutineScope(Dispatchers.Main).launch {
            try {
                val response = credentialManager.getCredential(this@MainActivity, request)
                val credential = response.credential

                if (credential is CustomCredential &&
                    credential.type == GoogleIdTokenCredential.TYPE_GOOGLE_ID_TOKEN_CREDENTIAL
                ) {
                    val googleCredential = GoogleIdTokenCredential.createFrom(credential.data)
                    val idToken = googleCredential.idToken
                    val providerId = extractSub(idToken)

                    result.success(mapOf(
                        "isSuccess" to true,
                        "idToken" to idToken,
                        "providerId" to providerId,
                    ))
                } else {
                    result.error("CREDENTIAL_ERROR", "예상치 못한 Credential 타입입니다.", null)
                }
            } catch (e: GoogleIdTokenParsingException) {
                result.error("TOKEN_PARSE_ERROR", e.message, null)
            } catch (e: GetCredentialException) {
                result.error("CREDENTIAL_EXCEPTION", e.message, null)
            }
        }
    }

    private fun googleLogout(result: MethodChannel.Result) {
        val credentialManager = CredentialManager.create(this)
        CoroutineScope(Dispatchers.Main).launch {
            try {
                credentialManager.clearCredentialState(ClearCredentialStateRequest())
                result.success(null)
            } catch (e: Exception) {
                result.success(null)
            }
        }
    }

    private fun extractSub(idToken: String): String = JwtUtils.extractSub(idToken)
}
