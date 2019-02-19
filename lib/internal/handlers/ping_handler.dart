library sqljocky.ping_handler;

import 'package:sqljocky5/constants.dart';
import 'handler.dart';

class PingHandler extends Handler {
  Uint8List createRequest() => Uint8List(1)..[0] = COM_PING;
}
