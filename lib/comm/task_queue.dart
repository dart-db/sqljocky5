import 'dart:async';
import 'dart:collection';

typedef Task<T> = Future<T> Function();

class _Task<T> {
  final int id;

  final Task<T> task;

  final Completer<T> completer;

  _Task(this.id, this.task, this.completer);
}

class TaskQueue {
  final _tasks = Queue<_Task>();

  Completer _completer;

  int id = 0;

  Future<T> run<T>(Task task) async {
    var ts = _Task<T>(++id, task, Completer<T>());
    _tasks.add(ts);
    _schedule();
    return ts.completer.future;
  }

  void _schedule() {
    if (_tasks.isEmpty) return;
    if (_completer == null) _next(_tasks.removeFirst());
  }

  void _next(_Task task) {
    _completer = task.completer;
    task.task().then((v) {
      task.completer.complete(v);
      _completer = null;
      _schedule();
    }, onError: (e, st) {
      task.completer.completeError(e, st);
      _completer = null;
      _schedule();
    });
  }
}
