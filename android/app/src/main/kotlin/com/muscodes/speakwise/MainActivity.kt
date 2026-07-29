package com.muscodes.speakwise

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel

/**
 * Audio interruptions for the live session — PRD R4.2.6.
 *
 * R4.2.6: "Interruptions handled gracefully: incoming phone call, app
 * backgrounded, headphones disconnected, network loss. Each pauses the session
 * and offers resume; nothing is lost."
 *
 * Dart can see two of those four. `AppLifecycleListener` covers backgrounding
 * and `connectivity_plus` covers the network. The other two are Android audio
 * concepts with no Flutter equivalent, which is why this file exists.
 *
 * ## Why audio focus rather than the telephony API
 *
 * Detecting a call with `READ_PHONE_STATE` would work and is the wrong trade.
 * It is a runtime permission, it appears on the Play data-safety form as access
 * to phone state, and §10.7 says not to collect more personal data than §9.5
 * lists. Audio focus gives the same signal — `AUDIOFOCUS_LOSS_TRANSIENT` fires
 * when a call arrives — for no permission at all, and it additionally covers
 * every other app that takes the audio: an alarm, a navigation prompt, another
 * media app.
 *
 * `ACTION_AUDIO_BECOMING_NOISY` is the documented signal for headphones being
 * pulled out. It is not the same event as focus loss and does not imply it,
 * which is why both are needed.
 *
 * ## What this does NOT do
 *
 * It does not record, buffer, or read any audio. R4.2.7 is a selling point as
 * well as a requirement, and this class holds no microphone handle — only a
 * focus request and a broadcast receiver, both of which are notifications
 * about audio rather than access to it.
 */
class MainActivity : FlutterActivity() {

    private companion object {
        const val CHANNEL = "com.muscodes.speakwise/audio_interruptions"
    }

    private var events: EventChannel.EventSink? = null
    private var focusRequest: AudioFocusRequest? = null
    private var noisyReceiver: BroadcastReceiver? = null

    private val audioManager: AudioManager
        get() = getSystemService(Context.AUDIO_SERVICE) as AudioManager

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
                    events = sink
                    startWatching()
                }

                override fun onCancel(arguments: Any?) {
                    stopWatching()
                    events = null
                }
            })
    }

    private fun emit(reason: String) {
        // Always on the main thread: Flutter's platform channels are not
        // thread-safe, and a broadcast receiver's callback is not guaranteed to
        // be on it.
        runOnUiThread { events?.success(reason) }
    }

    private fun startWatching() {
        val listener = AudioManager.OnAudioFocusChangeListener { change ->
            when (change) {
                // A call, an alarm, a navigation prompt, another media app.
                AudioManager.AUDIOFOCUS_LOSS,
                AudioManager.AUDIOFOCUS_LOSS_TRANSIENT ->
                    emit("audio_focus_lost")

                // Something wants us quieter rather than silent. The session
                // does not pause for this: ducking a text-to-speech voice for a
                // notification chime is normal, and pausing a practice session
                // for it would be the app being precious.
                AudioManager.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK -> Unit

                AudioManager.AUDIOFOCUS_GAIN -> emit("audio_focus_regained")
            }
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val attributes = AudioAttributes.Builder()
                // The session is a spoken conversation, not music. This is what
                // makes Android route it correctly to a headset and duck it
                // against navigation rather than stopping it.
                .setUsage(AudioAttributes.USAGE_VOICE_COMMUNICATION)
                .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                .build()

            focusRequest = AudioFocusRequest
                .Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
                .setAudioAttributes(attributes)
                .setOnAudioFocusChangeListener(listener)
                .build()
                .also { audioManager.requestAudioFocus(it) }
        } else {
            @Suppress("DEPRECATION")
            audioManager.requestAudioFocus(
                listener,
                AudioManager.STREAM_VOICE_CALL,
                AudioManager.AUDIOFOCUS_GAIN_TRANSIENT,
            )
        }

        noisyReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent?.action == AudioManager.ACTION_AUDIO_BECOMING_NOISY) {
                    emit("headphones_disconnected")
                }
            }
        }.also {
            registerReceiver(
                it,
                IntentFilter(AudioManager.ACTION_AUDIO_BECOMING_NOISY),
            )
        }
    }

    private fun stopWatching() {
        focusRequest?.let {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                audioManager.abandonAudioFocusRequest(it)
            }
        }
        focusRequest = null

        noisyReceiver?.let {
            // Unregistering a receiver that is already gone throws. It can
            // happen if the activity is torn down between onCancel and here.
            runCatching { unregisterReceiver(it) }
        }
        noisyReceiver = null
    }

    override fun onDestroy() {
        stopWatching()
        super.onDestroy()
    }
}
