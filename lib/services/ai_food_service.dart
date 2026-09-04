import 'dart:convert';
import 'package:http/http.dart' as http;

class FoodItem {
  final String name;
  final double grams;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  FoodItem({required this.name, required this.grams, required this.calories, required this.protein, required this.carbs, required this.fat});
}

class FoodResult {
  final List<FoodItem> items;
  final String note;
  FoodResult({required this.items, this.note = 'Estimativa nutricional. Confira as porções.'});
  double get calories => items.fold(0, (s, i) => s + i.calories);
  double get protein => items.fold(0, (s, i) => s + i.protein);
  double get carbs => items.fold(0, (s, i) => s + i.carbs);
  double get fat => items.fold(0, (s, i) => s + i.fat);
}

class AiFoodService {
  final String? endpoint;
  final String? apiKey;
  AiFoodService({this.endpoint, this.apiKey});

  Future<FoodResult> estimateText(String text) async {
    if (endpoint == null || endpoint!.isEmpty) return _localEstimate(text);
    final r = await http.post(
      Uri.parse(endpoint!),
      headers: {'Content-Type': 'application/json', if (apiKey?.isNotEmpty == true) 'Authorization': 'Bearer $apiKey'},
      body: jsonEncode({'text': text}),
    );
    if (r.statusCode < 200 || r.statusCode >= 300) throw Exception('Falha na análise nutricional.');
    return _fromJson(Map<String, dynamic>.from(jsonDecode(r.body) as Map));
  }

  Future<FoodResult> estimateImage(String path) async {
    if (endpoint == null || endpoint!.isEmpty) {
      return FoodResult(items: [FoodItem(name: 'Foto capturada', grams: 0, calories: 0, protein: 0, carbs: 0, fat: 0)], note: 'A foto foi capturada, mas o app ainda não tem um backend de visão/IA conectado. Nenhum valor foi inventado.');
    }
    final request = http.MultipartRequest('POST', Uri.parse(endpoint!));
    if (apiKey?.isNotEmpty == true) request.headers['Authorization'] = 'Bearer $apiKey';
    request.files.add(await http.MultipartFile.fromPath('image', path));
    final r = await request.send();
    final body = await r.stream.bytesToString();
    if (r.statusCode < 200 || r.statusCode >= 300) throw Exception('Falha na análise da foto.');
    return _fromJson(Map<String, dynamic>.from(jsonDecode(body) as Map));
  }

  FoodResult _fromJson(Map<String, dynamic> json) {
    final raw = (json['items'] as List?) ?? const [];
    return FoodResult(
      items: raw.map((x) {
        final i = Map<String, dynamic>.from(x as Map);
        return FoodItem(
          name: (i['name'] ?? 'Alimento').toString(),
          grams: (i['grams'] as num?)?.toDouble() ?? 0,
          calories: (i['calories'] as num?)?.toDouble() ?? 0,
          protein: (i['protein'] as num?)?.toDouble() ?? 0,
          carbs: (i['carbs'] as num?)?.toDouble() ?? 0,
          fat: (i['fat'] as num?)?.toDouble() ?? 0,
        );
      }).toList(),
      note: (json['note'] as String?) ?? 'Estimativa nutricional.',
    );
  }

  FoodResult _localEstimate(String text) {
    final input = text.toLowerCase().replaceAll(',', '.');
    final items = <FoodItem>[];
    final specs = <String, List<double>>{
      'arroz': [130, 2.7, 28, 0.3],
      'feijão': [76, 4.8, 13.6, 0.5],
      'feijao': [76, 4.8, 13.6, 0.5],
      'frango': [165, 31, 0, 3.6],
      'ovo': [143, 13, 1.1, 9.5],
      'carne': [217, 26, 0, 11],
      'macarrão': [157, 5.8, 30.5, 0.9],
      'macarrao': [157, 5.8, 30.5, 0.9],
      'batata': [77, 2, 17.5, 0.1],
      'leite': [61, 3.2, 4.8, 3.3],
    };

    double amountFor(String food, double fallback) {
      final unit = r'(kg|g|gramas?|ml|l)';
      final number = r'(\d+(?:\.\d+)?)';
      final patterns = <RegExp>[
        RegExp('$number\\s*$unit\\s*(?:de\\s*)?${RegExp.escape(food)}'),
        RegExp('${RegExp.escape(food)}\\s*(?:de\\s*)?$number\\s*$unit'),
      ];
      for (final pattern in patterns) {
        final match = pattern.firstMatch(input);
        if (match == null) continue;
        final rawNumber = match.group(1);
        final rawUnit = match.group(2)?.toLowerCase();
        final value = double.tryParse(rawNumber ?? '') ?? fallback;
        if (rawUnit == 'kg' || rawUnit == 'l') return value * 1000;
        return value;
      }
      return fallback;
    }

    void addFood(String key, String label, double fallback) {
      final base = specs[key]!;
      final grams = amountFor(key, fallback);
      final factor = grams / 100;
      items.add(FoodItem(
        name: '$label (${grams.toStringAsFixed(0)}g)',
        grams: grams,
        calories: base[0] * factor,
        protein: base[1] * factor,
        carbs: base[2] * factor,
        fat: base[3] * factor,
      ));
    }

    if (input.contains('arroz')) addFood('arroz', 'Arroz', 100);
    if (input.contains('feijão') || input.contains('feijao')) addFood(input.contains('feijão') ? 'feijão' : 'feijao', 'Feijão', 100);
    if (input.contains('frango')) addFood('frango', 'Frango', 100);
    if (input.contains('ovo')) addFood('ovo', 'Ovo', 50);
    if (input.contains('carne')) addFood('carne', 'Carne bovina', 100);
    if (input.contains('macarrão') || input.contains('macarrao')) addFood(input.contains('macarrão') ? 'macarrão' : 'macarrao', 'Macarrão', 100);
    if (input.contains('batata')) addFood('batata', 'Batata', 100);
    if (input.contains('leite')) addFood('leite', 'Leite', 250);

    if (items.isEmpty) items.add(FoodItem(name: 'Não identificado', grams: 0, calories: 0, protein: 0, carbs: 0, fat: 0));
    return FoodResult(items: items, note: 'As quantidades informadas em g/kg são convertidas e os valores são escalados proporcionalmente a 100g. Para líquidos, ml/l são tratados como volume aproximado em gramas. Ex.: 200g de carne gera o dobro dos valores de 100g.');
  }
}
