import 'package:flutter/material.dart';
import 'package:focus_quest/focus_quest.dart';

void main() {
  runApp(const FocusQuestExampleApp());
}

class FocusQuestExampleApp extends StatefulWidget {
  const FocusQuestExampleApp({super.key});

  @override
  State<FocusQuestExampleApp> createState() => _FocusQuestExampleAppState();
}

class _FocusQuestExampleAppState extends State<FocusQuestExampleApp>
    with WidgetsBindingObserver {
  late final FocusQuestController controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    controller = FocusQuestController(
      storage: SharedPreferencesFocusQuestStorage(
        prefix: 'focus_quest_example',
      ),
    );
    controller.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
    controller.initialize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      controller.handleLifecycleEvent(FocusLifecycleEvent.paused);
    } else if (state == AppLifecycleState.resumed) {
      controller.handleLifecycleEvent(FocusLifecycleEvent.resumed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    return MaterialApp(
      title: 'Focus Quest Example',
      home: Scaffold(
        appBar: AppBar(title: const Text('Focus Quest')),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reusable focus engine demo',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Text(
                  'Status: ${state.status.name}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Remaining: ${state.remainingDuration.inMinutes}:${(state.remainingDuration.inSeconds % 60).toString().padLeft(2, '0')}',
                ),
                const SizedBox(height: 8),
                Text('Focused today: ${state.focusedToday.inMinutes} min'),
                const SizedBox(height: 8),
                Text('Streak: ${state.currentStreak}'),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    ElevatedButton(
                      onPressed: () => controller.start(
                        duration: const Duration(minutes: 25),
                        metadata: {'category': 'study'},
                      ),
                      child: const Text('Start'),
                    ),
                    ElevatedButton(
                      onPressed: state.status == FocusSessionStatus.running
                          ? controller.pause
                          : null,
                      child: const Text('Pause'),
                    ),
                    ElevatedButton(
                      onPressed: state.status == FocusSessionStatus.paused
                          ? controller.resume
                          : null,
                      child: const Text('Resume'),
                    ),
                    ElevatedButton(
                      onPressed:
                          state.status == FocusSessionStatus.running ||
                              state.status == FocusSessionStatus.paused
                          ? controller.complete
                          : null,
                      child: const Text('Complete'),
                    ),
                    ElevatedButton(
                      onPressed:
                          state.status == FocusSessionStatus.running ||
                              state.status == FocusSessionStatus.paused
                          ? () => controller.cancel(reason: 'User cancelled')
                          : null,
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: ListView(
                    children: state.sessionHistory.reversed.map((session) {
                      return Card(
                        child: ListTile(
                          title: Text(session.status.name),
                          subtitle: Text(
                            '${session.targetDuration.inMinutes} min • ${session.actualFocusDuration.inMinutes} min focused',
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
