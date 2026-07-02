package com.mediavault

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.media.MediaScannerConnection
import android.os.Build

class MainActivity: FlutterActivity() {
    private val MEDIA_SCANNER_CHANNEL = "com.mediavault/media_scanner"
    private val DEVICE_INFO_CHANNEL = "com.mediavault/device_info"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Canal pour scanner les fichiers média
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MEDIA_SCANNER_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "scanFile") {
                val path = call.arguments as String
                MediaScannerConnection.scanFile(this, arrayOf(path), null) { scannedPath, uri ->
                    runOnUiThread {
                        result.success(uri?.toString())
                    }
                }
            } else {
                result.notImplemented()
            }
        }
        
        // Canal pour obtenir la version Android
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DEVICE_INFO_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getSdkVersion") {
                result.success(Build.VERSION.SDK_INT)
            } else {
                result.notImplemented()
            }
        }
    }
}