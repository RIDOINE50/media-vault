package com.example.media

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.media.MediaScannerConnection
import android.os.Build
import android.provider.Settings
import android.content.Intent
import android.net.Uri
import android.media.RingtoneManager
import android.content.ContentValues
import android.os.Environment
import android.provider.MediaStore
import java.io.File

class MainActivity: FlutterActivity() {
    private val MEDIA_SCANNER_CHANNEL = "com.mediavault/media_scanner"
    private val DEVICE_INFO_CHANNEL = "com.mediavault/device_info"
    private val RINGTONE_CHANNEL = "com.mediavault/ringtone" // ✅ NOUVEAU CANAL

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

        // ✅ NOUVEAU : Canal pour définir la sonnerie
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, RINGTONE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "setAsRingtone" -> {
                    val filePath = call.argument<String>("filePath")
                    val fileName = call.argument<String>("fileName") ?: "ringtone"
                    
                    if (filePath == null) {
                        result.error("INVALID_ARGS", "filePath manquant", null)
                        return@setMethodCallHandler
                    }

                    try {
                        val success = setAsRingtone(filePath, fileName)
                        result.success(success)
                    } catch (e: Exception) {
                        result.error("RINGTONE_ERROR", e.message, null)
                    }
                }
                "canWriteSettings" -> {
                    val canWrite = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        Settings.System.canWrite(this)
                    } else {
                        true
                    }
                    result.success(canWrite)
                }
                "openWriteSettings" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        val intent = Intent(Settings.ACTION_MANAGE_WRITE_SETTINGS)
                        intent.data = Uri.parse("package:$packageName")
                        startActivity(intent)
                    }
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    // ✅ FONCTION POUR DÉFINIR LA SONNERIE
    private fun setAsRingtone(filePath: String, fileName: String): Boolean {
        val file = File(filePath)
        if (!file.exists()) return false

        // Vérifier la permission d'écrire les paramètres système
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.System.canWrite(this)) {
            return false
        }

        try {
            // Copier le fichier dans le dossier Ringtones
            val ringtonesDir = File(
                Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_RINGTONES),
                "$fileName.mp3"
            )
            file.copyTo(ringtonesDir, overwrite = true)

            // Enregistrer dans la base de données Android
            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.TITLE, fileName)
                put(MediaStore.MediaColumns.MIME_TYPE, "audio/mpeg")
                put(MediaStore.Audio.Media.IS_RINGTONE, true)
                put(MediaStore.Audio.Media.IS_NOTIFICATION, false)
                put(MediaStore.Audio.Media.IS_ALARM, false)
                put(MediaStore.Audio.Media.IS_MUSIC, false)
            }

            val uri = contentResolver.insert(MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, values)
            uri?.let {
                // Définir comme sonnerie par défaut
                RingtoneManager.setActualDefaultRingtoneUri(
                    this,
                    RingtoneManager.TYPE_RINGTONE,
                    it
                )
                return true
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
        return false
    }
}