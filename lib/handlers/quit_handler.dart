library sqljocky.quit_handler;

import 'package:logging/logging.dart';

import 'package:sqljocky5/constants.dart';
import 'package:sqljocky5/exceptions/exceptions.dart';
import 'handler.dart';

class QuitHandler extends Handler {
  QuitHandler() : super(new Logger("QuitHandler"));

  Uint8List createRequest() => new Uint8List(1)..[0] = COM_QUIT;

  HandlerResponse processResponse(_) => throw MySqlProtocolError(
      "Shouldn't have received a response after sending a QUIT message");
}
