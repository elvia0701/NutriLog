class Food {
  final int? id;
  final String name;
  final int calories;
  final double protein;
  final double carbs;
  final double fat;
  final bool favorite;
  final bool isArchived;

  Food({
    this.id,
    required this.name,
    required this.calories,
    required this.protein,
    this.carbs = 0,
    this.fat = 0,
    this.favorite = false,
    this.isArchived = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'favorite': favorite ? 1 : 0,
      'is_archived': isArchived ? 1 : 0,
    };
  }

  factory Food.fromMap(Map<String, dynamic> map) {
    return Food(
      id: map['id'],
      name: map['name'],
      calories: map['calories'],
      protein: (map['protein'] as num).toDouble(),
      carbs: (map['carbs'] as num).toDouble(),
      fat: (map['fat'] as num).toDouble(),
      favorite: map['favorite'] == 1,
      isArchived: (map['is_archived'] as int? ?? 0) == 1,
    );
  }
}
