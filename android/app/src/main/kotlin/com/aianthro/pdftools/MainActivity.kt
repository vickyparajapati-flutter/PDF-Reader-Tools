package com.aianthro.pdftools

import android.content.ContentUris
import android.content.ContentValues
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.allpdftools/media_store"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "saveToPublicDownload" -> {
                    val srcPath = call.argument<String>("srcPath")
                    val fileName = call.argument<String>("fileName")

                    if (srcPath == null || fileName == null) {
                        result.error("INVALID_ARGS", "Source path and file name are required", null)
                        return@setMethodCallHandler
                    }

                    try {
                        val savedPath = savePdfToPublicDownloads(srcPath, fileName)
                        result.success(savedPath)
                    } catch (e: Exception) {
                        result.error("SAVE_FAILED", e.message, null)
                    }
                }
                "saveImageToGallery" -> {
                    val srcPath = call.argument<String>("srcPath")
                    val fileName = call.argument<String>("fileName")

                    if (srcPath == null || fileName == null) {
                        result.error("INVALID_ARGS", "Source path and file name are required", null)
                        return@setMethodCallHandler
                    }

                    try {
                        val savedPath = saveImageToPublicPictures(srcPath, fileName)
                        result.success(savedPath)
                    } catch (e: Exception) {
                        result.error("SAVE_IMAGE_FAILED", e.message, null)
                    }
                }
                "getCreatedPdfs" -> {
                    try {
                        val list = getPdfsFromMediaStore()
                        result.success(list)
                    } catch (e: Exception) {
                        result.error("QUERY_FAILED", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun savePdfToPublicDownloads(srcPath: String, fileName: String): String {
        val srcFile = File(srcPath)
        if (!srcFile.exists()) {
            throw Exception("Source file does not exist")
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val resolver = context.contentResolver

            // Check and determine unique actual filename if duplicate exists in MediaStore
            var actualName = fileName
            val nameWithoutExt = if (fileName.contains('.')) fileName.substringBeforeLast('.') else fileName
            val ext = if (fileName.contains('.')) "." + fileName.substringAfterLast('.') else ".pdf"

            val contentValues = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, actualName)
                put(MediaStore.MediaColumns.MIME_TYPE, "application/pdf")
                put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS + "/PDFReader")
            }

            val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, contentValues)
                ?: throw Exception("Failed to create MediaStore entry")

            // Query back the exact actual displayName assigned by Android (e.g. file (1).pdf)
            val projection = arrayOf(MediaStore.MediaColumns.DISPLAY_NAME)
            resolver.query(uri, projection, null, null, null)?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val actualDisplayNameCol = cursor.getColumnIndex(MediaStore.MediaColumns.DISPLAY_NAME)
                    if (actualDisplayNameCol != -1) {
                        val realName = cursor.getString(actualDisplayNameCol)
                        if (!realName.isNullOrEmpty()) {
                            actualName = realName
                        }
                    }
                }
            }

            resolver.openOutputStream(uri)?.use { out ->
                FileInputStream(srcFile).use { input ->
                    input.copyTo(out)
                }
            }

            return "/storage/emulated/0/Download/PDFReader/$actualName"
        } else {
            val dir = File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS), "PDFReader")
            if (!dir.exists()) dir.mkdirs()
            val destFile = File(dir, fileName)
            FileInputStream(srcFile).use { input ->
                FileOutputStream(destFile).use { out ->
                    input.copyTo(out)
                }
            }
            return destFile.absolutePath
        }
    }

    private fun saveImageToPublicPictures(srcPath: String, fileName: String): String {
        val srcFile = File(srcPath)
        if (!srcFile.exists()) {
            throw Exception("Source file does not exist")
        }

        val isPng = fileName.lowercase().endsWith(".png")
        val mimeType = if (isPng) "image/png" else "image/jpeg"

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val resolver = context.contentResolver
            var actualName = fileName

            val contentValues = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, actualName)
                put(MediaStore.MediaColumns.MIME_TYPE, mimeType)
                put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_PICTURES + "/PDFReader")
            }

            val uri = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, contentValues)
                ?: throw Exception("Failed to create MediaStore Image entry")

            val projection = arrayOf(MediaStore.MediaColumns.DISPLAY_NAME)
            resolver.query(uri, projection, null, null, null)?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val actualDisplayNameCol = cursor.getColumnIndex(MediaStore.MediaColumns.DISPLAY_NAME)
                    if (actualDisplayNameCol != -1) {
                        val realName = cursor.getString(actualDisplayNameCol)
                        if (!realName.isNullOrEmpty()) {
                            actualName = realName
                        }
                    }
                }
            }

            resolver.openOutputStream(uri)?.use { out ->
                FileInputStream(srcFile).use { input ->
                    input.copyTo(out)
                }
            }

            return "/storage/emulated/0/Pictures/PDFReader/$actualName"
        } else {
            val dir = File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES), "PDFReader")
            if (!dir.exists()) dir.mkdirs()
            val destFile = File(dir, fileName)
            FileInputStream(srcFile).use { input ->
                FileOutputStream(destFile).use { out ->
                    input.copyTo(out)
                }
            }
            return destFile.absolutePath
        }
    }

    private fun getPdfsFromMediaStore(): List<Map<String, Any>> {
        val list = mutableListOf<Map<String, Any>>()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val projection = arrayOf(
                MediaStore.MediaColumns._ID,
                MediaStore.MediaColumns.DISPLAY_NAME,
                MediaStore.MediaColumns.SIZE,
                MediaStore.MediaColumns.DATE_MODIFIED
            )

            val selection = "${MediaStore.MediaColumns.MIME_TYPE} = ? OR ${MediaStore.MediaColumns.DISPLAY_NAME} LIKE ?"
            val selectionArgs = arrayOf("application/pdf", "%.pdf")
            val sortOrder = "${MediaStore.MediaColumns.DATE_MODIFIED} DESC"

            context.contentResolver.query(
                MediaStore.Downloads.EXTERNAL_CONTENT_URI,
                projection,
                selection,
                selectionArgs,
                sortOrder
            )?.use { cursor ->
                val idCol = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns._ID)
                val nameCol = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.DISPLAY_NAME)
                val sizeCol = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.SIZE)
                val dateCol = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.DATE_MODIFIED)

                while (cursor.moveToNext()) {
                    val id = cursor.getLong(idCol)
                    val name = cursor.getString(nameCol) ?: "Document.pdf"
                    val size = cursor.getLong(sizeCol)
                    val dateModified = cursor.getLong(dateCol) * 1000

                    val item = mapOf<String, Any>(
                        "id" to id,
                        "name" to name,
                        "size" to size,
                        "date" to dateModified,
                        "path" to "/storage/emulated/0/Download/PDFReader/$name"
                    )
                    list.add(item)
                }
            }
        }
        return list
    }
}

