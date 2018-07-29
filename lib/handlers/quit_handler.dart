library sqljocky.quit_handler;

import 'package:logging/logging.dart';

import 'package:sqljocky5/constants.dart';
import 'package:sqljocky5/comm/buffer.dart';
import 'package:sqljocky5/exceptions/exceptions.dart';
import 'handler.dart';

class QuitHandler extends Handler {
  QuitHandler() : super(new Logger("QuitHandler"));

  Buffer createRequest() {
    var buffer = new Buffer(1);
    buffer.writeByte(COM_QUIT);
    return buffer;
  }

  processResponse(Buffer response) => throw MySqlProtocolError(
      "Shouldn't have received a response after sending a QUIT message");
}
