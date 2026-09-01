
import 'dart:convert';
import 'package:http/http.dart' as http;

class FoodItem {
  final String name;
  final double grams;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;

  FoodItem({
    required this.name,
    required this.grams,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });
}

class FoodResult {
  final List<FoodItem> items;
  final String note;

  FoodResult({
    required this.items,
    this.note = 'Estimativa nutricional. Confira as porções.',
  });

  double get calories => items.fold(0, (sum, item) => sum + item.calories);
  double get protein => items.fold(0, (sum, item) => sum + item.protein);
  double get carbs => items.fold(0, (sum, item) => sum + item.carbs);
  double get fat => items.fold(0, (sum, item) => sum + item.fat);
}

class AiFoodService {
  final String? endpoint;
  final String? apiKey;

  AiFoodService({this.endpoint, this.apiKey});

  Future<FoodResult> estimateText(String text) async {
    if (endpoint == null || endpoint!.isEmpty) {
      return _localEstimate(text);
    }

    final response = await http.post(
      Uri.parse(endpoint!),
      headers: {
        'Content-Type': 'application/json',
        if (apiKey != null && apiKey!.isNotEmpty)
          'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({'text': text}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Falha na análise nutricional.');
    }

    return _fromJson(
      Map<String, dynamic>.from(jsonDecode(response.body) as Map),
    );
  }

  Future<FoodResult> estimateImage(String path) async {
    if (endpoint == null || endpoint!.isEmpty) {
      return FoodResult(
        items: [
          FoodItem(
            name: 'Foto da refeição',
            grams: 0,
            calories: 0,
            protein: 0,
            carbs: 0,
            fat: 0,
          ),
        ],
        note:
            'Câmera funcionando. Para reconhecer alimentos de verdade, conecte um backend de visão/IA.',
      );
    }

    final request = http.MultipartRequest('POST', Uri.parse(endpoint!));
    if (apiKey != null && apiKey!.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $apiKey';
    }
    request.files.add(await http.MultipartFile.fromPath('image', path));

    final streamed = await request.send();
    final body = await streamed.stream.bytesToString();

    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      throw Exception('Falha na análise da foto.');
    }

    return _fromJson(
      Map<String, dynamic>.from(jsonDecode(body) as Map),
    );
  }

  FoodResult _fromJson(Map<String, dynamic> json) {
    final rawItems = (json['items'] as List?) ?? const [];
    return FoodResult(
      items: rawItems.map((raw) {
        final item = Map<String, dynamic>.from(raw as Map);
        return FoodItem(
          name: item['name'] as String,
          grams: (item['grams'] as num?)?.toDouble() ?? 0,
          calories: (item['calories'] as num?)?.toDouble() ?? 0,
          protein: (item['protein'] as num?)?.toDouble() ?? 0,
          carbs: (item['carbs'] as num?)?.toDouble() ?? 0,
          fat: (item['fat'] as num?)?.toDouble() ?? 0,
        );
      }).toList(),
      note: (json['note'] as String?) ?? 'Estimativa nutricional.',
    );
  }

  FoodResult _localEstimate(String text) {
    final input = text.toLowerCase();
    final items = <FoodItem>[];

    void add(
      String name,
      double grams,
      double calories,
      double protein,
      double carbs,
      double fat,
    ) {
      items.add(
        FoodItem(
          name: name,
          grams: grams,
          calories: calories,
          protein: protein,
          carbs: carbs,
          fat: fat,
        ),
      );
    }

    if (input.contains('arroz')) add('Arroz', 200, 260, 5, 56, 0.6);
    if (input.contains('feijão') || input.contains('feijao')) {
      add('Feijão', 100, 76, 4.8, 13.6, 0.5);
    }
    if (input.contains('frango')) add('Frango', 150, 248, 46, 0, 5);
    if (input.contains('ovo')) add('Ovos', 100, 143, 13, 1.1, 9.5);
    if (input.contains('carne')) add('Carne bovina', 150, 325, 39, 0, 17);
    if (input.contains('macarrão') || input.contains('macarrao')) {
      add('Macarrão', 200, 314, 11.6, 61, 1.8);
    }
    if (input.contains('batata')) add('Batata', 200, 154, 4, 35, 0.2);
    if (input.contains('leite')) add('Leite', 250, 153, 8, 12, 8);

    if (items.isEmpty) {
      add('Não identificado', 0, 0, 0, 0, 0);
    }

    return FoodResult(
      items: items,
      note:
          'Estimativa local demonstrativa. A quantidade informada é aproximada até conectar uma IA nutricional real.',
    );
  }
}
