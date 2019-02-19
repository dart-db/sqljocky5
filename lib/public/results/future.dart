import 'dart:async';
import 'package:async/async.dart';

import 'results.dart';

class StreamedFuture extends DelegatingFuture<StreamedResults>
    implements Future<StreamedResults> {
  StreamedFuture(Future<StreamedResults> future) : super(future);

  Future<Results> deStream() => then((r) => r.deStream());
}
