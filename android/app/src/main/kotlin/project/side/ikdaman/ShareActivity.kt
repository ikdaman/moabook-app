package project.side.ikdaman

import android.content.Intent
import android.net.Uri
import android.os.Build
import io.flutter.embedding.android.FlutterActivityLaunchConfigs.BackgroundMode
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File

/**
 * 갤러리 "공유하기" → 모아북 진입점.
 *
 * 투명 배경 + 별도 Dart entrypoint(shareMain)로 원본 화면 위에
 * 바텀시트만 오버레이한다. 공유 이미지는 캐시로 복사해 경로만 Dart에 넘긴다.
 */
// FlutterFragmentActivity 상속 이유: flutter_naver_login 플러그인이
// onAttachedToActivity에서 FlutterFragmentActivity 캐스팅을 요구한다.
class ShareActivity : FlutterFragmentActivity() {

    companion object {
        const val CHANNEL = "project.side.ikdaman/share_import"
        private const val CACHE_PREFIX = "share_import_"
    }

    // 루트 라이브러리(main.dart)의 shareMain 위임 함수로 진입.
    override fun getDartEntrypointFunctionName(): String = "shareMain"

    override fun getBackgroundMode(): BackgroundMode = BackgroundMode.transparent

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getSharedImage" -> copySharedImage(result)
                    "openMainApp" -> {
                        result.success(null)
                        openMainApp()
                    }
                    "close" -> {
                        result.success(null)
                        finish()
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /** ACTION_SEND의 EXTRA_STREAM 이미지를 캐시 파일로 복사해 경로 반환. */
    private fun copySharedImage(result: MethodChannel.Result) {
        val uri: Uri? = if (intent?.action == Intent.ACTION_SEND &&
            intent?.type?.startsWith("image/") == true
        ) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
            } else {
                @Suppress("DEPRECATION")
                intent.getParcelableExtra(Intent.EXTRA_STREAM)
            }
        } else null

        if (uri == null) {
            result.success(null)
            return
        }

        CoroutineScope(Dispatchers.Main).launch {
            val path = withContext(Dispatchers.IO) {
                try {
                    val file =
                        File(cacheDir, "$CACHE_PREFIX${System.currentTimeMillis()}.jpg")
                    contentResolver.openInputStream(uri)?.use { input ->
                        file.outputStream().use { output -> input.copyTo(output) }
                    } ?: return@withContext null
                    file.absolutePath
                } catch (_: Exception) {
                    null
                }
            }
            result.success(path)
        }
    }

    private fun openMainApp() {
        packageManager.getLaunchIntentForPackage(packageName)?.let {
            it.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(it)
        }
        finish()
    }

    override fun onDestroy() {
        // 이번/과거 공유에서 남은 캐시 이미지 정리.
        cacheDir.listFiles { f -> f.name.startsWith(CACHE_PREFIX) }
            ?.forEach { it.delete() }
        super.onDestroy()
    }
}
