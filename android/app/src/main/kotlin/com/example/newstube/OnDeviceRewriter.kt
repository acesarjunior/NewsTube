package com.example.newstube

import android.content.Context
import android.os.Build
import android.util.Log
import com.google.mlkit.genai.common.DownloadCallback
import com.google.mlkit.genai.common.FeatureStatus
import com.google.mlkit.genai.common.GenAiException
import com.google.mlkit.genai.proofreading.Proofreader
import com.google.mlkit.genai.proofreading.ProofreaderOptions
import com.google.mlkit.genai.proofreading.Proofreading
import com.google.mlkit.genai.proofreading.ProofreadingRequest
import java.util.concurrent.TimeUnit

class OnDeviceRewriter(
    private val context: Context
) {

    fun getRewriteAvailability(languageCode: String): Map<String, Any?> {
        if (Build.VERSION.SDK_INT < 26) {
            return mapOf(
                "supported" to false,
                "available" to false,
                "downloadable" to false,
                "downloading" to false,
                "reason" to "android_api_too_old"
            )
        }

        val proofreader = createProofreader(languageCode)
            ?: return mapOf(
                "supported" to false,
                "available" to false,
                "downloadable" to false,
                "downloading" to false,
                "reason" to "language_not_supported_by_gemini_nano_proofreading"
            )

        return try {
            val status = proofreader.checkFeatureStatus().get(15, TimeUnit.SECONDS)

            val supported = status != FeatureStatus.UNAVAILABLE
            val available = status == FeatureStatus.AVAILABLE
            val downloadable = status == FeatureStatus.DOWNLOADABLE
            val downloading = status == FeatureStatus.DOWNLOADING

            mapOf(
                "supported" to supported,
                "available" to available,
                "downloadable" to downloadable,
                "downloading" to downloading,
                "status" to status.toString(),
                "engine" to "gemini_nano"
            )
        } catch (e: Throwable) {
            mapOf(
                "supported" to false,
                "available" to false,
                "downloadable" to false,
                "downloading" to false,
                "reason" to shortErr(e)
            )
        } finally {
            closeQuietly(proofreader)
        }
    }

    fun rewriteTranscript(text: String, languageCode: String): Map<String, Any?> {
        val input = text.trim()
        if (input.isEmpty()) {
            return mapOf(
                "ok" to true,
                "text" to "",
                "engine" to "gemini_nano"
            )
        }

        if (Build.VERSION.SDK_INT < 26) {
            return mapOf(
                "ok" to false,
                "reason" to "android_api_too_old"
            )
        }

        val proofreader = createProofreader(languageCode)
            ?: return mapOf(
                "ok" to false,
                "reason" to "language_not_supported_by_gemini_nano_proofreading"
            )

        return try {
            var status = proofreader.checkFeatureStatus().get(15, TimeUnit.SECONDS)

            if (status == FeatureStatus.DOWNLOADABLE) {
                proofreader.downloadFeature(object : DownloadCallback {
                    override fun onDownloadStarted(bytesToDownload: Long) {
                        Log.d("NewsTube", "Gemini Nano download started: $bytesToDownload")
                    }

                    override fun onDownloadProgress(totalBytesDownloaded: Long) {
                        Log.d("NewsTube", "Gemini Nano download progress: $totalBytesDownloaded")
                    }

                    override fun onDownloadCompleted() {
                        Log.d("NewsTube", "Gemini Nano download completed")
                    }

                    override fun onDownloadFailed(e: GenAiException) {
                        Log.e("NewsTube", "Gemini Nano download failed", e)
                    }
                }).get(180, TimeUnit.SECONDS)

                status = proofreader.checkFeatureStatus().get(15, TimeUnit.SECONDS)
            }

            if (status == FeatureStatus.DOWNLOADING) {
                return mapOf(
                    "ok" to false,
                    "reason" to "model_downloading"
                )
            }

            if (status != FeatureStatus.AVAILABLE) {
                return mapOf(
                    "ok" to false,
                    "reason" to "feature_unavailable"
                )
            }

            proofreader.prepareInferenceEngine().get(30, TimeUnit.SECONDS)

            val request = ProofreadingRequest.builder(input).build()
            val result = proofreader.runInference(request).get(60, TimeUnit.SECONDS)
            val suggestions = result.results

            val best = suggestions.firstOrNull()?.text?.trim().orEmpty()

            if (best.isEmpty()) {
                mapOf(
                    "ok" to false,
                    "reason" to "empty_proofreading_result"
                )
            } else {
                mapOf(
                    "ok" to true,
                    "text" to best,
                    "engine" to "gemini_nano"
                )
            }
        } catch (e: Throwable) {
            mapOf(
                "ok" to false,
                "reason" to shortErr(e)
            )
        } finally {
            closeQuietly(proofreader)
        }
    }

    private fun createProofreader(languageCode: String): Proofreader? {
        val lang = toMlKitLanguage(languageCode) ?: return null

        val options = ProofreaderOptions.builder(context)
            .setLanguage(lang)
            .build()

        return Proofreading.getClient(options)
    }

    private fun toMlKitLanguage(languageCode: String): Int? {
        return when (normalizeLanguage(languageCode)) {
            "en" -> ProofreaderOptions.Language.ENGLISH
            "ja" -> ProofreaderOptions.Language.JAPANESE
            "fr" -> ProofreaderOptions.Language.FRENCH
            "de" -> ProofreaderOptions.Language.GERMAN
            "it" -> ProofreaderOptions.Language.ITALIAN
            "es" -> ProofreaderOptions.Language.SPANISH
            "ko" -> ProofreaderOptions.Language.KOREAN
            else -> null
        }
    }

    private fun normalizeLanguage(languageCode: String): String {
        val l = languageCode.trim().lowercase()

        return when {
            l.startsWith("en") -> "en"
            l.startsWith("ja") -> "ja"
            l.startsWith("fr") -> "fr"
            l.startsWith("de") -> "de"
            l.startsWith("it") -> "it"
            l.startsWith("es") -> "es"
            l.startsWith("ko") -> "ko"
            else -> l
        }
    }

    private fun shortErr(t: Throwable): String {
        val s = "${t.javaClass.simpleName}: ${t.message ?: "unknown"}"
        return if (s.length <= 240) s else s.substring(0, 240) + "…"
    }

    private fun closeQuietly(proofreader: Proofreader?) {
        try {
            proofreader?.close()
        } catch (_: Throwable) {
        }
    }
}