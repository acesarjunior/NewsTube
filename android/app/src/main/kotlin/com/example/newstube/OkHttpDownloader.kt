package com.example.newstube

import okhttp3.MediaType.Companion.toMediaTypeOrNull
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody
import okhttp3.RequestBody.Companion.toRequestBody
import org.schabi.newpipe.extractor.downloader.Downloader
import org.schabi.newpipe.extractor.downloader.Request as NPRequest
import org.schabi.newpipe.extractor.downloader.Response

class OkHttpDownloader : Downloader() {

    private val client = OkHttpClient.Builder()
        .followRedirects(true)
        .followSslRedirects(true)
        .build()

    override fun execute(request: NPRequest): Response {
        val method = request.httpMethod().uppercase()
        val url = request.url()

        val builder = Request.Builder().url(url)

        // headers: Map<String, List<String>>
        val headerMap = request.headers()
        for ((k, values) in headerMap) {
            for (v in values) builder.addHeader(k, v)
        }

        // Content-Type (se o extractor já definiu)
        val contentType = headerMap.entries
            .firstOrNull { it.key.equals("Content-Type", ignoreCase = true) }
            ?.value
            ?.firstOrNull()
            ?.trim()
            ?.takeIf { it.isNotEmpty() }
            ?: "application/x-www-form-urlencoded"

        val body: RequestBody? = when (method) {
            "GET", "HEAD" -> null
            else -> {
                val bytes = tryGetRequestBytes(request)
                if (bytes != null && bytes.isNotEmpty()) {
                    bytes.toRequestBody(contentType.toMediaTypeOrNull())
                } else {
                    // Mesmo sem bytes, OkHttp exige body em POST/PUT/PATCH etc.
                    "".toRequestBody(contentType.toMediaTypeOrNull())
                }
            }
        }

        builder.method(method, body)

        val resp = client.newCall(builder.build()).execute()

        val headers: Map<String, List<String>> = resp.headers.toMultimap()
        val bodyString: String? = resp.body?.string()
        val finalUrl = resp.request.url.toString()

        return Response(
            resp.code,
            resp.message,
            headers,
            bodyString,
            finalUrl
        )
    }

    /**
     * Extrai bytes do NPRequest. O NewPipeExtractor muda nomes entre versões,
     * então tentamos vários getters via reflexão.
     */
    private fun tryGetRequestBytes(req: NPRequest): ByteArray? {
        val candidates = listOf(
            "dataToSend", "getDataToSend",
            "data", "getData",
            "postData", "getPostData",
            "body", "getBody",
            "requestBody", "getRequestBody"
        )

        for (name in candidates) {
            try {
                val m = req.javaClass.methods.firstOrNull { it.name == name && it.parameterTypes.isEmpty() }
                if (m != null) {
                    val v = m.invoke(req)
                    when (v) {
                        is ByteArray -> return v
                        is String -> return v.toByteArray(Charsets.UTF_8)
                        else -> {
                            // Algumas versões podem retornar outro tipo; ignorar
                        }
                    }
                }
            } catch (_: Throwable) {
                // tenta o próximo
            }
        }
        return null
    }
}
