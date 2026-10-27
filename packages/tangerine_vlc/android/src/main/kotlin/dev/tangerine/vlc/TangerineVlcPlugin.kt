package dev.tangerine.vlc

import android.content.Context
import android.content.BroadcastReceiver
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioManager
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.net.Uri
import android.view.Surface
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.TextureRegistry
import org.videolan.libvlc.LibVLC
import org.videolan.libvlc.Media
import org.videolan.libvlc.MediaPlayer
import org.videolan.libvlc.interfaces.IMedia
import kotlin.math.roundToInt

/** Each Flutter engine owns its channel and each session owns its VLC/texture. */
class TangerineVlcPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var binding: FlutterPlugin.FlutterPluginBinding
    private lateinit var channel: MethodChannel
    private val sessions = mutableMapOf<Long, Session>()
    private var serial = 0L
    override fun onAttachedToEngine(value: FlutterPlugin.FlutterPluginBinding) {
        binding = value
        channel = MethodChannel(value.binaryMessenger, "tangerine/playback")
        channel.setMethodCallHandler(this)
    }
    override fun onDetachedFromEngine(value: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        sessions.values.forEach { it.close() }; sessions.clear()
    }
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            val args = call.arguments as? Map<*, *> ?: emptyMap<Any, Any>()
            if (call.method == "create") {
                val id = ++serial
                val session = Session(binding.applicationContext, binding.textureRegistry, args["preferences"] as? Map<*, *> ?: emptyMap<Any, Any>())
                sessions[id] = session
                result.success(mapOf("id" to id, "textureId" to session.texture.id(), "capabilities" to session.capabilities)); return
            }
            if (call.method == "preferences.catalog") { result.success(emptyList<Any>()); return }
            val id = (args["id"] as? Number)?.toLong() ?: error("Invalid player")
            val session = sessions[id] ?: error("Player closed")
            if (call.method == "dispose") { sessions.remove(id)?.close(); result.success(null); return }
            result.success(session.command(call.method, args))
        } catch (e: Exception) { result.error("LIBVLC", e.message ?: "Native player failed", null) } catch(e:LinkageError){result.error("LIBVLC_RUNTIME","VideoLAN runtime is unavailable for this device architecture.",null)}
    }
    private class Session(private val context: Context, textures: TextureRegistry, preferences: Map<*, *>) {
        val texture = textures.createSurfaceTexture()
        private val surface = Surface(texture.surfaceTexture())
        private lateinit var vlc: LibVLC
        private lateinit var player: MediaPlayer
        private var vlcCreated=false
        private var playerCreated=false
        private var width = 0; private var height = 0
        private var completed = false; private var failed = false; private var buffering = false
        private var media: Media? = null
        private val audioManager=context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        private var receiverRegistered=false
        private var closed=false
        private var resumeAfterFocus=false
        private var focusHeld=false
        private val focusListener=AudioManager.OnAudioFocusChangeListener { change ->
            Handler(Looper.getMainLooper()).post {
                if(!closed) when(change) {
                    AudioManager.AUDIOFOCUS_GAIN -> { focusHeld=true; if(resumeAfterFocus) {resumeAfterFocus=false; player.play()} }
                    AudioManager.AUDIOFOCUS_LOSS -> { resumeAfterFocus=false; focusHeld=false; player.pause() }
                    AudioManager.AUDIOFOCUS_LOSS_TRANSIENT,AudioManager.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK -> { resumeAfterFocus=player.isPlaying; focusHeld=false; player.pause() }
                }
            }
        }
        private val focusRequest:AudioFocusRequest? by lazy {
            if(Build.VERSION.SDK_INT>=26) AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
                .setAudioAttributes(AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_MEDIA).setContentType(AudioAttributes.CONTENT_TYPE_MOVIE).build())
                .setWillPauseWhenDucked(true).setOnAudioFocusChangeListener(focusListener,Handler(Looper.getMainLooper())).build() else null
        }
        private val noisyReceiver=object:BroadcastReceiver() {
            override fun onReceive(context:Context,intent:Intent) {if(!closed && intent.action==AudioManager.ACTION_AUDIO_BECOMING_NOISY) {resumeAfterFocus=false;player.pause();abandonFocus()} }
        }
        @Suppress("DEPRECATION") private fun acquireFocus() {
            if(focusHeld)return
            val result=if(Build.VERSION.SDK_INT>=26)audioManager.requestAudioFocus(focusRequest!!) else audioManager.requestAudioFocus(focusListener,AudioManager.STREAM_MUSIC,AudioManager.AUDIOFOCUS_GAIN)
            check(result==AudioManager.AUDIOFOCUS_REQUEST_GRANTED){"Audio playback is interrupted. Return to the app and try again."};focusHeld=true
        }
        @Suppress("DEPRECATION") private fun abandonFocus() {
            resumeAfterFocus=false
            if(Build.VERSION.SDK_INT>=26)audioManager.abandonAudioFocusRequest(focusRequest!!) else audioManager.abandonAudioFocus(focusListener)
            focusHeld=false
        }
        private var equalizer: MediaPlayer.Equalizer? = null
        val capabilities = listOf("transport", "tracks", "chapters", "equalizer", "aspect", "zoom", "audioDelay", "subtitleDelay", "diagnostics")
        init {
          try {
            val options = arrayListOf("--no-video-title-show", "--no-snapshot-preview")
            val allowed = mapOf("fileCache" to "file-caching", "networkCache" to "network-caching", "audioLanguage" to "audio-language", "subtitleLanguage" to "sub-language", "encoding" to "subsdec-encoding", "decoder" to "codec")
            allowed.forEach { (key, option) ->
                val value = preferences[key] as? String
                if (value != null && value.length <= 256 && !value.contains('\u0000')) options.add("--$option=$value")
            }
            if (preferences["normalize"] == "true") {
                options.add("--audio-filter=normvol"); options.add("--norm-max-level=2")
            }
            mapOf("subtitleSize" to "freetype-fontsize", "subtitleColor" to "freetype-color").forEach { (key, option) ->
                val value = preferences[key] as? String
                if (value != null && value.length <= 10 && value.matches(Regex("[0-9]+"))) options.add("--$option=$value")
            }
            if (preferences["hardware"] == "none") options.add("--avcodec-hw=none")
            vlc = LibVLC(context, options); vlcCreated=true
            player = MediaPlayer(vlc); playerCreated=true
            texture.surfaceTexture().setDefaultBufferSize(1280, 720)
            player.vlcVout.setVideoSurface(surface, null)
            player.vlcVout.attachViews { _, w, h, _, _, _, _ ->
                width = w; height = h
                // Bound texture storage; VLC scales into this surface.
                val scale = minOf(1.0, 1920.0 / maxOf(1, w), 1080.0 / maxOf(1, h))
                texture.surfaceTexture().setDefaultBufferSize(maxOf(1, (w * scale).roundToInt()), maxOf(1, (h * scale).roundToInt()))
            }
            if(Build.VERSION.SDK_INT>=33)context.registerReceiver(noisyReceiver,IntentFilter(AudioManager.ACTION_AUDIO_BECOMING_NOISY),Context.RECEIVER_NOT_EXPORTED)
            else context.registerReceiver(noisyReceiver,IntentFilter(AudioManager.ACTION_AUDIO_BECOMING_NOISY))
            receiverRegistered=true
            player.setEventListener { event ->
                when (event.type) {
                    MediaPlayer.Event.EndReached -> {completed = true; abandonFocus()}
                    MediaPlayer.Event.EncounteredError -> {failed = true; abandonFocus()}
                    MediaPlayer.Event.Buffering -> buffering = event.buffering < 100f
                    MediaPlayer.Event.Playing -> buffering = false
                }
            }
          } catch (failure:Throwable) {close();throw failure}
        }
        private fun number(a: Map<*, *>, key: String):Double {val v=(a[key] as? Number)?.toDouble() ?: error("Missing $key");require(v.isFinite());return v}
        fun command(method: String, args: Map<*, *>): Any? {
            when (method) {
                "open" -> {
                    val uri = Uri.parse(args["uri"] as String)
                    require(uri.scheme in listOf("file", "http", "https", "rtsp", "rtmp", "udp", "rtp", "srt"))
                    player.stop(); media?.release(); media=null; completed = false; failed = false
                    acquireFocus();media = Media(vlc, uri); player.media = media; player.play()
                }
                "state" -> return mapOf(
                    "position" to maxOf(0L, player.time), "duration" to maxOf(0L, player.length),
                    "playing" to player.isPlaying, "completed" to completed, "error" to failed, "buffering" to buffering,
                    "volume" to player.volume, "rate" to player.rate.toDouble(), "width" to width, "height" to height,
                    "audioTrack" to player.audioTrack, "subtitleTrack" to player.spuTrack,
                    "audio" to (player.audioTracks?.take(128)?.map { mapOf("id" to it.id, "title" to it.name) } ?: emptyList()),
                    "subtitles" to (player.spuTracks?.take(128)?.map { mapOf("id" to it.id, "title" to it.name) } ?: emptyList()),
                    "chapter" to player.chapter, "chapters" to (player.getChapters(-1)?.size ?: 0),
                    "metadata" to mapOf("Title" to (media?.getMeta(IMedia.Meta.Title)?.take(2048)?:""),"Artist" to (media?.getMeta(IMedia.Meta.Artist)?.take(2048)?:""),"Album" to (media?.getMeta(IMedia.Meta.Album)?.take(2048)?:"")),
                    "statistics" to (media?.stats?.let{ mapOf("readBytes" to it.readBytes,"decodedVideo" to it.decodedVideo,"displayedPictures" to it.displayedPictures,"lostPictures" to it.lostPictures) }?:emptyMap<String,Int>()),
                    "version" to LibVLC.version(), "capabilities" to capabilities)
                "play" -> { acquireFocus();completed = false; player.play() }
                "pause" -> { player.pause(); abandonFocus() }
                "seek" -> player.setTime(number(args,"value").toLong().coerceAtLeast(0))
                "rate" -> { val v=number(args,"value"); require(v in 0.25..4.0); player.rate=v.toFloat() }
                "volume" -> player.setVolume(number(args,"value").toInt().coerceIn(0,100))
                "audioTrack" -> require(player.setAudioTrack(number(args,"value").toInt()))
                "subtitleTrack" -> require(player.setSpuTrack(number(args,"value").toInt()))
                "subtitle" -> require(player.addSlave(IMedia.Slave.Type.Subtitle, Uri.fromFile(java.io.File(args["value"] as String)), true))
                "chapter" -> player.chapter=number(args,"value").toInt().coerceAtLeast(0)
                "picture" -> {
                    if (args.containsKey("aspect")) player.aspectRatio=(args["aspect"] as String).ifEmpty { null }
                    if (args.containsKey("zoom")) player.scale=number(args,"zoom").toFloat().coerceIn(0f,5f)
                    if (args.containsKey("audioDelay")) player.setAudioDelay((number(args,"audioDelay")*1000000).toLong())
                    if (args.containsKey("subtitleDelay")) player.setSpuDelay((number(args,"subtitleDelay")*1000000).toLong())
                }
                "equalizer" -> {
                    if(args["enabled"] == true) {
                        val eq=equalizer ?: MediaPlayer.Equalizer.create().also { equalizer=it }
                        eq.setPreAmp(number(args,"preamp").toFloat().coerceIn(-20f,20f))
                        (args["bands"] as List<*>).take(10).forEachIndexed { i, value -> eq.setAmp(i,(value as Number).toFloat().coerceIn(-20f,20f)) }
                        require(player.setEqualizer(eq))
                    } else { require(player.setEqualizer(null)); equalizer=null }
                }
                else -> error("Unsupported native action: $method")
            }
            return null
        }
        fun close() {
            if(closed)return;closed=true
            runCatching { abandonFocus() }
            if(receiverRegistered){runCatching {context.unregisterReceiver(noisyReceiver)};receiverRegistered=false}
            if(playerCreated) {
                runCatching {player.setEventListener(null)}
                runCatching {player.stop()}
                runCatching {player.vlcVout.detachViews()}
                runCatching {player.setEqualizer(null)};equalizer=null
                runCatching {player.release()}
            }
            runCatching {media?.release()};media=null
            if(vlcCreated)runCatching {vlc.release()}
            runCatching {surface.release()};runCatching {texture.release()}
        }
    }
}
