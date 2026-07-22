import 'package:flutter/material.dart';

import '../../daily_tasks/presentation/daily_tasks_screen.dart';
import '../../extra_tasks/presentation/extra_tasks_screen.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Задачи'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Center(
              child: SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('Ежедневные')),
                  ButtonSegment(value: 1, label: Text('Доп. задачи')),
                ],
                selected: {_selected},
                onSelectionChanged: (selection) => setState(() => _selected = selection.first),
              ),
            ),
          ),
        ),
      ),
      body: IndexedStack(
        index: _selected,
        children: const [DailyTasksScreen(), ExtraTasksScreen()],
      ),
    );
  }
}
