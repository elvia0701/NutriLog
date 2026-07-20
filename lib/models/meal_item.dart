class MealItem {
  final int recordId;
  final int foodId;
  final String date;
  final String mealType;
  final double servings;
  final String foodName;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;

  MealItem({
    required this.recordId,
    required this.foodId,
    required this.date,
    required this.mealType,
    required this.servings,
    required this.foodName,
    required this.calories,
    required this.protein,
    this.carbs = 0,
    this.fat = 0,
  });

  factory MealItem.fromMap(Map<String, dynamic> map) {
    return MealItem(
      recordId: map['record_id'] as int,
      foodId: map['food_id'] as int,
      date: map['date'] as String,
      mealType: map['meal_type'] as String,
      servings: (map['servings'] as num).toDouble(),
      foodName: map['food_name'] as String,
      calories: (map['calories'] as num).toDouble(),
      protein: (map['protein'] as num).toDouble(),
      carbs: (map['carbs'] as num).toDouble(),
      fat: (map['fat'] as num).toDouble(),
    );
  }

  double get totalCalories => calories * servings;

  double get totalProtein => protein * servings;

  double get totalCarbs => carbs * servings;

  double get totalFat => fat * servings;
}
