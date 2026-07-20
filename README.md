# NutriLog

NutriLog 是以 Flutter 開發的每日飲食與營養紀錄 App。

## 目前功能

- 依早餐、午餐、晚餐及點心記錄當日餐點
- 建立食物資料，保存每份熱量與蛋白質
- 搜尋並重複使用既有食物，只需輸入本次份數
- 建立新食物後可直接加入目前餐別
- 安全移除食物：未使用的資料永久刪除，有歷史紀錄時改為封存
- 自動計算每筆餐點與當日總熱量、總蛋白質
- 刪除單筆餐點紀錄並即時更新當日摘要
- 使用 SQLite 保存食物與餐點紀錄

## 技術棧

- Flutter、Dart、Material 3
- `sqflite`、`path`
- Flutter widget tests

## 執行方式

```sh
flutter pub get
flutter run
```

執行檢查與測試：

```sh
flutter analyze
flutter test
```

## 專案狀態

目前已完成每日餐點紀錄 MVP，包含份數計算、當日營養摘要及刪除紀錄。
