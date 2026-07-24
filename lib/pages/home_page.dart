import 'package:flutter/material.dart';
import 'add_food_page.dart';

import '../auth/auth_service.dart';
import '../widgets/dashboard_summary.dart';
import '../widgets/meal_section.dart';
import '../models/meal_item.dart';
import '../models/weight_record.dart';
import '../models/nutrition_goal.dart';
import '../repositories/weight_repository.dart';
import '../repositories/nutrition_goal_repository.dart';
import '../repositories/food_repository.dart';
import '../repositories/meal_repository.dart';
import '../utils/local_date.dart';
import '../widgets/weight_entry_dialog.dart';
import 'weight_history_page.dart';
import 'nutrition_goal_page.dart';
import 'settings_page.dart';

class HomePage extends StatefulWidget {
  final FoodRepository foodRepository;
  final MealRepository mealRepository;
  final WeightRepository weightRepository;
  final NutritionGoalRepository nutritionGoalRepository;
  final DateTime? todayOverride;
  final Future<List<MealItem>> Function(String date, String mealType)?
  mealItemsLoader;
  final Future<void> Function(MealItem item)? mealRecordDeleter;
  final AuthService? authService;
  final bool localProfileDataEnabled;

  const HomePage({
    super.key,
    required this.foodRepository,
    required this.mealRepository,
    required this.weightRepository,
    required this.nutritionGoalRepository,
    this.todayOverride,
    this.mealItemsLoader,
    this.mealRecordDeleter,
    this.authService,
    this.localProfileDataEnabled = true,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<MealItem> breakfastItems = [];
  List<MealItem> lunchItems = [];
  List<MealItem> dinnerItems = [];
  List<MealItem> snackItems = [];
  late DateTime selectedDate;
  bool historicalDateUnlocked = false;
  WeightRecord? selectedWeight;
  NutritionGoal? selectedGoal;
  bool _isMealLoading = true;
  bool _isMealMutating = false;
  Object? _mealLoadError;

  DateTime get today => localDateOnly(widget.todayOverride ?? DateTime.now());
  bool get isViewingToday => isSameLocalDate(selectedDate, today);
  bool get canEditRecords => isViewingToday || historicalDateUnlocked;

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
    loadMealItems();
  }

  Future<void> loadMealItems() async {
    final requestedDate = databaseDate(selectedDate);
    if (mounted) {
      setState(() {
        _isMealLoading = true;
        _mealLoadError = null;
      });
    }

    List<List<MealItem>>? meals;
    Object? mealError;
    try {
      meals = await Future.wait<List<MealItem>>([
        _loadMealType(requestedDate, 'breakfast'),
        _loadMealType(requestedDate, 'lunch'),
        _loadMealType(requestedDate, 'dinner'),
        _loadMealType(requestedDate, 'snack'),
      ]);
    } catch (error, stackTrace) {
      mealError = error;
      debugPrint('HomePage failed to load meals: $error');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      if (mounted && requestedDate == databaseDate(selectedDate)) {
        setState(() {
          if (mealError == null && meals != null) {
            breakfastItems = meals[0];
            lunchItems = meals[1];
            dinnerItems = meals[2];
            snackItems = meals[3];
          }
          _mealLoadError = mealError;
          _isMealLoading = false;
        });
      }
    }

    if (widget.localProfileDataEnabled) {
      await _loadLocalProfileData(requestedDate);
    }
  }

  Future<void> _loadLocalProfileData(String requestedDate) async {
    try {
      final results = await Future.wait<Object?>([
        _loadWeight(requestedDate),
        _loadGoal(requestedDate),
      ]);
      if (!mounted || requestedDate != databaseDate(selectedDate)) return;
      setState(() {
        selectedWeight = results[0] as WeightRecord?;
        selectedGoal = results[1] as NutritionGoal?;
      });
    } catch (error, stackTrace) {
      debugPrint('HomePage failed to load local profile data: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<List<MealItem>> _loadMealType(String date, String mealType) {
    final loader = widget.mealItemsLoader;
    if (loader != null) return loader(date, mealType);
    return widget.mealRepository.getMealItemsByDateAndMealType(date, mealType);
  }

  Future<WeightRecord?> _loadWeight(String date) {
    return widget.weightRepository.getWeightForDate(date);
  }

  Future<NutritionGoal?> _loadGoal(String date) {
    return widget.nutritionGoalRepository.getGoalForDate(date);
  }

  Future<void> deleteMealItem(MealItem item) async {
    if (_isMealMutating) return;
    setState(() => _isMealMutating = true);
    try {
      final deleter = widget.mealRecordDeleter;
      if (deleter != null) {
        await deleter(item);
      } else {
        await widget.mealRepository.deleteMealRecord(item);
      }
      await loadMealItems();
    } catch (error, stackTrace) {
      debugPrint('HomePage failed to delete meal: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      final message = error is MealRepositoryException
          ? error.message
          : '無法刪除餐點，請稍後再試。';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _isMealMutating = false);
    }
  }

  Future<void> _editWeight() async {
    if (!canEditRecords) return;
    final weight = await showDialog<double>(
      context: context,
      builder: (context) =>
          WeightEntryDialog(initialWeight: selectedWeight?.weight),
    );
    if (weight == null) return;

    final date = databaseDate(selectedDate);
    await widget.weightRepository.saveWeight(date, weight);
    await loadMealItems();
  }

  Future<void> _deleteWeight() async {
    if (!canEditRecords || selectedWeight == null) return;
    final date = databaseDate(selectedDate);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('刪除體重紀錄？'),
        content: Text('確定要刪除 $date 的體重紀錄嗎？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('刪除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await widget.weightRepository.deleteWeight(date);
    await loadMealItems();
  }

  Future<void> _openWeightHistory() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (context) =>
            WeightHistoryPage(weightRepository: widget.weightRepository),
      ),
    );
  }

  Future<void> _openGoalSettings() async {
    final currentGoal = await _loadGoal(databaseDate(today));
    if (!mounted) return;
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => NutritionGoalPage(
          nutritionGoalRepository: widget.nutritionGoalRepository,
          todayOverride: today,
          initialGoal: currentGoal,
        ),
      ),
    );
    if (changed == true) await loadMealItems();
  }

  Future<void> _openSettings() async {
    final authService = widget.authService;
    if (authService == null) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (context) => SettingsPage(authService: authService),
      ),
    );
  }

  Future<void> _createReusableFood() async {
    final result = await Navigator.push<AddFoodResult>(
      context,
      MaterialPageRoute(builder: (context) => const AddFoodPage()),
    );
    if (result == null) return;

    try {
      await widget.foodRepository.insertFood(result.food);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('食物已建立。')));
    } catch (error) {
      if (!mounted) return;
      final message = error is FoodRepositoryException
          ? error.message
          : '無法建立食物，請稍後再試。';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
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
      selectedWeight = null;
      selectedGoal = null;
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
        content: Text(
          '解鎖 ${fullLocalDate(selectedDate)} 後，可在本次查看期間補記、修改或刪除餐點與體重。',
        ),
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
    final theme = Theme.of(context);
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
                    Text('今天', style: theme.textTheme.titleLarge),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
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
              child: Text(historicalDateUnlocked ? '此日已解鎖，可修正餐點與體重' : '此日已封存'),
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

  Widget _buildMealContent() {
    if (_isMealLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: CircularProgressIndicator(key: Key('mealLoadingIndicator')),
        ),
      );
    }

    final error = _mealLoadError;
    if (error != null) {
      final message = error is MealRepositoryException
          ? error.message
          : '無法載入餐點資料，請稍後再試。';
      return Card(
        key: const Key('mealLoadError'),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(
                Icons.cloud_off_outlined,
                color: Theme.of(context).colorScheme.error,
                size: 40,
              ),
              const SizedBox(height: 12),
              const Text('無法載入餐點資料'),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.icon(
                key: const Key('retryLoadMealsButton'),
                onPressed: loadMealItems,
                icon: const Icon(Icons.refresh),
                label: const Text('重新載入'),
              ),
            ],
          ),
        ),
      );
    }

    final canEditMeals = canEditRecords && !_isMealMutating;
    return Column(
      children: [
        MealSection(
          title: '早餐',
          mealType: 'breakfast',
          date: databaseDate(selectedDate),
          canEdit: canEditMeals,
          foodRepository: widget.foodRepository,
          mealRepository: widget.mealRepository,
          items: breakfastItems,
          onMealAdded: loadMealItems,
          onDelete: deleteMealItem,
        ),
        MealSection(
          title: '午餐',
          mealType: 'lunch',
          date: databaseDate(selectedDate),
          canEdit: canEditMeals,
          foodRepository: widget.foodRepository,
          mealRepository: widget.mealRepository,
          items: lunchItems,
          onMealAdded: loadMealItems,
          onDelete: deleteMealItem,
        ),
        MealSection(
          title: '晚餐',
          mealType: 'dinner',
          date: databaseDate(selectedDate),
          canEdit: canEditMeals,
          foodRepository: widget.foodRepository,
          mealRepository: widget.mealRepository,
          items: dinnerItems,
          onMealAdded: loadMealItems,
          onDelete: deleteMealItem,
        ),
        MealSection(
          title: '點心',
          mealType: 'snack',
          date: databaseDate(selectedDate),
          canEdit: canEditMeals,
          foodRepository: widget.foodRepository,
          mealRepository: widget.mealRepository,
          items: snackItems,
          onMealAdded: loadMealItems,
          onDelete: deleteMealItem,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = constraints.maxWidth >= 600 ? 24.0 : 16.0;
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    20,
                    horizontalPadding,
                    104,
                  ),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'NutriLog',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                        ),
                        if (widget.authService != null)
                          IconButton(
                            key: const Key('settingsButton'),
                            onPressed: _openSettings,
                            tooltip: '設定',
                            icon: const Icon(Icons.settings_outlined),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    _buildDateHeader(),

                    if (!isViewingToday) ...[
                      const SizedBox(height: 8),
                      _buildHistoricalNotice(),
                    ],

                    const SizedBox(height: 20),

                    DashboardSummary(
                      totalCalories: totalCalories,
                      totalProtein: totalProtein,
                      goal: selectedGoal,
                      onOpenGoalSettings: widget.localProfileDataEnabled
                          ? _openGoalSettings
                          : null,
                      weight: selectedWeight?.weight,
                      canEditWeight:
                          widget.localProfileDataEnabled && canEditRecords,
                      onEditWeight: widget.localProfileDataEnabled
                          ? _editWeight
                          : null,
                      onDeleteWeight: widget.localProfileDataEnabled
                          ? _deleteWeight
                          : null,
                      onOpenWeightHistory: widget.localProfileDataEnabled
                          ? _openWeightHistory
                          : null,
                    ),

                    const SizedBox(height: 20),

                    _buildMealContent(),
                  ],
                ),
              ),
            );
          },
        ),
      ),

      floatingActionButton: FloatingActionButton.extended(
        tooltip: '建立可重複使用的食物',
        onPressed: _createReusableFood,
        icon: const Icon(Icons.restaurant_menu),
        label: const Text('建立食物'),
      ),
    );
  }
}
