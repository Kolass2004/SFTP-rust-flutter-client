package com.rexon.sftp_client

import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setHighRefreshRate()
    }

    override fun onResume() {
        super.onResume()
        setHighRefreshRate()
    }

    private fun setHighRefreshRate() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val display = windowManager.defaultDisplay
            val modes = display.supportedModes
            var maxMode = display.mode
            for (mode in modes) {
                if (mode.refreshRate > maxMode.refreshRate) {
                    maxMode = mode
                }
            }
            val layoutParams = window.attributes
            layoutParams.preferredDisplayModeId = maxMode.modeId
            window.attributes = layoutParams
        }
    }
}
