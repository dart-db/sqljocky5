library sqljocky.prepare_ok_packet;

import 'package:typed_buffer/typed_buffer.dart';

class PrepareOkPacket {
  final int statementHandlerId;
  final int columnCount;
  final int parameterCount;
  final int warningCount;

  PrepareOkPacket(
      {this.statementHandlerId,
      this.columnCount,
      this.parameterCount,
      this.warningCount});

  factory PrepareOkPacket.fromBuffer(ReadBuffer buffer) {
    buffer.seek(1);
    int statementHandlerId = buffer.uint32;
    int columnCount = buffer.uint16;
    int parameterCount = buffer.uint16;
    buffer.skip(1);
    int warningCount = buffer.uint16;

    return PrepareOkPacket(
        statementHandlerId: statementHandlerId,
        columnCount: columnCount,
        parameterCount: parameterCount,
        warningCount: warningCount);
  }

  String toString() => "OK: statement handler id: $statementHandlerId, "
      "columns: $columnCount, "
      "parameters: $parameterCount, "
      "warnings: $warningCount";
}
