import 'dart:async';
import 'package:flutter/foundation.dart'; // For debugPrint
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse;
import 'package:html/dom.dart' as dom;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class ContentFetcherService {
  final YoutubeExplode _yt = YoutubeExplode();

  // --- URL Validation Helpers ---

  bool isValidUrl(String url) {
    final uri = Uri.tryParse(url);
    return uri != null && uri.hasScheme && uri.hasAuthority && (uri.scheme == 'http' || uri.scheme == 'https');
  }

  bool isYouTubeUrl(String url) {
    final uri = Uri.tryParse(url);
    // Simplified check: Ensure URI parsed and has authority
    if (uri == null || !uri.hasAuthority) return false;

    // Now we know uri and uri.host are likely not null (due to hasAuthority)
    return (uri.host.endsWith('youtube.com') || uri.host.endsWith('youtu.be')) &&
           (uri.queryParameters.containsKey('v') || (uri.host.endsWith('youtu.be') && uri.pathSegments.isNotEmpty));
  }

  // --- Fetching Logic ---

  Future<String> fetchAndParseUrl(String urlString) async {
    // (Same logic as the previous global _fetchAndParseUrl function)
     try {
      final url = Uri.parse(urlString);
      final response = await http.get(url).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        dom.Document document = parse(response.body);
        document.querySelectorAll('script, style').forEach((element) => element.remove());
        String parsedText = document.body?.text ?? '';
        parsedText = parsedText.replaceAll(RegExp(r'\s+'), ' ').trim();

        if (parsedText.isEmpty) {
          throw Exception('Could not extract meaningful text content from the URL.');
        }
        return parsedText;
      } else {
        throw Exception('Failed to fetch URL. Status code: ${response.statusCode}');
      }
    } on TimeoutException catch (_) {
      throw Exception('The request to fetch the URL timed out.');
    } catch (e) {
      throw Exception('Error fetching or parsing URL: ${e.toString()}');
    }
  }

  Future<String> fetchYouTubeTranscript(String urlString) async {
    // (Same logic as the previous global _fetchYouTubeTranscript function, but uses _yt)
    try {
      var videoId = VideoId.parseVideoId(urlString);
      if (videoId == null) {
        throw Exception('Could not parse YouTube video ID from URL.');
      }

      var manifest = await _yt.videos.closedCaptions.getManifest(videoId);

      if (manifest.tracks.isEmpty) {
        throw Exception('No closed captions found for this video.');
      }

      ClosedCaptionTrackInfo trackInfo = manifest.tracks.firstWhere(
          (t) => t.language.code == 'en',
          orElse: () => manifest.tracks.first);

      debugPrint('Fetching captions in language: ${trackInfo.language.name}');
      var track = await _yt.videos.closedCaptions.get(trackInfo);

      String transcript = track.captions.map((caption) => caption.text).join(' ');

      if (transcript.trim().isEmpty) {
         throw Exception('Fetched captions appear to be empty.');
      }

      return transcript.replaceAll(RegExp(r'\s+'), ' ').trim();

    } on ArgumentError catch (e) {
      throw Exception('Invalid YouTube URL format: ${e.message}');
    } catch (e) {
      throw Exception('Error fetching YouTube transcript: ${e.toString()}');
    }
  }

  // --- Cleanup ---

  void dispose() {
    _yt.close(); // Close the YoutubeExplode client
  }
} 