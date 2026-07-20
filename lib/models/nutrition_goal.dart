class NutritionGoal {
  final int? id;
  final String effectiveDate;
  final double calorieTarget;
  final double proteinTarget;

  const NutritionGoal({
    this.id,
    required this.effectiveDate,
    required this.calorieTarget,
    required this.proteinTarget,
  });

  factory NutritionGoal.fromMap(Map<String, dynamic> map) {
    return NutritionGoal(
      id: map['id'] as int?,
      effectiveDate: map['effective_date'] as String,
      calorieTarget: (map['calorie_target'] as num).toDouble(),
      proteinTarget: (map['protein_target'] as num).toDouble(),
    );
  }
}
