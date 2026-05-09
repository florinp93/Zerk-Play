package cloud.zerk.play

import android.app.UiModeManager
import android.content.Context
import android.content.res.Configuration
import android.util.DisplayMetrics
import android.util.Log
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache

class MainActivity : FlutterActivity() {

    companion object {
        // Must match FlutterTvMedia3Plugin.appEngineId
        private const val APP_ENGINE_CACHE_ID = "app_engine_cache_id"
        private const val TAG = "MainActivity"
    }

    /**
     * Return the already-running engine when one exists in the cache (e.g. when
     * the activity is recreated after PlayerActivity finishes).  On the very
     * first launch the cache is empty, so we fall through to the default
     * behaviour and let FlutterActivity create a new engine; the plugin will
     * then store it under APP_ENGINE_CACHE_ID via onAttachedToEngine.
     */
    override fun provideFlutterEngine(context: Context): FlutterEngine? {
        val cached = FlutterEngineCache.getInstance().get(APP_ENGINE_CACHE_ID)
        if (cached != null) {
            Log.d(TAG, "provideFlutterEngine: reusing cached engine – Dart isolate preserved")
            return cached
        }
        Log.d(TAG, "provideFlutterEngine: no cache hit – creating new engine")
        return super.provideFlutterEngine(context)
    }

    /**
     * Never destroy the engine when this activity is destroyed.  The engine
     * (and its Dart isolate) must survive configuration-change recreations and
     * the return from PlayerActivity so that PlaybackPage remains mounted and
     * the onPlaybackStopping callback can still fire correctly.
     */
    override fun shouldDestroyEngineWithHost(): Boolean = false

    override fun attachBaseContext(newBase: Context) {
        val uiModeManager = newBase.getSystemService(Context.UI_MODE_SERVICE) as UiModeManager
        if (uiModeManager.currentModeType == Configuration.UI_MODE_TYPE_TELEVISION) {
            val dm = DisplayMetrics()
            @Suppress("DEPRECATION")
            val wm = newBase.getSystemService(Context.WINDOW_SERVICE) as WindowManager
            @Suppress("DEPRECATION")
            wm.defaultDisplay.getRealMetrics(dm)
            val physicalWidth = maxOf(dm.widthPixels, dm.heightPixels)

            val targetLogicalWidth = 1440.0
            val targetDensityDpi = (physicalWidth / targetLogicalWidth * 160).toInt()

            val config = Configuration(newBase.resources.configuration)
            config.densityDpi = targetDensityDpi
            super.attachBaseContext(newBase.createConfigurationContext(config))
        } else {
            super.attachBaseContext(newBase)
        }
    }
}
