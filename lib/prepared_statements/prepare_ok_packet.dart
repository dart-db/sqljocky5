library sqljocky.prepare_ok_packet;

import 'package:typed_buffer/typed_buffer.dart';

class PrepareOkPacket {
  int _statementHandlerId;
  int _columnCount;
  int _parameterCount;
  int _warningCount;

  int get statementHandlerId => _statementHandlerId;
  int get columnCount => _columnCount;
  int get parameterCount => _parameterCount;
  int get warningCount => _warningCount;

  PrepareOkPacket(ReadBuffer buffer) {
    buffer.seek(1);
    _statementHandlerId = buffer.uint32;
    _columnCount = buffer.uint16;
    _parameterCount = buffer.uint16;
    buffer.skip(1);
    _warningCount = buffer.uint16;
  }

  String toString() =>
      "OK: statement handler id: $_statementHandlerId, columns: $_columnCount, "
      "parameters: $_parameterCount, warnings: $_warningCount";
}
