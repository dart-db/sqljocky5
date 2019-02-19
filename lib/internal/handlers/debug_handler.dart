library sqljocky.debug_handler;

import 'dart:typed_data';
import 'package:sqljocky5/constants.dart';
import 'handler.dart';

class DebugHandler extends Handler {
  Uint8List createRequest() => Uint8List(1)..[0] = COM_DEBUG;
}
