import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:cloud_functions/cloud_functions.dart';

class CloudflareR2Service {
  final String accountId = dotenv.env['CLOUDFLARE_ACCOUNT_ID'] ?? '';
  final String bucketName = dotenv.env['CLOUDFLARE_BUCKET_NAME'] ?? '';
  final String customDomain = dotenv.env['DOMAIN'] ?? '';
  final FirebaseFunctions functions = FirebaseFunctions.instance;

  Future<String> uploadImage(File imageFile, String fileName) async {
    try {
      final result = await functions.httpsCallable('getR2UploadUrl').call({'fileName': fileName});
      final uploadUrl = result.data['url'];
      final headers = Map<String, String>.from(result.data['headers']);
      final request = http.Request('PUT', Uri.parse(uploadUrl));
      request.headers.addAll(headers);
      request.bodyBytes = await imageFile.readAsBytes();
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        print('Image uploaded successfully');
        final publicUrl = _getPublicUrl(fileName);
        return publicUrl;
      } else {
        throw Exception('Failed to upload image. Status code: ${response.statusCode}, Body: ${response.body}');
      }
    } catch (e) {
      print('Error uploading image: $e');
      throw Exception('Failed to upload image: $e');
    }
  }

  Future<void> deleteImage(String fileName) async {
    try {
      final result = await functions.httpsCallable('deleteR2Object').call({'fileName': fileName});
      if (result.data['success']) {
        print('Image deleted successfully');
      } else {
        throw Exception('Failed to delete image: ${result.data['error']}');
      }
    } catch (e) {
      print('Error deleting image: $e');
      throw Exception('Failed to delete image: $e');
    }
  }

  String _getPublicUrl(String fileName) {
    return '$customDomain/$fileName';
  }
}
