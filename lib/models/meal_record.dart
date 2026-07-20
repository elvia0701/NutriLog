class MealRecord {
  final int? id;
  final String date;
  final String mealType;
  final int foodId;
  final double servings;
  final String foodNameSnapshot;
  final double caloriesSnapshot;
  final double proteinSnapshot;
  final double carbsSnapshot;
  final double fatSnapshot;

  MealRecord({
    this.id,
    required this.date,
    required this.mealType,
    required this.foodId,
    required this.servings,
    required this.foodNameSnapshot,
    required this.caloriesSnapshot,
    required this.proteinSnapshot,
    required this.carbsSnapshot,
    required this.fatSnapshot,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date,
      'meal_type': mealType,
      'food_id': foodId,
      'servings': servings,
      'food_name_snapshot': foodNameSnapshot,
      'calories_snapshot': caloriesSnapshot,
      'protein_snapshot': proteinSnapshot,
      'carbs_snapshot': carbsSnapshot,
      'fat_snapshot': fatSnapshot,
    };
  }

  factory MealRecord.fromMap(Map<String, dynamic> map) {
    return MealRecord(
      id: map['id'] as int?,
      date: map['date'] as String,
      mealType: map['meal_type'] as String,
      foodId: map['food_id'] as int,
      servings: (map['servings'] as num).toDouble(),
      foodNameSnapshot: map['food_name_snapshot'] as String,
      caloriesSnapshot: (map['calories_snapshot'] as num).toDouble(),
      proteinSnapshot: (map['protein_snapshot'] as num).toDouble(),
      carbsSnapshot: (map['carbs_snapshot'] as num).toDouble(),
      fatSnapshot: (map['fat_snapshot'] as num).toDouble(),
    );
  }
}
