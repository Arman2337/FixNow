import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Native audio tone and VoIP voice streaming service.
class CallAudioService {
  CallAudioService._();

  static const MethodChannel _toneChannel = MethodChannel(
    'com.fixnow.mobile/audio_tone',
  );
  static const MethodChannel _voiceChannel = MethodChannel(
    'com.fixnow.mobile/voice_stream',
  );

  static void Function(Uint8List)? _onVoiceChunkCallback;
  static bool _handlerInstalled = false;

  static void _ensureHandlerInstalled() {
    if (_handlerInstalled) return;
    _handlerInstalled = true;
    _voiceChannel.setMethodCallHandler((call) async {
      if (call.method == 'onVoiceChunk') {
        final data = call.arguments;
        if (data is Uint8List) {
          _onVoiceChunkCallback?.call(data);
        } else if (data is List) {
          _onVoiceChunkCallback?.call(Uint8List.fromList(data.cast<int>()));
        }
      }
    });
  }

  /// Plays standard telecom supervisory ringback tone (audible ringing in caller's ear).
  static Future<void> playRingback() async {
    try {
      await _toneChannel.invokeMethod('playRingback');
    } catch (e) {
      debugPrint('[CallAudioService] Failed to play ringback: $e');
    }
  }

  /// Plays system incoming call ringtone with looping and device vibration.
  static Future<void> playIncomingRingtone() async {
    try {
      await _toneChannel.invokeMethod('playIncomingRingtone');
    } catch (e) {
      debugPrint('[CallAudioService] Failed to play incoming ringtone: $e');
    }
  }

  /// Stops all active ringback tones, incoming ringtones, and vibrations.
  static Future<void> stop() async {
    try {
      await _toneChannel.invokeMethod('stopAudio');
    } catch (e) {
      debugPrint('[CallAudioService] Failed to stop audio: $e');
    }
  }

  /// Starts native VoIP AudioRecord and AudioTrack for bi-directional conversation.
  static Future<void> startVoiceStream({
    bool isSpeaker = true,
    required void Function(Uint8List chunk) onVoiceChunk,
  }) async {
    _ensureHandlerInstalled();
    _onVoiceChunkCallback = onVoiceChunk;
    try {
      await _voiceChannel.invokeMethod('startVoiceStream', {
        'isSpeaker': isSpeaker,
      });
    } catch (e) {
      debugPrint('[CallAudioService] Failed to start voice stream: $e');
    }
  }

  /// Writes remote PCM chunk directly to native AudioTrack speaker.
  static Future<void> playVoiceChunk(Uint8List chunk) async {
    try {
      await _voiceChannel.invokeMethod('playVoiceChunk', {'chunk': chunk});
    } catch (e) {
      debugPrint('[CallAudioService] Failed to play voice chunk: $e');
    }
  }

  /// Mutes or unmutes local microphone.
  static Future<void> setMute(bool isMuted) async {
    try {
      await _voiceChannel.invokeMethod('setVoiceMute', {'isMuted': isMuted});
    } catch (e) {
      debugPrint('[CallAudioService] Failed to set voice mute: $e');
    }
  }

  /// Toggles speakerphone on/off.
  static Future<void> setSpeaker(bool isSpeaker) async {
    try {
      await _voiceChannel.invokeMethod('setSpeakerphone', {
        'isSpeaker': isSpeaker,
      });
    } catch (e) {
      debugPrint('[CallAudioService] Failed to set speakerphone: $e');
    }
  }

  /// Stops native AudioRecord and AudioTrack voice session.
  static Future<void> stopVoiceStream() async {
    _onVoiceChunkCallback = null;
    try {
      await _voiceChannel.invokeMethod('stopVoiceStream');
    } catch (e) {
      debugPrint('[CallAudioService] Failed to stop voice stream: $e');
    }
  }
}
