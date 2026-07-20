import 'package:flutter/material.dart';

class WeightEntryDialog extends StatefulWidget {
  final double? initialWeight;

  const WeightEntryDialog({super.key, this.initialWeight});

  @override
  State<WeightEntryDialog> createState() => _WeightEntryDialogState();
}

class _WeightEntryDialogState extends State<WeightEntryDialog> {
  late final TextEditingController controller;
  String? errorText;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(
      text: widget.initialWeight == null
          ? ''
          : _formatNumber(widget.initialWeight!),
    );
  }

  String _formatNumber(num value) {
    return value.toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '');
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _submit() {
    final input = controller.text.trim();
    String? validationError;
    if (input.isEmpty) {
      validationError = '請輸入體重';
    } else if (double.tryParse(input) == null) {
      validationError = '請輸入有效的數字';
    } else {
      final weight = double.parse(input);
      if (!weight.isFinite || weight < 20 || weight > 500) {
        validationError = '體重必須介於 20–500 kg';
      } else if (!RegExp(r'^\d+(\.\d)?$').hasMatch(input)) {
        validationError = '體重最多只能有一位小數';
      } else {
        Navigator.pop(context, weight);
        return;
      }
    }

    setState(() => errorText = validationError);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initialWeight == null ? '記錄體重' : '修改體重'),
      content: TextField(
        key: const Key('weightField'),
        controller: controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: '體重（kg）',
          hintText: '例如 90.5',
          errorText: errorText,
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          key: const Key('saveWeightButton'),
          onPressed: _submit,
          child: const Text('儲存'),
        ),
      ],
    );
  }
}
