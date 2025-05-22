import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:logging/logging.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Enum to represent TTS playback state
enum OpenAiTtsPlayerState { stopped, loading, playing, paused, completed, error }

// Class to hold the current TTS state and the ID of the message being spoken/loaded
class OpenAiTtsStateData {
  final OpenAiTtsPlayerState playerState;
  final String? currentMessageId;
  final String? errorMessage;

  OpenAiTtsStateData({
    this.playerState = OpenAiTtsPlayerState.stopped,
    this.currentMessageId,
    this.errorMessage,
  });

  OpenAiTtsStateData copyWith({
    OpenAiTtsPlayerState? playerState,
    String? currentMessageId,
    bool clearMessageId = false,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return OpenAiTtsStateData(
      playerState: playerState ?? this.playerState,
      currentMessageId: clearMessageId ? null : currentMessageId ?? this.currentMessageId,
      errorMessage: clearErrorMessage ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class OpenAiTtsService extends StateNotifier<OpenAiTtsStateData> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final _log = Logger('OpenAiTtsService');
  final http.Client _httpClient = http.Client();
  
  // Production Supabase Edge Function URL
  static const String _supabaseFunctionBaseUrl = 'https://dhztoureixsskctbpovk.supabase.co/functions/v1';
  static const String _ttsProxyFunctionName = 'openai-tts-proxy'; 
  static const String _ttsEndpointPath = ''; // Our function is directly at /openai-tts-proxy

  // Local testing URLs (commented out):
  // static const String _supabaseFunctionBaseUrl = 'http://YOUR_COMPUTER_IP_ADDRESS_HERE:54321/functions/v1'; // For Physical Device connected to same network
  // static const String _ttsProxyFunctionName = 'openai-tts-proxy'; 
  // static const String _ttsEndpointPath = '';

  OpenAiTtsService() : super(OpenAiTtsStateData()) {
    _initAudioPlayerListeners();
  }

  void _initAudioPlayerListeners() {
    _audioPlayer.playerStateStream.listen((playerState) {
      if (!mounted) return;
      _log.info("AudioPlayer state: ${playerState.processingState}, playing: ${playerState.playing}");
      switch (playerState.processingState) {
        case ProcessingState.idle:
          if (state.playerState != OpenAiTtsPlayerState.stopped && state.currentMessageId != null) {
             state = state.copyWith(playerState: OpenAiTtsPlayerState.stopped, clearMessageId: true, errorMessage: "Playback stopped unexpectedly.");
          } else {
            state = state.copyWith(playerState: OpenAiTtsPlayerState.stopped, clearMessageId: true, clearErrorMessage: true);
          }
          break;
        case ProcessingState.loading:
          state = state.copyWith(playerState: OpenAiTtsPlayerState.loading);
          break;
        case ProcessingState.buffering:
          state = state.copyWith(playerState: OpenAiTtsPlayerState.loading); 
          break;
        case ProcessingState.ready:
          if (playerState.playing) {
            state = state.copyWith(playerState: OpenAiTtsPlayerState.playing, clearErrorMessage: true);
          } else {
            if (state.playerState == OpenAiTtsPlayerState.playing || state.playerState == OpenAiTtsPlayerState.loading) {
                 state = state.copyWith(playerState: OpenAiTtsPlayerState.paused); 
            }
          }
          break;
        case ProcessingState.completed:
          state = state.copyWith(playerState: OpenAiTtsPlayerState.completed, clearMessageId: true);
          _audioPlayer.stop(); 
          break;
      }
    });
  }

  Future<void> speak(String text, String messageId, {String model = 'tts-1', String voice = 'alloy'}) async {
    final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];
    final currentUser = Supabase.instance.client.auth.currentUser;
    final session = Supabase.instance.client.auth.currentSession;

    if (supabaseAnonKey == null) {
      _log.severe('SUPABASE_ANON_KEY not found in .env file.');
      state = state.copyWith(playerState: OpenAiTtsPlayerState.error, errorMessage: 'Supabase key not configured.', currentMessageId: messageId);
      return;
    }

    if (currentUser == null || session == null) {
      _log.severe('User not authenticated. Cannot make TTS request.');
      state = state.copyWith(playerState: OpenAiTtsPlayerState.error, errorMessage: 'User not authenticated.', currentMessageId: messageId);
      return;
    }

    if (state.playerState == OpenAiTtsPlayerState.loading && state.currentMessageId == messageId) {
      _log.info('Already loading this message: $messageId');
      return; 
    }
    
    if (state.playerState == OpenAiTtsPlayerState.playing && state.currentMessageId == messageId) {
        await stop(); 
        return;
    }

    if (state.playerState == OpenAiTtsPlayerState.playing || state.playerState == OpenAiTtsPlayerState.loading) {
      await _audioPlayer.stop();
    }
    
    state = state.copyWith(playerState: OpenAiTtsPlayerState.loading, currentMessageId: messageId, clearErrorMessage: true);

    // Construct the full URL to your Supabase Edge Function for TTS
    final ttsFunctionUrl = Uri.parse('$_supabaseFunctionBaseUrl/$_ttsProxyFunctionName$_ttsEndpointPath');
    _log.info('Calling Supabase TTS proxy: $ttsFunctionUrl');

    try {
      final response = await _httpClient.post(
        ttsFunctionUrl,
        headers: {
          'apikey': supabaseAnonKey, // Supabase anon key
          'Authorization': 'Bearer ${session.accessToken}', // User's JWT
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': model,
          'input': text, // Corrected to 'input' to match OpenAI TTS API and our Edge Function
          'voice': voice,
          // 'response_format': 'mp3', // Handled by Edge function if needed
        }),
      ).timeout(const Duration(seconds: 30)); // Added timeout

      if (response.statusCode == 200) {
        final Uint8List audioBytes = response.bodyBytes;
        if (audioBytes.isEmpty) {
          _log.severe('Supabase TTS Proxy Error: Received empty audio data.');
          state = state.copyWith(playerState: OpenAiTtsPlayerState.error, errorMessage: 'Received empty audio.', clearMessageId: true);
          return;
        }
        final tempAudioSource = _MyCustomBytesAudioSource(audioBytes);
        await _audioPlayer.setAudioSource(tempAudioSource);
        await _audioPlayer.play();
      } else {
        _log.severe('Supabase TTS Proxy Error: ${response.statusCode} - ${response.body}');
        String errorBody = response.body;
        try {
            final decodedError = jsonDecode(errorBody) as Map<String, dynamic>;
            if (decodedError.containsKey('error')) { // Check if 'error' key exists
                var errorContent = decodedError['error'];
                if (errorContent is Map && errorContent.containsKey('message')) {
                     errorBody = errorContent['message'] ?? errorBody;
                } else if (errorContent is String) {
                    errorBody = errorContent;
                }
            }
        } catch (_) {}
        state = state.copyWith(playerState: OpenAiTtsPlayerState.error, errorMessage: 'Proxy Error: $errorBody', clearMessageId: true);
      }
    } on TimeoutException catch (_) {
        _log.severe('Supabase TTS Proxy request timed out.');
        state = state.copyWith(playerState: OpenAiTtsPlayerState.error, errorMessage: 'Request timed out.', clearMessageId: true);
    } catch (e, stackTrace) {
      _log.severe('Error calling Supabase TTS proxy or playing audio: $e', e, stackTrace);
      state = state.copyWith(playerState: OpenAiTtsPlayerState.error, errorMessage: 'Failed to get audio: $e', clearMessageId: true);
    }
  }

  Future<void> stop() async {
    _log.info("Stop called. Current state: ${state.playerState}, messageId: ${state.currentMessageId}");
    await _audioPlayer.stop(); 
  }

  Future<void> pause() async {
      if (_audioPlayer.playing) {
          await _audioPlayer.pause();
      }
  }

  Future<void> resume() async {
      if (!_audioPlayer.playing && state.playerState == OpenAiTtsPlayerState.paused) {
          await _audioPlayer.play();
      }
  }


  @override
  void dispose() {
    _log.info("Disposing OpenAiTtsService");
    _audioPlayer.dispose();
    _httpClient.close();
    super.dispose();
  }
}

// Custom AudioSource for playing bytes with just_audio
class _MyCustomBytesAudioSource extends StreamAudioSource {
  final Uint8List _buffer;

  _MyCustomBytesAudioSource(this._buffer) : super(tag: 'MyCustomBytesAudioSource');

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;
    end ??= _buffer.length;
    return StreamAudioResponse(
      sourceLength: _buffer.length,
      contentLength: end - start,
      offset: start,
      stream: Stream.value(_buffer.sublist(start, end)),
      contentType: 'audio/mpeg', 
    );
  }
}

// Riverpod provider for the OpenAiTtsService
final openAiTtsServiceProvider = StateNotifierProvider<OpenAiTtsService, OpenAiTtsStateData>((ref) {
  return OpenAiTtsService();
}); 