import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class AIService {
  final String apiKey = dotenv.env['GEMINI_API_KEY'] ?? "";

  Future<List<Map<String, dynamic>>> getRecommendations(List<Map<String, dynamic>> places, String placeType) async {
    final model = GenerativeModel(model: 'gemini-1.5-flash-latest', apiKey: apiKey);
    final prompt = '''
    Based on the following list of ${placeType}s and their ratings, recommend the top results (max 5) to visit and explain why for each:
    ${places.map((place) => "${place['name']}: ${place['rating']} stars (${place['user_ratings_total']} reviews)").join('\n')}
    
    For each recommendation, provide a brief explanation of why this $placeType is a great choice, considering factors like rating, number of reviews, and any other relevant information.
    Format your response as follows:
    1. [Place Name]
    [Explanation]

    2. [Place Name]
    [Explanation]

    3. [Place Name]
    [Explanation]

    Do not include any other information in your response.
    ''';

    final content = [Content.text(prompt)];
    final response = await model.generateContent(content);

    if (response.text == null) {
      return [{'recommendation': 'Unable to generate recommendations at this time.', 'place': null}];
    }

    List<String> recommendations = response.text!.split('\n\n').where((rec) => rec.trim().isNotEmpty).toList();
    List<Map<String, dynamic>> result = [];

    for (var recommendation in recommendations) {
      String placeName = recommendation.split('\n').first.replaceAll(RegExp(r'^\d+\.\s+'), '').trim();
      Map<String, dynamic>? place = places.firstWhere((p) => p['name'] == placeName, orElse: () => {});
      
      result.add({
        'recommendation': recommendation,
        'place': place.isNotEmpty ? place : null,
      });
    }

    return result;
  }
}