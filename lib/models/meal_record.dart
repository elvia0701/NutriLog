class MealRecord {
  final int? id;
  final String date;
  final String mealType;
  final int foodId;
  final double servings;

  MealRecord({
    this.id,
    required this.date,
    required this.mealType,
    required this.foodId,
    required this.servings,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date,
      'meal_type': mealType,
      'food_id': foodId,
      'servings': servings,
    };
  }

  factory MealRecord.fromMap(Map<String, dynamic> map) {
    return MealRecord(
      id: map['id'] as int?,
      date: map['date'] as String,
      mealType: map['meal_type'] as String,
      foodId: map['food_id'] as int,
      servings: (map['servings'] as num).toDouble(),
    );
  }
}