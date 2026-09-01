
class Exercise {
  String id;
  String name;
  String muscle;
  int sets;
  int reps;
  List<double> weights;
  List<bool> done;

  Exercise({
    required this.id,
    required this.name,
    required this.muscle,
    required this.sets,
    required this.reps,
    List<double>? weights,
    List<bool>? done,
  })  : weights = _fitDoubles(weights ?? const [], sets),
        done = _fitBools(done ?? const [], sets);

  static List<double> _fitDoubles(List<double> values, int length) {
    return List<double>.generate(
      length,
      (i) => i < values.length ? values[i] : 0,
    );
  }

  static List<bool> _fitBools(List<bool> values, int length) {
    return List<bool>.generate(
      length,
      (i) => i < values.length ? values[i] : false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'muscle': muscle,
        'sets': sets,
        'reps': reps,
        'weights': weights,
        'done': done,
      };

  factory Exercise.fromJson(Map<String, dynamic> json) {
    final rawWeights = (json['weights'] as List?) ?? const [];
    final rawDone = (json['done'] as List?) ?? const [];
    return Exercise(
      id: json['id'] as String,
      name: json['name'] as String,
      muscle: (json['muscle'] as String?) ?? '',
      sets: (json['sets'] as num?)?.toInt() ?? 3,
      reps: (json['reps'] as num?)?.toInt() ?? 10,
      weights: rawWeights.map((e) => (e as num).toDouble()).toList(),
      done: rawDone.map((e) => e == true).toList(),
    );
  }
}

class Workout {
  String id;
  String name;
  String date;
  List<Exercise> exercises;

  Workout({
    required this.id,
    required this.name,
    required this.date,
    required this.exercises,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'date': date,
        'exercises': exercises.map((e) => e.toJson()).toList(),
      };

  factory Workout.fromJson(Map<String, dynamic> json) {
    final rawExercises = (json['exercises'] as List?) ?? const [];
    return Workout(
      id: json['id'] as String,
      name: json['name'] as String,
      date: (json['date'] as String?) ?? '',
      exercises: rawExercises
          .map((e) => Exercise.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }
}

class Meal {
  String id;
  String date;
  String type;
  String food;
  double calories;
  double protein;
  double carbs;
  double fat;
  String source;

  Meal({
    required this.id,
    required this.date,
    required this.type,
    required this.food,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.source = 'manual',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date,
        'type': type,
        'food': food,
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'source': source,
      };

  factory Meal.fromJson(Map<String, dynamic> json) => Meal(
        id: json['id'] as String,
        date: json['date'] as String,
        type: (json['type'] as String?) ?? 'Refeição',
        food: json['food'] as String,
        calories: (json['calories'] as num).toDouble(),
        protein: (json['protein'] as num).toDouble(),
        carbs: (json['carbs'] as num).toDouble(),
        fat: (json['fat'] as num).toDouble(),
        source: (json['source'] as String?) ?? 'manual',
      );
}

class MoneyTransaction {
  String id;
  String date;
  String description;
  String category;
  double amount;
  bool income;

  MoneyTransaction({
    required this.id,
    required this.date,
    required this.description,
    required this.category,
    required this.amount,
    required this.income,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date,
        'description': description,
        'category': category,
        'amount': amount,
        'income': income,
      };

  factory MoneyTransaction.fromJson(Map<String, dynamic> json) =>
      MoneyTransaction(
        id: json['id'] as String,
        date: json['date'] as String,
        description: json['description'] as String,
        category: (json['category'] as String?) ?? 'Outros',
        amount: (json['amount'] as num).toDouble(),
        income: json['income'] == true,
      );
}

class AgendaEvent {
  String id;
  String date;
  String title;
  String description;
  String start;
  String end;

  AgendaEvent({
    required this.id,
    required this.date,
    required this.title,
    required this.description,
    required this.start,
    required this.end,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date,
        'title': title,
        'description': description,
        'start': start,
        'end': end,
      };

  factory AgendaEvent.fromJson(Map<String, dynamic> json) => AgendaEvent(
        id: json['id'] as String,
        date: json['date'] as String,
        title: json['title'] as String,
        description: (json['description'] as String?) ?? '',
        start: (json['start'] as String?) ?? '08:00',
        end: (json['end'] as String?) ?? '09:00',
      );
}
