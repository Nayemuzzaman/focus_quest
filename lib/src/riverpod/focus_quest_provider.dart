import 'package:focus_quest/src/controller/focus_quest_controller.dart';
import 'package:focus_quest/src/models/focus_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final focusQuestControllerProvider = Provider<FocusQuestController>((ref) {
  return FocusQuestController();
});

final focusQuestStateProvider =
    StateNotifierProvider<FocusQuestNotifier, FocusQuestState>((ref) {
      final controller = ref.watch(focusQuestControllerProvider);
      return FocusQuestNotifier(controller);
    });

class FocusQuestNotifier extends StateNotifier<FocusQuestState> {
  FocusQuestNotifier(this.controller) : super(controller.state) {
    controller.addListener(_sync);
  }

  final FocusQuestController controller;

  Future<void> initialize() async {
    await controller.initialize();
    state = controller.state;
  }

  Future<void> start({
    Duration? duration,
    Map<String, Object?>? metadata,
  }) async {
    await controller.start(duration: duration, metadata: metadata);
    state = controller.state;
  }

  Future<void> pause() async {
    await controller.pause();
    state = controller.state;
  }

  Future<void> resume() async {
    await controller.resume();
    state = controller.state;
  }

  Future<void> complete() async {
    await controller.complete();
    state = controller.state;
  }

  Future<void> cancel({String? reason}) async {
    await controller.cancel(reason: reason);
    state = controller.state;
  }

  Future<void> reset() async {
    await controller.reset();
    state = controller.state;
  }

  Future<void> refreshStatistics() async {
    await controller.refreshStatistics();
    state = controller.state;
  }

  Future<void> clearError() async {
    await controller.clearError();
    state = controller.state;
  }

  void _sync() {
    state = controller.state;
  }

  @override
  void dispose() {
    controller.removeListener(_sync);
    super.dispose();
  }
}
