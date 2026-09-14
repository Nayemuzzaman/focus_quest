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

class _FocusQuestExampleAppState extends State<FocusQuestExampleApp> {
  late final FocusQuestController controller;
  late final FocusQuestLifecycleObserver lifecycleObserver;

  @override
  void initState() {
    super.initState();
    controller = FocusQuestController(
      storage: SharedPreferencesFocusQuestStorage(
        prefix: 'focus_quest_example',
      ),
      feedback: const FlutterFocusFeedback(),
    );
    controller.addListener(_onControllerChanged);
    // Forwards app lifecycle transitions (inactive, hidden, paused, resumed,
    // detached) to the controller so the configured background behavior runs.
    lifecycleObserver = FocusQuestLifecycleObserver(controller)..attach();
    controller.initialize();
  }

  @override
  void dispose() {
    lifecycleObserver.detach();
    controller.removeListener(_onControllerChanged);
    controller.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } on FocusQuestException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    final statistics = state.statistics;
    final isActive =
        state.status == FocusSessionStatus.running ||
        state.status == FocusSessionStatus.paused;

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
                if (state.error != null)
                  Text(
                    'Error: ${state.error}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
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
                Text(
                  'Streak: ${state.currentStreak} (best ${state.longestStreak})',
                ),
                const SizedBox(height: 8),
                Text(
                  'Level ${statistics.currentLevel} • '
                  '${statistics.progressToNextLevel}/'
                  '${statistics.progressToNextLevel + statistics.experienceToNextLevel} XP',
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(value: statistics.levelProgress),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    ElevatedButton(
                      onPressed: state.isLoading || isActive
                          ? null
                          : () => _run(
                              () => controller.start(
                                duration: const Duration(minutes: 25),
                                metadata: {'category': 'study'},
                              ),
                            ),
                      child: const Text('Start'),
                    ),
                    ElevatedButton(
                      onPressed: state.status == FocusSessionStatus.running
                          ? () => _run(controller.pause)
                          : null,
                      child: const Text('Pause'),
                    ),
                    ElevatedButton(
                      onPressed: state.status == FocusSessionStatus.paused
                          ? () => _run(controller.resume)
                          : null,
                      child: const Text('Resume'),
                    ),
                    ElevatedButton(
                      onPressed: isActive
                          ? () => _run(controller.complete)
                          : null,
                      child: const Text('Complete'),
                    ),
                    ElevatedButton(
                      onPressed: isActive
                          ? () => _run(
                              () => controller.cancel(reason: 'User cancelled'),
                            )
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
                          trailing: session.reward == null
                              ? null
                              : Text('+${session.reward!.points} pts'),
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
