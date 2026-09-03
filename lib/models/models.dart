class Exercise {
  String id;
  String name;
  String muscle;
  int sets;
  int reps;
  List<double> weights;
  List<bool> done;

  Exercise({required this.id, required this.name, required this.muscle, required this.sets, required this.reps, List<double>? weights, List<bool>? done})
      : weights = _fitDoubles(weights ?? const [], sets), done = _fitBools(done ?? const [], sets);

  static List<double> _fitDoubles(List<double> v, int n) => List<double>.generate(n, (i) => i < v.length ? v[i] : 0);
  static List<bool> _fitBools(List<bool> v, int n) => List<bool>.generate(n, (i) => i < v.length ? v[i] : false);

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'muscle': muscle, 'sets': sets, 'reps': reps, 'weights': weights, 'done': done};
  factory Exercise.fromJson(Map<String, dynamic> j) => Exercise(
    id: j['id'] as String, name: j['name'] as String, muscle: (j['muscle'] as String?) ?? '',
    sets: (j['sets'] as num?)?.toInt() ?? 3, reps: (j['reps'] as num?)?.toInt() ?? 10,
    weights: ((j['weights'] as List?) ?? const []).map((e) => (e as num).toDouble()).toList(),
    done: ((j['done'] as List?) ?? const []).map((e) => e == true).toList(),
  );
}

class Workout {
  String id;
  String name;
  String date;
  int weekday;
  List<Exercise> exercises;
  Workout({required this.id, required this.name, required this.date, this.weekday = 1, required this.exercises});
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'date': date, 'weekday': weekday, 'exercises': exercises.map((e) => e.toJson()).toList()};
  factory Workout.fromJson(Map<String, dynamic> j) {
    final date = (j['date'] as String?) ?? '';
    int day = (j['weekday'] as num?)?.toInt() ?? 0;
    if (day < 1 || day > 7) { try { day = DateTime.parse(date).weekday; } catch (_) { day = 1; } }
    return Workout(id: j['id'] as String, name: j['name'] as String, date: date, weekday: day,
      exercises: ((j['exercises'] as List?) ?? const []).map((e) => Exercise.fromJson(Map<String, dynamic>.from(e as Map))).toList());
  }
}

class Meal {
  String id; String date; String type; String food; double calories; double protein; double carbs; double fat; String source;
  Meal({required this.id, required this.date, required this.type, required this.food, required this.calories, required this.protein, required this.carbs, required this.fat, this.source = 'manual'});
  Map<String, dynamic> toJson() => {'id': id, 'date': date, 'type': type, 'food': food, 'calories': calories, 'protein': protein, 'carbs': carbs, 'fat': fat, 'source': source};
  factory Meal.fromJson(Map<String, dynamic> j) => Meal(id: j['id'] as String, date: j['date'] as String, type: (j['type'] as String?) ?? 'Refeição', food: j['food'] as String, calories: (j['calories'] as num).toDouble(), protein: (j['protein'] as num).toDouble(), carbs: (j['carbs'] as num).toDouble(), fat: (j['fat'] as num).toDouble(), source: (j['source'] as String?) ?? 'manual');
}

class MoneyTransaction {
  String id; String date; String description; String category; double amount; bool income;
  MoneyTransaction({required this.id, required this.date, required this.description, required this.category, required this.amount, required this.income});
  Map<String, dynamic> toJson() => {'id': id, 'date': date, 'description': description, 'category': category, 'amount': amount, 'income': income};
  factory MoneyTransaction.fromJson(Map<String, dynamic> j) => MoneyTransaction(id: j['id'] as String, date: j['date'] as String, description: j['description'] as String, category: (j['category'] as String?) ?? 'Outros', amount: (j['amount'] as num).toDouble(), income: j['income'] == true);
}

class AgendaEvent {
  String id; String date; String title; String description; String start; String end;
  AgendaEvent({required this.id, required this.date, required this.title, required this.description, required this.start, required this.end});
  Map<String, dynamic> toJson() => {'id': id, 'date': date, 'title': title, 'description': description, 'start': start, 'end': end};
  factory AgendaEvent.fromJson(Map<String, dynamic> j) => AgendaEvent(id: j['id'] as String, date: j['date'] as String, title: j['title'] as String, description: (j['description'] as String?) ?? '', start: (j['start'] as String?) ?? '08:00', end: (j['end'] as String?) ?? '09:00');
}
