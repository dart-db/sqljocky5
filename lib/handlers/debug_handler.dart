library sqljocky.debug_handler;

import 'dart:typed_data';
import 'package:logging/logging.dart';

import 'package:sqljocky5/constants.dart';
import 'handler.dart';

class DebugHandler extends Handler {
  DebugHandler() : super(new Logger("DebugHandler"));

  Uint8List createRequest() => new Uint8List(1)..[0] = COM_DEBUG;
}
