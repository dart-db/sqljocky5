library sqljocky.quit_handler;

import 'package:sqljocky5/constants.dart';
import 'package:sqljocky5/public/exceptions/exceptions.dart';
import 'handler.dart';

class QuitHandler extends Handler {
  Uint8List createRequest() => Uint8List(1)..[0] = COM_QUIT;

  HandlerResponse processResponse(_) => throw MySqlProtocolError(
      "Shouldn't have received a response after sending a QUIT message");
}
