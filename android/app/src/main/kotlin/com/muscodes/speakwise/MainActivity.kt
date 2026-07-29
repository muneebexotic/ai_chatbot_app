package com.muscodes.speakwise

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
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
 * ## Why this does NOT request audio focus
 *
 * The first version did, and it broke every session on the first try.
 *
 * The reasoning looked sound: hold `AUDIOFOCUS_GAIN_TRANSIENT`, and
 * `AUDIOFOCUS_LOSS_TRANSIENT` then reports an incoming call for free, with no
 * `READ_PHONE_STATE` permission and nothing added to the Play data-safety form
 * (§10.7). It also covers alarms, navigation prompts and other media apps.
 *
 * What it missed is that **this app's own components request audio focus too.**
 * `SpeechRecognizer` takes focus when it starts listening and `TextToSpeech`
 * takes it when it speaks — so the Activity's request was immediately displaced
 * by the recogniser it exists to support, the listener fired `AUDIOFOCUS_LOSS`,
 * and the session paused with "Something else took the audio" before the user
 * had said a word. The app was losing focus to itself.
 *
 * So focus is left to the plugins that actually play and capture audio, and
 * this class only *observes*:
 *
 * * `ACTION_AUDIO_BECOMING_NOISY` — the documented signal for headphones being
 *   pulled out. It needs no focus and no permission.
 * * `OnModeChangedListener` (API 31+) — the audio mode entering a call state.
 *   Below API 31 there is no permission-free equivalent, and the session still
 *   reacts: a call takes the microphone, the recogniser errors, and that
 *   surfaces as an interruption through the ordinary path. Less precise
 *   wording, same behaviour.
 *
 * ## What this does NOT do
 *
 * It does not record, buffer, or read any audio. R4.2.7 is a selling point as
 * well as a requirement, and this class holds no microphone handle — only a
 * broadcast receiver and a mode listener, both of which are notifications
 * about audio rather than access to it.
 */
class MainActivity : FlutterActivity() {

    private companion object {
        const val CHANNEL = "com.muscodes.speakwise/audio_interruptions"
    }

    private var events: EventChannel.EventSink? = null
    private var noisyReceiver: BroadcastReceiver? = null
    private var modeListener: AudioManager.OnModeChangedListener? = null

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

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val listener = AudioManager.OnModeChangedListener { mode ->
                // Only a call. MODE_NORMAL and MODE_IN_COMMUNICATION are both
                // reached by this app's own recogniser and synthesiser, so
                // neither may pause the session — that was the whole mistake
                // the focus-based version made.
                if (mode == AudioManager.MODE_IN_CALL ||
                    mode == AudioManager.MODE_RINGTONE
                ) {
                    emit("call_started")
                }
            }
            modeListener = listener
            audioManager.addOnModeChangedListener(mainExecutor, listener)
        }
    }

    private fun stopWatching() {
        noisyReceiver?.let {
            // Unregistering a receiver that is already gone throws. It can
            // happen if the activity is torn down between onCancel and here.
            runCatching { unregisterReceiver(it) }
        }
        noisyReceiver = null

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            modeListener?.let {
                runCatching { audioManager.removeOnModeChangedListener(it) }
            }
        }
        modeListener = null
    }

    override fun onDestroy() {
        stopWatching()
        super.onDestroy()
    }
}
