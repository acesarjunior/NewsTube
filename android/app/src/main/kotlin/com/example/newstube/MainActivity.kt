package com.example.newstube

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.schabi.newpipe.extractor.NewPipe
import org.schabi.newpipe.extractor.ServiceList
import org.schabi.newpipe.extractor.search.SearchInfo
import org.schabi.newpipe.extractor.stream.StreamInfo

class MainActivity : FlutterActivity() {

    private val CHANNEL = "newstube/extractor"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        NewPipe.init(OkHttpDownloader())
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {

                    "getCaptions" -> {
                        val url = call.argument<String>("url") ?: ""
                        val preferLang = call.argument<String>("preferLang") ?: "pt"
                        if (url.isBlank()) {
                            result.error("ARG", "URL vazia", null)
                            return@setMethodCallHandler
                        }

                        Thread {
                            try {
                                val info = StreamInfo.getInfo(ServiceList.YouTube, url)

                                // ✅ reflexão (compatível com versões diferentes)
                                val found = findCaptionUrlByReflection(info, preferLang)

                                if (found == null) {
                                    result.success(hashMapOf<String, Any?>("hasCaptions" to false))
                                } else {
                                    result.success(
                                        hashMapOf(
                                            "hasCaptions" to true,
                                            "captionUrl" to found.first,
                                            "captionLang" to found.second
                                        )
                                    )
                                }
                            } catch (e: Exception) {
                                result.error("CAPTION_FAIL", shortErr(e), null)
                            }
                        }.start()
                    }

                    "searchVideos" -> {
                        val query = call.argument<String>("query") ?: ""
                        if (query.isBlank()) {
                            result.success(emptyList<Map<String, Any?>>())
                            return@setMethodCallHandler
                        }

                        Thread {
                            try {
                                val items = doSearchItems(query)
                                val out = ArrayList<Map<String, Any?>>()

                                for (obj in items) {
                                    val u = tryGetString(obj, "url") ?: continue
                                    val looksLikeVideo = u.contains("watch", true) || u.contains("youtu.be", true)
                                    if (!looksLikeVideo) continue

                                    val title = (tryGetString(obj, "name") ?: "").trim()
                                    val uploader = (tryGetString(obj, "uploaderName") ?: "").trim()
                                    if (title.isBlank() || uploader.isBlank()) continue

                                    out.add(
                                        hashMapOf(
                                            "videoUrl" to normalizeYouTubeUrl(u),
                                            "title" to title,
                                            "channel" to uploader,
                                            "thumb" to tryGetThumbUrl(obj),
                                            "publishedMillis" to extractPublishedMillis(obj),
                                            "publishedText" to extractPublishedText(obj)
                                        )
                                    )
                                }

                                out.sortWith { a, b ->
                                    val am = (a["publishedMillis"] as? Long) ?: 0L
                                    val bm = (b["publishedMillis"] as? Long) ?: 0L
                                    val aHas = am > 0
                                    val bHas = bm > 0
                                    when {
                                        aHas && !bHas -> -1
                                        !aHas && bHas -> 1
                                        aHas && bHas -> (bm - am).coerceIn(Int.MIN_VALUE.toLong(), Int.MAX_VALUE.toLong()).toInt()
                                        else -> 0
                                    }
                                }

                                result.success(out)
                            } catch (e: Exception) {
                                result.error("SEARCH_FAIL", shortErr(e), null)
                            }
                        }.start()
                    }

                    "searchChannels" -> {
                        val query = call.argument<String>("query") ?: ""
                        if (query.isBlank()) {
                            result.success(emptyList<Map<String, Any?>>())
                            return@setMethodCallHandler
                        }

                        Thread {
                            try {
                                val items = doSearchItems(query)
                                val out = ArrayList<Map<String, Any?>>()

                                for (obj in items) {
                                    val u = tryGetString(obj, "url") ?: continue
                                    val looksLikeChannel =
                                        u.contains("/channel/", true) ||
                                                u.contains("/@", true) ||
                                                u.contains("/user/", true) ||
                                                u.contains("/c/", true)
                                    if (!looksLikeChannel) continue

                                    val title = (tryGetString(obj, "name") ?: "").trim()
                                    if (title.isBlank()) continue

                                    out.add(
                                        hashMapOf(
                                            "channelUrl" to normalizeChannelUrl(u),
                                            "title" to title,
                                            "thumb" to tryGetThumbUrl(obj)
                                        )
                                    )
                                }

                                result.success(out)
                            } catch (e: Exception) {
                                result.error("SEARCH_FAIL", shortErr(e), null)
                            }
                        }.start()
                    }

                    "getChannelVideos" -> {
                        val rawUrl = call.argument<String>("channelUrl") ?: ""
                        val limit = call.argument<Int>("limit") ?: 30
                        if (rawUrl.isBlank()) {
                            result.error("ARG", "channelUrl vazio", null)
                            return@setMethodCallHandler
                        }

                        Thread {
                            try {
                                val channelUrl = normalizeChannelUrl(rawUrl)
                                val vids = channelVideosViaTabs(channelUrl, limit)
                                result.success(vids)
                            } catch (e: Exception) {
                                result.error("CHANNEL_FAIL", shortErr(e), null)
                            }
                        }.start()
                    }

                    else -> result.notImplemented()
                }
            }
    }

    // =========================
    // CAPTIONS via reflexão
    // =========================
    private fun findCaptionUrlByReflection(streamInfo: Any, preferLang: String): Pair<String, String>? {
        val containers = arrayOf(
            "getSubtitles",
            "getSubtitleTracks",
            "getCaptions",
            "getClosedCaptions",
            "getSubtitlesDefault"
        )

        for (mName in containers) {
            try {
                val m = streamInfo.javaClass.methods.firstOrNull { it.name == mName && it.parameterTypes.isEmpty() } ?: continue
                val container = m.invoke(streamInfo) ?: continue

                val tracksDirect = asListOrNull(container)
                if (tracksDirect != null && tracksDirect.isNotEmpty()) {
                    val pick = pickTrack(tracksDirect, preferLang)
                    val url = getTrackUrl(pick)
                    val lang = getTrackLang(pick)
                    if (!url.isNullOrBlank()) return Pair(url, lang ?: "")
                }

                val tracks = extractTracksFromContainer(container)
                if (tracks != null && tracks.isNotEmpty()) {
                    val pick = pickTrack(tracks, preferLang)
                    val url = getTrackUrl(pick)
                    val lang = getTrackLang(pick)
                    if (!url.isNullOrBlank()) return Pair(url, lang ?: "")
                }
            } catch (_: Throwable) {}
        }

        return null
    }

    private fun extractTracksFromContainer(container: Any): List<Any>? {
        val names = arrayOf("getAvailableTracks", "getTracks", "getCaptionTracks", "getSubtitles")
        for (n in names) {
            try {
                val m = container.javaClass.methods.firstOrNull { it.name == n && it.parameterTypes.isEmpty() } ?: continue
                val v = m.invoke(container) ?: continue
                val list = asListOrNull(v)
                if (list != null) return list
            } catch (_: Throwable) {}
        }
        return null
    }

    private fun asListOrNull(v: Any): List<Any>? {
        return try {
            if (v is List<*>) v.filterNotNull() as List<Any> else null
        } catch (_: Throwable) {
            null
        }
    }

    private fun pickTrack(tracks: List<Any>, preferLang: String): Any {
        val pref = preferLang.lowercase()
        for (t in tracks) {
            val lang = (getTrackLang(t) ?: "").lowercase()
            if (lang.startsWith(pref)) return t
        }
        return tracks[0]
    }

    private fun getTrackUrl(track: Any): String? {
        val names = arrayOf("getUrl", "getContent", "getCaptionUrl", "getSubtitleUrl", "url")
        for (n in names) {
            try {
                val m = track.javaClass.methods.firstOrNull { it.name == n && it.parameterTypes.isEmpty() }
                val v = m?.invoke(track)
                if (v is String && v.isNotBlank()) return v
            } catch (_: Throwable) {}
        }
        return null
    }

    private fun getTrackLang(track: Any): String? {
        val names = arrayOf("getLanguageCode", "getLang", "getLanguage", "languageCode", "lang")
        for (n in names) {
            try {
                val m = track.javaClass.methods.firstOrNull { it.name == n && it.parameterTypes.isEmpty() }
                val v = m?.invoke(track)
                if (v is String && v.isNotBlank()) return v
            } catch (_: Throwable) {}
        }
        return null
    }

    // =========================
    // CHANNEL VIDEOS via tabs
    // =========================
    private fun channelVideosViaTabs(channelUrl: String, limit: Int): List<Map<String, Any?>> {
        val service = ServiceList.YouTube

        val channelInfo = run {
            val ciClass = Class.forName("org.schabi.newpipe.extractor.channel.ChannelInfo")
            val m = ciClass.methods.firstOrNull { it.name == "getInfo" && it.parameterTypes.size == 2 }
                ?: throw IllegalStateException("ChannelInfo.getInfo(service, url) não encontrado")
            m.invoke(null, service, channelUrl)
        }

        val channelTitle = (tryGetString(channelInfo, "name") ?: "").trim()

        val tabs: List<Any> = run {
            val m = channelInfo.javaClass.methods.firstOrNull { it.name == "getTabs" && it.parameterTypes.isEmpty() }
            val v = m?.invoke(channelInfo)
            if (v is List<*>) v.filterNotNull() as List<Any> else emptyList()
        }

        if (tabs.isEmpty()) {
            val items = extractItemsFromAny(channelInfo)
            return itemsToVideoMaps(items, channelTitle, limit)
        }

        val pickedTab = tabs.firstOrNull { tab ->
            val name = ((tryGetString(tab, "name") ?: tryGetString(tab, "title") ?: "")).lowercase()
            name.contains("video") || name.contains("vídeo") || name.contains("stream")
        } ?: tabs[0]

        val tabUrl =
            tryGetString(pickedTab, "url")
                ?: tryGetString(pickedTab, "tabUrl")
                ?: tryGetString(pickedTab, "link")

        if (!tabUrl.isNullOrBlank()) {
            val tabInfo = tryChannelTabInfoGetInfo(service, tabUrl)
            if (tabInfo != null) {
                val items = extractItemsFromAny(tabInfo)
                val list = itemsToVideoMaps(items, channelTitle, limit)
                if (list.isNotEmpty()) return sortByDate(list)
            }
        }

        val tabExtractor = tryGetTabExtractor(pickedTab)
        if (tabExtractor != null) {
            tryFetch(tabExtractor)
            val items = extractItemsFromAny(tabExtractor)
            val list = itemsToVideoMaps(items, channelTitle, limit)
            if (list.isNotEmpty()) return sortByDate(list)
        }

        val items = extractItemsFromAny(channelInfo)
        return sortByDate(itemsToVideoMaps(items, channelTitle, limit))
    }

    private fun sortByDate(list: List<Map<String, Any?>>): List<Map<String, Any?>> {
        val out = ArrayList(list)
        out.sortWith { a, b ->
            val am = (a["publishedMillis"] as? Long) ?: 0L
            val bm = (b["publishedMillis"] as? Long) ?: 0L
            val aHas = am > 0
            val bHas = bm > 0
            when {
                aHas && !bHas -> -1
                !aHas && bHas -> 1
                aHas && bHas -> (bm - am).coerceIn(Int.MIN_VALUE.toLong(), Int.MAX_VALUE.toLong()).toInt()
                else -> 0
            }
        }
        return out
    }

    private fun tryChannelTabInfoGetInfo(service: Any, tabUrl: String): Any? {
        val candidates = listOf(
            "org.schabi.newpipe.extractor.channel.tabs.ChannelTabInfo",
            "org.schabi.newpipe.extractor.channel.ChannelTabInfo"
        )
        for (cn in candidates) {
            try {
                val cls = Class.forName(cn)
                val m = cls.methods.firstOrNull { it.name == "getInfo" && it.parameterTypes.size == 2 }
                if (m != null) return m.invoke(null, service, tabUrl)
            } catch (_: Throwable) {}
        }
        return null
    }

    private fun tryGetTabExtractor(tab: Any): Any? {
        try {
            val m = tab.javaClass.methods.firstOrNull { it.name == "getContent" && it.parameterTypes.isEmpty() }
            val v = m?.invoke(tab)
            if (v != null) return v
        } catch (_: Throwable) {}

        try {
            val m = tab.javaClass.methods.firstOrNull { it.name == "getTabExtractor" && it.parameterTypes.isEmpty() }
            val v = m?.invoke(tab)
            if (v != null) return v
        } catch (_: Throwable) {}

        return null
    }

    private fun extractItemsFromAny(obj: Any): List<Any> {
        val candidates = listOf("getItems", "getRelatedItems", "getStreams", "getVideoStreams")
        for (name in candidates) {
            try {
                val m = obj.javaClass.methods.firstOrNull { it.name == name && it.parameterTypes.isEmpty() }
                val v = m?.invoke(obj)
                if (v is List<*>) {
                    val list = v.filterNotNull()
                    if (list.isNotEmpty()) return list as List<Any>
                }
            } catch (_: Throwable) {}
        }
        return emptyList()
    }

    private fun itemsToVideoMaps(itemsRaw: List<Any>, channelTitleFallback: String, limit: Int): List<Map<String, Any?>> {
        val out = ArrayList<Map<String, Any?>>()
        for (obj in itemsRaw) {
            if (out.size >= limit) break

            val url0 = tryGetString(obj, "url") ?: continue
            val url = normalizeYouTubeUrl(url0)

            val looksLikeVideo = url.contains("watch", true) || url.contains("youtu.be", true)
            if (!looksLikeVideo) continue

            val title = (tryGetString(obj, "name") ?: "").trim()
            if (title.isEmpty()) continue

            val uploader = (tryGetString(obj, "uploaderName") ?: channelTitleFallback).trim()

            out.add(
                hashMapOf(
                    "videoUrl" to url,
                    "title" to title,
                    "channel" to uploader,
                    "thumb" to tryGetThumbUrl(obj),
                    "publishedMillis" to extractPublishedMillis(obj),
                    "publishedText" to extractPublishedText(obj)
                )
            )
        }
        return out
    }

    // =========================
    // SEARCH helpers
    // =========================
    private fun doSearchItems(query: String): List<Any> {
        val service: Any = ServiceList.YouTube
        val extractor = tryCreateSearchExtractor(service, query)
            ?: throw IllegalStateException("Não foi possível criar SearchExtractor.")

        tryFetch(extractor)

        val info = run {
            val m = SearchInfo::class.java.methods.firstOrNull { it.name == "getInfo" && it.parameterTypes.size == 1 }
                ?: throw IllegalStateException("SearchInfo.getInfo(extractor) não encontrado.")
            m.invoke(null, extractor) as SearchInfo
        }

        return extractItemsList(info)
    }

    private fun tryFetch(extractor: Any) {
        try {
            val m = extractor.javaClass.methods.firstOrNull { it.name == "fetchPage" && it.parameterTypes.isEmpty() }
            if (m != null) { m.invoke(extractor); return }
        } catch (_: Throwable) {}

        try {
            val m = extractor.javaClass.methods.firstOrNull { it.name == "fetch" && it.parameterTypes.isEmpty() }
            if (m != null) { m.invoke(extractor); return }
        } catch (_: Throwable) {}
    }

    private fun tryCreateSearchExtractor(service: Any, query: String): Any? {
        try {
            val m = service.javaClass.methods.firstOrNull { it.name == "getSearchExtractor" && it.parameterTypes.size == 1 }
            if (m != null) return m.invoke(service, query)
        } catch (_: Throwable) {}

        try {
            val m = service.javaClass.methods.firstOrNull { it.name == "searchExtractor" && it.parameterTypes.size == 1 }
            if (m != null) return m.invoke(service, query)
        } catch (_: Throwable) {}

        return null
    }

    private fun extractItemsList(info: SearchInfo): List<Any> {
        try {
            val m = info.javaClass.methods.firstOrNull { it.name == "getItems" && it.parameterTypes.isEmpty() }
            val v = m?.invoke(info)
            if (v is List<*>) return v.filterNotNull()
        } catch (_: Throwable) {}

        try {
            val m = info.javaClass.methods.firstOrNull { it.name == "getRelatedItems" && it.parameterTypes.isEmpty() }
            val v = m?.invoke(info)
            if (v is List<*>) return v.filterNotNull()
        } catch (_: Throwable) {}

        return emptyList()
    }

    // =========================
    // misc helpers
    // =========================
    private fun tryGetString(obj: Any, field: String): String? {
        return try {
            val getter = "get" + field.replaceFirstChar { it.uppercase() }
            val m = obj.javaClass.methods.firstOrNull { it.name == getter && it.parameterTypes.isEmpty() }
            val v = m?.invoke(obj)
            if (v is String) v else null
        } catch (_: Throwable) {
            null
        }
    }

    private fun tryGetThumbUrl(obj: Any): String {
        return try {
            val m = obj.javaClass.methods.firstOrNull { it.name == "getThumbnails" }
            val thumbs = m?.invoke(obj)
            if (thumbs is List<*>) {
                val first = thumbs.firstOrNull()
                val urlM = first?.javaClass?.methods?.firstOrNull { it.name == "getUrl" }
                val u = urlM?.invoke(first)
                if (u is String) u else ""
            } else ""
        } catch (_: Throwable) {
            ""
        }
    }

    private fun extractPublishedMillis(obj: Any): Long {
        val methodNames = listOf("getUploadDate", "getPublishDate", "getPublishedDate", "getDate")
        for (mn in methodNames) {
            try {
                val m = obj.javaClass.methods.firstOrNull { it.name == mn && it.parameterTypes.isEmpty() } ?: continue
                val v = m.invoke(obj) ?: continue
                when (v) {
                    is java.util.Date -> return v.time
                    is Long -> return v
                    is Number -> return v.toLong()
                }
            } catch (_: Throwable) {}
        }
        return 0L
    }

    private fun extractPublishedText(obj: Any): String {
        val methodNames = listOf("getTextualUploadDate", "getTextualPublishDate", "getUploadDate", "getPublishDate")
        for (mn in methodNames) {
            try {
                val m = obj.javaClass.methods.firstOrNull { it.name == mn && it.parameterTypes.isEmpty() } ?: continue
                val v = m.invoke(obj) ?: continue
                if (v is String) {
                    val s = v.trim()
                    if (s.isNotEmpty()) return s
                }
            } catch (_: Throwable) {}
        }
        return ""
    }

    private fun normalizeChannelUrl(input: String): String {
        val s = input.trim()
        if (s.isEmpty()) return s
        if (s.startsWith("http://") || s.startsWith("https://")) return s
        if (s.startsWith("UC") && s.length > 10) return "https://www.youtube.com/channel/$s"
        if (s.startsWith("@")) return "https://www.youtube.com/$s"
        return "https://www.youtube.com/$s"
    }

    private fun normalizeYouTubeUrl(url: String): String {
        val u = url.trim()
        if (u.startsWith("http://") || u.startsWith("https://")) return u
        if (u.startsWith("/")) return "https://www.youtube.com$u"
        return "https://www.youtube.com/$u"
    }

    private fun shortErr(e: Exception): String {
        val s = e.toString()
        return if (s.length <= 220) s else s.substring(0, 220) + "…"
    }
}
