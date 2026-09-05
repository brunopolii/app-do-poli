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
    final r = await http.post(Uri.parse(endpoint!), headers: {'Content-Type': 'application/json', if (apiKey?.isNotEmpty == true) 'Authorization': 'Bearer $apiKey'}, body: jsonEncode({'text': text}));
    if (r.statusCode < 200 || r.statusCode >= 300) throw Exception('Falha na análise nutricional.');
    return _fromJson(Map<String, dynamic>.from(jsonDecode(r.body) as Map));
  }

  Future<FoodResult> estimateImage(String path) async {
    if (endpoint == null || endpoint!.isEmpty) return FoodResult(items: [FoodItem(name: 'Foto capturada', grams: 0, calories: 0, protein: 0, carbs: 0, fat: 0)], note: 'A foto foi capturada, mas o app ainda não tem um backend de visão/IA conectado. Nenhum valor foi inventado.');
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
    return FoodResult(items: raw.map((x) {
      final i = Map<String, dynamic>.from(x as Map);
      return FoodItem(name: (i['name'] ?? 'Alimento').toString(), grams: (i['grams'] as num?)?.toDouble() ?? 0, calories: (i['calories'] as num?)?.toDouble() ?? 0, protein: (i['protein'] as num?)?.toDouble() ?? 0, carbs: (i['carbs'] as num?)?.toDouble() ?? 0, fat: (i['fat'] as num?)?.toDouble() ?? 0);
    }).toList(), note: (json['note'] as String?) ?? 'Estimativa nutricional.');
  }

  FoodResult _localEstimate(String text) {
    final input = text.toLowerCase().replaceAll(',', '.');
    final specs = <String, List<double>>{
      'arroz': [130, 2.7, 28, 0.3], 'feijão': [76, 4.8, 13.6, 0.5], 'feijao': [76, 4.8, 13.6, 0.5], 'frango': [165, 31, 0, 3.6],
      'ovo': [143, 13, 1.1, 9.5], 'carne': [217, 26, 0, 11], 'carne moída': [215, 26, 0, 12], 'carne moida': [215, 26, 0, 12],
      'macarrão': [157, 5.8, 30.5, 0.9], 'macarrao': [157, 5.8, 30.5, 0.9], 'batata': [77, 2, 17.5, 0.1], 'batata doce': [86, 1.6, 20.1, 0.1],
      'mandioca': [125, 0.6, 30, 0.3], 'tapioca': [240, 0.2, 59, 0.2], 'pão': [265, 9, 49, 3.2], 'pao': [265, 9, 49, 3.2],
      'queijo prato': [360, 22, 2, 29], 'queijo': [350, 22, 3, 28], 'presunto': [145, 16, 2, 8], 'hamburguer': [250, 15, 5, 18],
      'leite': [61, 3.2, 4.8, 3.3], 'iogurte': [63, 3.5, 5, 3], 'aveia': [394, 16.9, 66.3, 8.6], 'banana': [89, 1.1, 22.8, 0.3],
      'maçã': [52, 0.3, 13.8, 0.2], 'maca': [52, 0.3, 13.8, 0.2], 'laranja': [47, 0.9, 11.8, 0.1], 'mamão': [43, 0.5, 10.8, 0.3], 'mamao': [43, 0.5, 10.8, 0.3],
      'morango': [32, 0.7, 7.7, 0.3], 'abacate': [160, 2, 8.5, 14.7], 'tomate': [18, 0.9, 3.9, 0.2], 'alface': [15, 1.4, 2.9, 0.2],
      'cenoura': [41, 0.9, 9.6, 0.2], 'brócolis': [34, 2.8, 6.6, 0.4], 'brocolis': [34, 2.8, 6.6, 0.4], 'milho': [96, 3.4, 21, 1.5],
      'ervilha': [81, 5.4, 14.5, 0.4], 'lentilha': [116, 9, 20, 0.4], 'grão de bico': [164, 8.9, 27.4, 2.6], 'grao de bico': [164, 8.9, 27.4, 2.6],
      'atum': [132, 29, 0, 1], 'sardinha': [208, 25, 0, 11], 'salmão': [208, 20, 0, 13], 'salmao': [208, 20, 0, 13], 'peixe': [128, 26, 0, 2.7],
      'camarão': [99, 24, 0.2, 0.3], 'camarao': [99, 24, 0.2, 0.3], 'carne suína': [242, 27, 0, 14], 'carne suina': [242, 27, 0, 14],
      'azeite': [884, 0, 0, 100], 'manteiga': [717, 0.9, 0.1, 81], 'requeijão': [257, 9.6, 2.6, 23], 'requeijao': [257, 9.6, 2.6, 23],
      'chocolate': [535, 7.8, 59, 30], 'biscoito': [480, 6, 68, 20], 'pizza': [266, 11, 33, 10], 'lasanha': [135, 7, 13, 6],
      'açúcar': [387, 0, 100, 0], 'acucar': [387, 0, 100, 0], 'mel': [304, 0.3, 82.4, 0], 'suco': [45, 0.5, 10, 0.1], 'refrigerante': [42, 0, 10.6, 0],
    };
    final aliases = <String, List<String>>{
      'arroz': ['arroz'], 'feijão': ['feijão', 'feijao'], 'frango': ['frango'], 'ovo': ['ovo', 'ovos'], 'carne moída': ['carne moída', 'carne moida'], 'carne': ['carne bovina', 'carne'],
      'macarrão': ['macarrão', 'macarrao'], 'batata doce': ['batata doce', 'batata-doce'], 'batata': ['batata'], 'mandioca': ['mandioca', 'aipim', 'macaxeira'], 'tapioca': ['tapioca'],
      'pão': ['pão', 'pao'], 'queijo prato': ['queijo prato'], 'queijo': ['queijo'], 'presunto': ['presunto'], 'hamburguer': ['hambúrguer', 'hamburguer'], 'leite': ['leite'],
      'iogurte': ['iogurte'], 'aveia': ['aveia'], 'banana': ['banana'], 'maçã': ['maçã', 'maca'], 'laranja': ['laranja'], 'mamão': ['mamão', 'mamao'], 'morango': ['morango'], 'abacate': ['abacate'],
      'tomate': ['tomate'], 'alface': ['alface'], 'cenoura': ['cenoura'], 'brócolis': ['brócolis', 'brocolis'], 'milho': ['milho'], 'ervilha': ['ervilha'], 'lentilha': ['lentilha'],
      'grão de bico': ['grão de bico', 'grao de bico'], 'atum': ['atum'], 'sardinha': ['sardinha'], 'salmão': ['salmão', 'salmao'], 'peixe': ['peixe'], 'camarão': ['camarão', 'camarao'],
      'carne suína': ['carne suína', 'carne suina'], 'azeite': ['azeite'], 'manteiga': ['manteiga'], 'requeijão': ['requeijão', 'requeijao'], 'chocolate': ['chocolate'], 'biscoito': ['biscoito', 'bolacha'],
      'pizza': ['pizza'], 'lasanha': ['lasanha'], 'açúcar': ['açúcar', 'acucar'], 'mel': ['mel'], 'suco': ['suco'], 'refrigerante': ['refrigerante'],
    };
    final items = <FoodItem>[];
    final keys = aliases.keys.toList()..sort((a, b) => b.length.compareTo(a.length));
    for (final key in keys) {
      final words = aliases[key]!;
      if (!words.any(input.contains)) continue;
      final base = specs[key];
      if (base == null) continue;
      final defaultGrams = key == 'ovo' ? 50.0 : key == 'pão' ? 50.0 : key == 'queijo prato' ? 20.0 : key == 'leite' ? 250.0 : 100.0;
      double grams = defaultGrams;
      for (final word in words) {
        final e = RegExp.escape(word);
        final before = RegExp(r'(\d+(?:\.\d+)?)\s*(kg|g|gramas?|ml|l)\s*(?:de\s*)?' + e).firstMatch(input);
        final after = RegExp(e + r'\s*(?:de\s*)?(\d+(?:\.\d+)?)\s*(kg|g|gramas?|ml|l)').firstMatch(input);
        final countBefore = RegExp(r'(\d+(?:\.\d+)?)\s*(unidades?|un|x)\s*(?:de\s*)?' + e).firstMatch(input);
        final countAfter = RegExp(e + r'\s*(?:de\s*)?(\d+(?:\.\d+)?)\s*(unidades?|un|x)').firstMatch(input);
        if (before != null) { final n = double.tryParse(before.group(1)!) ?? defaultGrams; grams = (before.group(2) == 'kg' || before.group(2) == 'l') ? n * 1000 : n; break; }
        if (after != null) { final n = double.tryParse(after.group(1)!) ?? defaultGrams; grams = (after.group(2) == 'kg' || after.group(2) == 'l') ? n * 1000 : n; break; }
        if (countBefore != null) { grams = (double.tryParse(countBefore.group(1)!) ?? 1) * defaultGrams; break; }
        if (countAfter != null) { grams = (double.tryParse(countAfter.group(1)!) ?? 1) * defaultGrams; break; }
      }
      final factor = grams / 100;
      items.add(FoodItem(name: '${key[0].toUpperCase()}${key.substring(1)} (${grams.toStringAsFixed(0)}g)', grams: grams, calories: base[0] * factor, protein: base[1] * factor, carbs: base[2] * factor, fat: base[3] * factor));
    }
    if (items.isEmpty) items.add(FoodItem(name: 'Não identificado', grams: 0, calories: 0, protein: 0, carbs: 0, fat: 0));
    return FoodResult(items: items, note: 'Reconhece dezenas de alimentos comuns, aceita g/kg/ml/l e unidades e calcula a porção informada proporcionalmente. Os valores são estimativas e devem ser conferidos.');
  }
}
