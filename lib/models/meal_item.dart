class MealItem {
  final int recordId;
  final int foodId;
  final String date;
  final String mealType;
  final double servings;
  final String foodName;
  final int calories;
  final double protein;

  MealItem({
    required this.recordId,
    required this.foodId,
    required this.date,
    required this.mealType,
    required this.servings,
    required this.foodName,
    required this.calories,
    required this.protein,
  });

  factory MealItem.fromMap(Map<String, dynamic> map) {
    return MealItem(
      recordId: map['record_id'] as int,
      foodId: map['food_id'] as int,
      date: map['date'] as String,
      mealType: map['meal_type'] as String,
      servings: (map['servings'] as num).toDouble(),
      foodName: map['food_name'] as String,
      calories: map['calories'] as int,
      protein: (map['protein'] as num).toDouble(),
    );
  }

  double get totalCalories => calories * servings;

  double get totalProtein => protein * servings;
}