package com.fixnow.fixnow_mobile

import android.content.Context
import android.content.Intent
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.media.AudioAttributes
import android.media.AudioDeviceInfo
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioRecord
import android.media.AudioTrack
import android.media.MediaPlayer
import android.media.MediaRecorder
import android.media.RingtoneManager
import android.media.ToneGenerator
import android.net.Uri
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val NAVIGATION_CHANNEL = "com.fixnow.mobile/navigation"
    private val AUDIO_TONE_CHANNEL = "com.fixnow.mobile/audio_tone"
    private val VOICE_STREAM_CHANNEL = "com.fixnow.mobile/voice_stream"

    private var toneGenerator: ToneGenerator? = null
    private var mediaPlayer: MediaPlayer? = null
    private var vibrator: Vibrator? = null

    // VoIP Real-Time Voice Streaming & Hardware Proximity
    private var voiceChannel: MethodChannel? = null
    private var audioRecord: AudioRecord? = null
    private var audioTrack: AudioTrack? = null
    @Volatile private var isVoiceStreaming = false
    @Volatile private var isVoiceMuted = false
    private var voiceRecordingThread: Thread? = null
    private val SAMPLE_RATE = 16000
    private var sensorManager: SensorManager? = null
    private var proximitySensor: Sensor? = null
    private var proximityListener: SensorEventListener? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Navigation Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NAVIGATION_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "openNavigation") {
                val lat = call.argument<Double>("latitude")
                val lng = call.argument<Double>("longitude")
                val label = call.argument<String>("label") ?: "Customer Location"

                if (lat != null && lng != null) {
                    try {
                        val gmmIntentUri = Uri.parse("google.navigation:q=$lat,$lng&mode=d")
                        val mapIntent = Intent(Intent.ACTION_VIEW, gmmIntentUri)
                        mapIntent.setPackage("com.google.android.apps.maps")
                        if (mapIntent.resolveActivity(packageManager) != null) {
                            startActivity(mapIntent)
                            result.success(true)
                        } else {
                            val geoUri = Uri.parse("geo:$lat,$lng?q=$lat,$lng($label)")
                            val fallbackIntent = Intent(Intent.ACTION_VIEW, geoUri)
                            startActivity(fallbackIntent)
                            result.success(true)
                        }
                    } catch (e: Exception) {
                        result.error("NAVIGATION_ERROR", e.message, null)
                    }
                } else {
                    result.error("INVALID_COORDINATES", "Latitude and Longitude cannot be null", null)
                }
            } else {
                result.notImplemented()
            }
        }

        // Audio Tone & Ringtone Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AUDIO_TONE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "playRingback" -> {
                    playRingback()
                    result.success(true)
                }
                "playIncomingRingtone" -> {
                    playIncomingRingtone()
                    result.success(true)
                }
                "stopAudio" -> {
                    stopAudio()
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // Voice Streaming Channel (Mic Recording & Speaker Playback)
        voiceChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, VOICE_STREAM_CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "startVoiceStream" -> {
                        val isSpeaker = call.argument<Boolean>("isSpeaker") ?: true
                        startVoiceStream(isSpeaker)
                        result.success(true)
                    }
                    "playVoiceChunk" -> {
                        val arg = call.argument<Any>("chunk")
                        val bytes: ByteArray? = when (arg) {
                            is ByteArray -> arg
                            is List<*> -> ByteArray(arg.size) { (arg[it] as Number).toByte() }
                            else -> null
                        }
                        if (bytes != null && bytes.isNotEmpty()) {
                            playVoiceChunk(bytes)
                            result.success(true)
                        } else {
                            result.error("INVALID_CHUNK", "Chunk cannot be null or empty", null)
                        }
                    }
                    "setVoiceMute" -> {
                        isVoiceMuted = call.argument<Boolean>("isMuted") ?: false
                        Log.i("FixNowAudio", "Set voice mute: $isVoiceMuted")
                        result.success(true)
                    }
                    "setSpeakerphone" -> {
                        val isSpeaker = call.argument<Boolean>("isSpeaker") ?: true
                        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                        applySpeakerphone(audioManager, isSpeaker)
                        result.success(true)
                    }
                    "stopVoiceStream" -> {
                        stopVoiceStream()
                        result.success(true)
                    }
                    else -> {
                        result.notImplemented()
                    }
                }
            }
        }
    }

    private fun playRingback() {
        stopAudio()
        try {
            // STREAM_MUSIC routes through loudspeaker so caller clearly hears telecom ringback
            toneGenerator = ToneGenerator(AudioManager.STREAM_MUSIC, 100)
            toneGenerator?.startTone(ToneGenerator.TONE_SUP_RINGTONE, -1)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun playIncomingRingtone() {
        stopAudio()
        try {
            // Start vibrator
            vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vm = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager
                vm?.defaultVibrator ?: (getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator)
            } else {
                @Suppress("DEPRECATION")
                getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
            }

            val pattern = longArrayOf(0, 1000, 1000)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator?.vibrate(VibrationEffect.createWaveform(pattern, 0))
            } else {
                @Suppress("DEPRECATION")
                vibrator?.vibrate(pattern, 0)
            }

            // Play loud audible ringtone via MediaPlayer on STREAM_MUSIC (audible even in silent/vibrate mode)
            val uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
                ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)

            if (uri != null) {
                try {
                    mediaPlayer = MediaPlayer().apply {
                        setAudioAttributes(
                            AudioAttributes.Builder()
                                .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                                .setUsage(AudioAttributes.USAGE_MEDIA)
                                .setLegacyStreamType(AudioManager.STREAM_MUSIC)
                                .build()
                        )
                        setDataSource(applicationContext, uri)
                        isLooping = true
                        prepare()
                        start()
                    }
                } catch (mpEx: Exception) {
                    toneGenerator = ToneGenerator(AudioManager.STREAM_MUSIC, 100)
                    toneGenerator?.startTone(ToneGenerator.TONE_CDMA_CALL_SIGNAL_ISDN_NORMAL, -1)
                }
            } else {
                toneGenerator = ToneGenerator(AudioManager.STREAM_MUSIC, 100)
                toneGenerator?.startTone(ToneGenerator.TONE_CDMA_CALL_SIGNAL_ISDN_NORMAL, -1)
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun stopAudio() {
        try {
            toneGenerator?.stopTone()
            toneGenerator?.release()
            toneGenerator = null
        } catch (e: Exception) {}

        try {
            mediaPlayer?.stop()
            mediaPlayer?.release()
            mediaPlayer = null
        } catch (e: Exception) {}

        try {
            vibrator?.cancel()
            vibrator = null
        } catch (e: Exception) {}
    }

    private fun applySpeakerphone(audioManager: AudioManager, isSpeaker: Boolean) {
        try {
            audioManager.mode = AudioManager.MODE_IN_COMMUNICATION
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                if (isSpeaker) {
                    val speakerDevice = audioManager.availableCommunicationDevices.firstOrNull {
                        it.type == AudioDeviceInfo.TYPE_BUILTIN_SPEAKER
                    }
                    if (speakerDevice != null) {
                        val success = audioManager.setCommunicationDevice(speakerDevice)
                        Log.i("FixNowAudio", "setCommunicationDevice SPEAKER: $success")
                    }
                    @Suppress("DEPRECATION")
                    audioManager.isSpeakerphoneOn = true
                } else {
                    val earpieceDevice = audioManager.availableCommunicationDevices.firstOrNull {
                        it.type == AudioDeviceInfo.TYPE_BUILTIN_EARPIECE
                    }
                    if (earpieceDevice != null) {
                        val success = audioManager.setCommunicationDevice(earpieceDevice)
                        Log.i("FixNowAudio", "setCommunicationDevice EARPIECE: $success")
                    } else {
                        audioManager.clearCommunicationDevice()
                    }
                    @Suppress("DEPRECATION")
                    audioManager.isSpeakerphoneOn = false
                }
            } else {
                @Suppress("DEPRECATION")
                audioManager.isSpeakerphoneOn = isSpeaker
            }
        } catch (e: Exception) {
            Log.e("FixNowAudio", "Failed to apply speakerphone", e)
        }
    }

    private val audioPlaybackExecutor = java.util.concurrent.Executors.newSingleThreadExecutor()

    private fun startVoiceStream(isSpeaker: Boolean) {
        stopVoiceStream()
        try {
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            applySpeakerphone(audioManager, isSpeaker)

            // 1. AudioTrack for 16kHz Mono 16-bit PCM playback
            val minTrackBuf = AudioTrack.getMinBufferSize(
                SAMPLE_RATE,
                AudioFormat.CHANNEL_OUT_MONO,
                AudioFormat.ENCODING_PCM_16BIT
            )
            val trackBufSize = maxOf(minTrackBuf * 2, 6400)
            audioTrack = AudioTrack.Builder()
                .setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(if (isSpeaker) AudioAttributes.USAGE_MEDIA else AudioAttributes.USAGE_VOICE_COMMUNICATION)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                        .build()
                )
                .setAudioFormat(
                    AudioFormat.Builder()
                        .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                        .setSampleRate(SAMPLE_RATE)
                        .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                        .build()
                )
                .setBufferSizeInBytes(trackBufSize)
                .setTransferMode(AudioTrack.MODE_STREAM)
                .build()

            audioTrack?.setVolume(1.0f)
            audioTrack?.play()
            try {
                val maxCallVol = audioManager.getStreamMaxVolume(AudioManager.STREAM_VOICE_CALL)
                audioManager.setStreamVolume(AudioManager.STREAM_VOICE_CALL, maxCallVol, 0)
                val maxMusicVol = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
                audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, maxMusicVol, 0)
            } catch (e: Exception) {}

            val permissionCheck = androidx.core.content.ContextCompat.checkSelfPermission(
                this,
                android.Manifest.permission.RECORD_AUDIO
            )
            if (permissionCheck != android.content.pm.PackageManager.PERMISSION_GRANTED) {
                Log.w("FixNowAudio", "RECORD_AUDIO permission not granted, requesting...")
                androidx.core.app.ActivityCompat.requestPermissions(
                    this,
                    arrayOf(android.Manifest.permission.RECORD_AUDIO),
                    101
                )
            }

            // 2. AudioRecord (prefer VOICE_COMMUNICATION for echo cancellation, fallback to MIC)
            val minRecordBuf = AudioRecord.getMinBufferSize(
                SAMPLE_RATE,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT
            )
            val recordBufSize = maxOf(minRecordBuf * 2, 6400)

            var record: AudioRecord? = null
            try {
                record = AudioRecord(
                    MediaRecorder.AudioSource.VOICE_COMMUNICATION,
                    SAMPLE_RATE,
                    AudioFormat.CHANNEL_IN_MONO,
                    AudioFormat.ENCODING_PCM_16BIT,
                    recordBufSize
                )
            } catch (e: Exception) {
                Log.w("FixNowAudio", "VOICE_COMMUNICATION source failed, falling back to MIC", e)
            }

            if (record == null || record.state != AudioRecord.STATE_INITIALIZED) {
                record?.release()
                try {
                    record = AudioRecord(
                        MediaRecorder.AudioSource.MIC,
                        SAMPLE_RATE,
                        AudioFormat.CHANNEL_IN_MONO,
                        AudioFormat.ENCODING_PCM_16BIT,
                        recordBufSize
                    )
                } catch (e: Exception) {
                    Log.e("FixNowAudio", "AudioRecord MIC creation failed", e)
                }
            }

            audioRecord = record
            audioRecord?.startRecording()
            isVoiceStreaming = true
            Log.i("FixNowAudio", "AudioRecord initialized, state=${audioRecord?.state}, recordingState=${audioRecord?.recordingState}")

            // Read 50ms chunks (800 samples = 1600 bytes)
            voiceRecordingThread = Thread({
                val chunk = ByteArray(1600)
                var frameCount = 0
                Log.i("FixNowAudio", "Voice recording loop started")
                while (isVoiceStreaming) {
                    val read = audioRecord?.read(chunk, 0, chunk.size) ?: -1
                    if (read > 0 && !isVoiceMuted) {
                        frameCount++
                        if (frameCount % 40 == 0) {
                            Log.d("FixNowAudio", "Recorded $frameCount voice frames (last frame: $read bytes)")
                        }
                        val payload = chunk.copyOf(read)
                        runOnUiThread {
                            if (isVoiceStreaming) {
                                voiceChannel?.invokeMethod("onVoiceChunk", payload)
                            }
                        }
                    } else if (read < 0) {
                        Log.w("FixNowAudio", "AudioRecord.read error: $read")
                        Thread.sleep(50)
                    }
                }
            }, "FixNowVoiceRecording").apply {
                priority = Thread.MAX_PRIORITY
                start()
            }
            // Proximity sensor auto-switch (Loudspeaker when held, Earpiece when near ear)
            try {
                sensorManager = getSystemService(Context.SENSOR_SERVICE) as? SensorManager
                proximitySensor = sensorManager?.getDefaultSensor(Sensor.TYPE_PROXIMITY)
                if (proximitySensor != null) {
                    proximityListener = object : SensorEventListener {
                        override fun onSensorChanged(event: SensorEvent?) {
                            val distance = event?.values?.getOrNull(0) ?: return
                            val maxRange = proximitySensor?.maximumRange ?: 5f
                            val isNear = distance < maxRange && distance < 4f
                            Log.i("FixNowAudio", "Proximity sensor: distance=$distance, isNear=$isNear")
                            val currentAudioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                            applySpeakerphone(currentAudioManager, !isNear)
                        }
                        override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
                    }
                    sensorManager?.registerListener(
                        proximityListener,
                        proximitySensor,
                        SensorManager.SENSOR_DELAY_NORMAL
                    )
                }
            } catch (e: Exception) {
                Log.w("FixNowAudio", "Proximity sensor setup skipped", e)
            }
        } catch (e: Exception) {
            Log.e("FixNowAudio", "Failed startVoiceStream", e)
        }
    }

    private var playedFrameCount = 0
    private fun playVoiceChunk(data: ByteArray) {
        audioPlaybackExecutor.execute {
            try {
                audioTrack?.let { track ->
                    if (track.playState != AudioTrack.PLAYSTATE_PLAYING) {
                        track.play()
                    }
                    val written = track.write(data, 0, data.size, AudioTrack.WRITE_BLOCKING)
                    playedFrameCount++
                    if (playedFrameCount % 40 == 0) {
                        Log.d("FixNowAudio", "Played $playedFrameCount voice chunks (last write: $written bytes)")
                    }
                }
            } catch (e: Exception) {
                Log.e("FixNowAudio", "Failed playVoiceChunk in executor", e)
            }
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 101 && grantResults.isNotEmpty() && grantResults[0] == android.content.pm.PackageManager.PERMISSION_GRANTED) {
            Log.i("FixNowAudio", "RECORD_AUDIO permission granted by user")
            if (isVoiceStreaming && audioRecord?.recordingState != AudioRecord.RECORDSTATE_RECORDING) {
                startVoiceStream(true)
            }
        }
    }

    private fun stopVoiceStream() {
        isVoiceStreaming = false
        try {
            if (proximityListener != null) {
                sensorManager?.unregisterListener(proximityListener)
                proximityListener = null
            }
        } catch (e: Exception) {}

        try {
            voiceRecordingThread?.interrupt()
            voiceRecordingThread = null
        } catch (e: Exception) {}

        try {
            audioRecord?.stop()
            audioRecord?.release()
            audioRecord = null
        } catch (e: Exception) {}

        try {
            audioTrack?.pause()
            audioTrack?.flush()
            audioTrack?.stop()
            audioTrack?.release()
            audioTrack = null
        } catch (e: Exception) {}

        try {
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            audioManager.mode = AudioManager.MODE_NORMAL
        } catch (e: Exception) {}
    }

    override fun onDestroy() {
        stopAudio()
        stopVoiceStream()
        super.onDestroy()
    }
}


