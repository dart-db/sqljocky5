library sqljocky.ping_handler;

import 'package:logging/logging.dart';

import 'package:sqljocky5/constants.dart';
import 'package:typed_buffer/typed_buffer.dart';
import 'handler.dart';

class PingHandler extends Handler {
  PingHandler() : super(new Logger("PingHandler"));

  Uint8List createRequest() => new Uint8List(1)..[0] = COM_PING;
}
