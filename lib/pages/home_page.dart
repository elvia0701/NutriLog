import 'package:flutter/material.dart';
import 'package:nutrilog/models/food.dart';
import 'add_food_page.dart';

import '../widgets/dashboard_summary.dart';
import '../widgets/meal_section.dart';
import '../database/database_helper.dart';
import '../models/meal_item.dart';
import '../utils/local_date.dart';

class HomePage extends StatefulWidget {
  final DateTime? todayOverride;
  final Future<List<MealItem>> Function(String date, String mealType)?
  mealItemsLoader;
  final Future<void> Function(int recordId)? mealRecordDeleter;

  const HomePage({
    super.key,
    this.todayOverride,
    this.mealItemsLoader,
    this.mealRecordDeleter,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Food> foods = [];

  List<MealItem> breakfastItems = [];
  List<MealItem> lunchItems = [];
  List<MealItem> dinnerItems = [];
  List<MealItem> snackItems = [];
  late DateTime selectedDate;
  bool historicalDateUnlocked = false;

  DateTime get today => localDateOnly(widget.todayOverride ?? DateTime.now());
  bool get isViewingToday => isSameLocalDate(selectedDate, today);
  bool get canEditMeals => isViewingToday || historicalDateUnlocked;

  List<MealItem> get allMealItems => [
    ...breakfastItems,
    ...lunchItems,
    ...dinnerItems,
    ...snackItems,
  ];

  double get totalCalories =>
      allMealItems.fold(0, (total, item) => total + item.totalCalories);

  double get totalProtein =>
      allMealItems.fold(0, (total, item) => total + item.totalProtein);

  @override
  void initState() {
    super.initState();
    selectedDate = today;
    if (widget.mealItemsLoader == null) {
      loadFoods();
    }
    loadMealItems();
  }

  Future<void> loadFoods() async {
    final loadedFoods = await DatabaseHelper.instance.getFoods();

    final meals = await DatabaseHelper.instance.getAllMealRecords();

    debugPrint('========== MEAL RECORDS：${meals.length} ==========');

    if (!mounted) return;
    setState(() {
      foods = loadedFoods;
    });
  }

  Future<void> loadMealItems() async {
    final requestedDate = databaseDate(selectedDate);
    final results = await Future.wait([
      _loadMealType(requestedDate, 'breakfast'),
      _loadMealType(requestedDate, 'lunch'),
      _loadMealType(requestedDate, 'dinner'),
      _loadMealType(requestedDate, 'snack'),
    ]);

    if (!mounted) return;
    if (requestedDate != databaseDate(selectedDate)) return;

    setState(() {
      breakfastItems = results[0];
      lunchItems = results[1];
      dinnerItems = results[2];
      snackItems = results[3];
    });
  }

  Future<List<MealItem>> _loadMealType(String date, String mealType) {
    final loader = widget.mealItemsLoader;
    if (loader != null) return loader(date, mealType);
    return DatabaseHelper.instance.getMealItemsByDateAndMealType(
      date,
      mealType,
    );
  }

  Future<void> deleteMealItem(MealItem item) async {
    final deleter = widget.mealRecordDeleter;
    if (deleter != null) {
      await deleter(item.recordId);
    } else {
      await DatabaseHelper.instance.deleteMealRecord(item.recordId);
    }
    await loadMealItems();
  }

  Future<void> _changeDate(DateTime value) async {
    final date = localDateOnly(value);
    if (date.isAfter(today)) return;
    setState(() {
      selectedDate = date;
      historicalDateUnlocked = false;
      breakfastItems = [];
      lunchItems = [];
      dinnerItems = [];
      snackItems = [];
    });
    await loadMealItems();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2000),
      lastDate: today,
    );
    if (picked != null) await _changeDate(picked);
  }

  Future<void> _unlockHistoricalDate() async {
    if (isViewingToday || selectedDate.isAfter(today)) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('解鎖歷史日期？'),
        content: Text('解鎖 ${fullLocalDate(selectedDate)} 後，可在本次查看期間補記或刪除餐點。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('確認解鎖'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      setState(() => historicalDateUnlocked = true);
    }
  }

  Widget _buildDateHeader() {
    final subtitle = isViewingToday
        ? fullLocalDate(selectedDate)
        : '${fullLocalDate(selectedDate)} ${weekdayLabel(selectedDate)}';
    return Row(
      children: [
        IconButton(
          key: const Key('previousDayButton'),
          onPressed: () => _changeDate(
            DateTime(
              selectedDate.year,
              selectedDate.month,
              selectedDate.day - 1,
            ),
          ),
          tooltip: '前一天',
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: InkWell(
            key: const Key('datePickerButton'),
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  if (isViewingToday)
                    const Text(
                      '今天',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  Text(subtitle, style: const TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          ),
        ),
        IconButton(
          key: const Key('nextDayButton'),
          onPressed: isViewingToday
              ? null
              : () => _changeDate(
                  DateTime(
                    selectedDate.year,
                    selectedDate.month,
                    selectedDate.day + 1,
                  ),
                ),
          tooltip: '後一天',
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }

  Widget _buildHistoricalNotice() {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.lock_outline),
            const SizedBox(width: 8),
            Expanded(
              child: Text(historicalDateUnlocked ? '此日已解鎖，可修正餐點' : '此日已封存'),
            ),
            if (!historicalDateUnlocked)
              TextButton(
                key: const Key('unlockHistoricalButton'),
                onPressed: _unlockHistoricalDate,
                child: const Text('解鎖修正'),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: ListView(
            children: [
              const Text(
                'NutriLog',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              _buildDateHeader(),

              if (!isViewingToday) _buildHistoricalNotice(),

              const SizedBox(height: 24),

              DashboardSummary(
                totalCalories: totalCalories,
                totalProtein: totalProtein,
              ),

              const SizedBox(height: 24),

              MealSection(
                title: '早餐',
                mealType: 'breakfast',
                date: databaseDate(selectedDate),
                canEdit: canEditMeals,
                items: breakfastItems,
                onMealAdded: loadMealItems,
                onDelete: deleteMealItem,
              ),
              MealSection(
                title: '午餐',
                mealType: 'lunch',
                date: databaseDate(selectedDate),
                canEdit: canEditMeals,
                items: lunchItems,
                onMealAdded: loadMealItems,
                onDelete: deleteMealItem,
              ),

              MealSection(
                title: '晚餐',
                mealType: 'dinner',
                date: databaseDate(selectedDate),
                canEdit: canEditMeals,
                items: dinnerItems,
                onMealAdded: loadMealItems,
                onDelete: deleteMealItem,
              ),

              MealSection(
                title: '點心',
                mealType: 'snack',
                date: databaseDate(selectedDate),
                canEdit: canEditMeals,
                items: snackItems,
                onMealAdded: loadMealItems,
                onDelete: deleteMealItem,
              ),
            ],
          ),
        ),
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final AddFoodResult? result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddFoodPage()),
          );
          if (result != null) {
            await DatabaseHelper.instance.insertFood(result.food);
            await loadFoods();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
