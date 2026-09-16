class Exercise {
  String id;
  String name;
  String muscle;
  int sets;
  int reps;
  // Kept for workout execution/history compatibility. WorkoutPlan serialization excludes them.
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

  static List<double> _fitDoubles(List<double> v, int n) =>
      List<double>.generate(n, (i) => i < v.length ? v[i] : 0);
  static List<bool> _fitBools(List<bool> v, int n) =>
      List<bool>.generate(n, (i) => i < v.length ? v[i] : false);

  Exercise copy() => Exercise(
        id: id,
        name: name,
        muscle: muscle,
        sets: sets,
        reps: reps,
        weights: [...weights],
        done: [...done],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'muscle': muscle,
        'sets': sets,
        'reps': reps,
        'weights': weights,
        'done': done,
      };

  Map<String, dynamic> toPlanJson() => {
        'id': id,
        'name': name,
        'muscle': muscle,
        'sets': sets,
        'reps': reps,
      };

  factory Exercise.fromJson(Map<String, dynamic> j) => Exercise(
        id: (j['id'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        muscle: (j['muscle'] ?? '').toString(),
        sets: (j['sets'] as num?)?.toInt() ?? 3,
        reps: (j['reps'] as num?)?.toInt() ?? 10,
        weights: ((j['weights'] as List?) ?? const [])
            .map((e) => (e as num).toDouble())
            .toList(),
        done: ((j['done'] as List?) ?? const []).map((e) => e == true).toList(),
      );

  factory Exercise.fromPlanJson(Map<String, dynamic> j) => Exercise(
        id: (j['id'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        muscle: (j['muscle'] ?? '').toString(),
        sets: (j['sets'] as num?)?.toInt() ?? 3,
        reps: (j['reps'] as num?)?.toInt() ?? 10,
      );
}

class Workout {
  String id;
  String name;
  String date;
  int weekday;
  List<Exercise> exercises;
  Workout({
    required this.id,
    required this.name,
    required this.date,
    this.weekday = 1,
    required this.exercises,
  });
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'date': date,
        'weekday': weekday,
        'exercises': exercises.map((e) => e.toJson()).toList(),
      };
  factory Workout.fromJson(Map<String, dynamic> j) {
    final date = (j['date'] as String?) ?? '';
    int day = (j['weekday'] as num?)?.toInt() ?? 0;
    if (day < 1 || day > 7) {
      try {
        day = DateTime.parse(date).weekday;
      } catch (_) {
        day = 1;
      }
    }
    return Workout(
      id: (j['id'] ?? '').toString(),
      name: (j['name'] ?? 'Treino').toString(),
      date: date,
      weekday: day,
      exercises: ((j['exercises'] as List?) ?? const [])
          .map((e) => Exercise.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }
}

class WorkoutPlan {
  String id;
  String name;
  List<int> weekdays;
  Map<String, List<Exercise>> dayExercises;
  WorkoutPlan({
    required this.id,
    required this.name,
    required this.weekdays,
    required this.dayExercises,
  });
  List<Exercise> exercisesFor(int day) => dayExercises['$day'] ?? const [];
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'weekdays': weekdays,
        'dayExercises': dayExercises.map(
          (k, v) => MapEntry(k, v.map((e) => e.toPlanJson()).toList()),
        ),
      };
  factory WorkoutPlan.fromJson(Map<String, dynamic> j) {
    final raw = Map<String, dynamic>.from((j['dayExercises'] as Map?) ?? {});
    return WorkoutPlan(
      id: (j['id'] ?? '').toString(),
      name: (j['name'] ?? 'Treino').toString(),
      weekdays: ((j['weekdays'] as List?) ?? const [])
          .map((e) => (e as num).toInt())
          .where((e) => e >= 1 && e <= 7)
          .toList(),
      dayExercises: raw.map(
        (k, v) => MapEntry(
          k,
          ((v as List?) ?? const [])
              .map((e) => Exercise.fromPlanJson(Map<String, dynamic>.from(e as Map)))
              .toList(),
        ),
      ),
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
  factory Meal.fromJson(Map<String, dynamic> j) => Meal(
        id: (j['id'] ?? '').toString(),
        date: (j['date'] ?? '').toString(),
        type: (j['type'] ?? 'Refeição').toString(),
        food: (j['food'] ?? '').toString(),
        calories: (j['calories'] as num?)?.toDouble() ?? 0,
        protein: (j['protein'] as num?)?.toDouble() ?? 0,
        carbs: (j['carbs'] as num?)?.toDouble() ?? 0,
        fat: (j['fat'] as num?)?.toDouble() ?? 0,
        source: (j['source'] ?? 'manual').toString(),
      );
}

class MoneyTransaction {
  String id;
  String date;
  String description;
  String category;
  double amount;
  bool income;
  String paymentStatus;
  bool isRecurring;
  bool isInstallment;
  String installmentGroupId;
  int totalInstallments;
  int installmentNumber;
  double totalAmount;
  double installmentAmount;
  String dueDate;
  String? paidDate;
  String recurrenceFrequency;
  String recurrenceStartDate;
  String? recurrenceEndDate;
  String? recurrenceGroupId;
  String? notes;

  MoneyTransaction({
    required this.id,
    required this.date,
    required this.description,
    required this.category,
    required this.amount,
    required this.income,
    this.paymentStatus = 'paid',
    this.isRecurring = false,
    this.isInstallment = false,
    this.installmentGroupId = '',
    this.totalInstallments = 1,
    this.installmentNumber = 1,
    double? totalAmount,
    double? installmentAmount,
    String? dueDate,
    this.paidDate,
    this.recurrenceFrequency = 'monthly',
    this.recurrenceStartDate = '',
    this.recurrenceEndDate,
    this.recurrenceGroupId,
    this.notes,
  })  : totalAmount = totalAmount ?? amount,
        installmentAmount = installmentAmount ?? amount,
        dueDate = dueDate ?? date;

  bool get isPaid => paymentStatus == 'paid';
  bool get isPending => paymentStatus == 'pending';
  bool get isOverdue => paymentStatus == 'overdue';
  bool get isCancelled => paymentStatus == 'cancelled';

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date,
        'description': description,
        'category': category,
        'amount': amount,
        'income': income,
        'paymentStatus': paymentStatus,
        'isRecurring': isRecurring,
        'isInstallment': isInstallment,
        'installmentGroupId': installmentGroupId,
        'totalInstallments': totalInstallments,
        'installmentNumber': installmentNumber,
        'totalAmount': totalAmount,
        'installmentAmount': installmentAmount,
        'dueDate': dueDate,
        'paidDate': paidDate,
        'recurrenceFrequency': recurrenceFrequency,
        'recurrenceStartDate': recurrenceStartDate,
        'recurrenceEndDate': recurrenceEndDate,
        'recurrenceGroupId': recurrenceGroupId,
        'notes': notes,
      };

  factory MoneyTransaction.fromJson(Map<String, dynamic> j) {
    final amount = (j['amount'] as num?)?.toDouble() ?? 0;
    final date = (j['date'] ?? '').toString();
    return MoneyTransaction(
      id: (j['id'] ?? '').toString(),
      date: date,
      description: (j['description'] ?? '').toString(),
      category: (j['category'] ?? 'Outros').toString(),
      amount: amount,
      income: j['income'] == true,
      paymentStatus: (j['paymentStatus'] ?? 'paid').toString(),
      isRecurring: j['isRecurring'] == true,
      isInstallment: j['isInstallment'] == true,
      installmentGroupId: (j['installmentGroupId'] ?? '').toString(),
      totalInstallments: (j['totalInstallments'] as num?)?.toInt() ?? 1,
      installmentNumber: (j['installmentNumber'] as num?)?.toInt() ?? 1,
      totalAmount: (j['totalAmount'] as num?)?.toDouble() ?? amount,
      installmentAmount: (j['installmentAmount'] as num?)?.toDouble() ?? amount,
      dueDate: (j['dueDate'] ?? date).toString(),
      paidDate: j['paidDate']?.toString(),
      recurrenceFrequency: (j['recurrenceFrequency'] ?? 'monthly').toString(),
      recurrenceStartDate: (j['recurrenceStartDate'] ?? date).toString(),
      recurrenceEndDate: j['recurrenceEndDate']?.toString(),
      recurrenceGroupId: j['recurrenceGroupId']?.toString(),
      notes: j['notes']?.toString(),
    );
  }
}

class FinancialForecast {
  String id;
  String month;
  double projectedIncome;
  double projectedExpenses;
  double installmentTotal;
  double recurringExpenseTotal;
  double committedTotal;
  double projectedBalance;
  List<String> sourceTransactionIds;
  FinancialForecast({
    required this.id,
    required this.month,
    required this.projectedIncome,
    required this.projectedExpenses,
    required this.installmentTotal,
    required this.recurringExpenseTotal,
    required this.committedTotal,
    required this.projectedBalance,
    this.sourceTransactionIds = const [],
  });
  Map<String, dynamic> toJson() => {
        'id': id,
        'month': month,
        'projectedIncome': projectedIncome,
        'projectedExpenses': projectedExpenses,
        'installmentTotal': installmentTotal,
        'recurringExpenseTotal': recurringExpenseTotal,
        'committedTotal': committedTotal,
        'projectedBalance': projectedBalance,
        'sourceTransactionIds': sourceTransactionIds,
      };
}

class InstallmentPlan {
  String id;
  String description;
  String category;
  double totalAmount;
  double installmentAmount;
  int totalInstallments;
  String firstDueDate;
  String installmentGroupId;
  List<String> installments;
  String status;
  InstallmentPlan({
    required this.id,
    required this.description,
    required this.category,
    required this.totalAmount,
    required this.installmentAmount,
    required this.totalInstallments,
    required this.firstDueDate,
    required this.installmentGroupId,
    this.installments = const [],
    this.status = 'active',
  });
}

class RecurringExpense {
  String id;
  String description;
  String category;
  double amount;
  String frequency;
  String startDate;
  String? endDate;
  List<String> occurrences;
  String status;
  RecurringExpense({
    required this.id,
    required this.description,
    required this.category,
    required this.amount,
    required this.frequency,
    required this.startDate,
    this.endDate,
    this.occurrences = const [],
    this.status = 'active',
  });
}

class AgendaEvent {
  String id;
  String date;
  String title;
  String description;
  String start;
  String end;
  bool notify;
  AgendaEvent({
    required this.id,
    required this.date,
    required this.title,
    required this.description,
    required this.start,
    required this.end,
    this.notify = false,
  });
  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date,
        'title': title,
        'description': description,
        'start': start,
        'end': end,
        'notify': notify,
      };
  factory AgendaEvent.fromJson(Map<String, dynamic> j) => AgendaEvent(
        id: (j['id'] ?? '').toString(),
        date: (j['date'] ?? '').toString(),
        title: (j['title'] ?? '').toString(),
        description: (j['description'] ?? '').toString(),
        start: (j['start'] ?? '08:00').toString(),
        end: (j['end'] ?? '09:00').toString(),
        notify: j['notify'] == true,
      );
}

class WeightEntry {
  String date;
  double weight;
  WeightEntry({required this.date, required this.weight});
  Map<String, dynamic> toJson() => {'date': date, 'weight': weight};
  factory WeightEntry.fromJson(Map<String, dynamic> j) => WeightEntry(
        date: (j['date'] ?? '').toString(),
        weight: (j['weight'] as num?)?.toDouble() ?? 0,
      );
}
