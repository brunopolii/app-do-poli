import 'package:shared_preferences/shared_preferences.dart';

import 'license_service.dart';
import 'storage_service.dart';

/// Central rules for Free and Premium access. Existing records are never deleted.
class PlanService {
  static const int agendaLimit = 5;
  static const int workoutLimit = 1;
  static const int foodMonthlyLimit = 50;
  static const int financeMonthlyLimit = 50;

  final LicenseService _licenses = LicenseService();

  Future<bool> get hasPremium async {
    final key = await _licenses.storedLicenseKey();
    if (key == null || key.isEmpty) return false;
    return _licenses.isActivated();
  }

  Future<bool> get isFormerPremium async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('polirotinas_paid_license_previously_installed') ?? false;
  }

  Future<bool> get agendaOnly async => (await isFormerPremium) && !(await hasPremium);

  Future<bool> canCreateAgenda() async {
    if (await hasPremium) return true;
    final events = await StorageService.read('agenda');
    final today = DateTime.now();
    final active = events.where((raw) {
      final date = DateTime.tryParse((raw['date'] ?? '').toString());
      return date == null || !DateTime(date.year, date.month, date.day).isBefore(DateTime(today.year, today.month, today.day));
    }).length;
    return active < agendaLimit;
  }

  Future<bool> canCreateWorkoutPlan() async {
    if (await hasPremium) return true;
    return (await StorageService.read('workout_plans')).isEmpty;
  }

  Future<bool> canCreateWorkout() async {
    if (await hasPremium) return true;
    return (await StorageService.read('workout_history')).isEmpty;
  }

  Future<bool> canCreateFoodRecord() async {
    if (await hasPremium) return true;
    final now = DateTime.now();
    final meals = await StorageService.read('meals');
    return meals.where((raw) {
      final date = DateTime.tryParse((raw['date'] ?? '').toString());
      return date != null && date.year == now.year && date.month == now.month;
    }).length < foodMonthlyLimit;
  }

  Future<bool> canCreateDiaryNote(String dateKey) async {
    if (await hasPremium) return true;
    final notes = await StorageService.read('diary_notes');
    return !notes.any((note) => (note['date'] ?? '').toString() == dateKey);
  }

  Future<bool> canCreateFinanceRecord() async {
    if (await hasPremium) return true;
    final now = DateTime.now();
    final items = await StorageService.read('finance');
    return items.where((raw) {
      final date = DateTime.tryParse((raw['dueDate'] ?? raw['date'] ?? '').toString());
      return date != null && date.year == now.year && date.month == now.month;
    }).length < financeMonthlyLimit;
  }
}
