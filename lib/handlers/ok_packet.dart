library sqljocky.ok_packet;

import 'package:typed_buffer/typed_buffer.dart';

class OkPacket {
  final int affectedRows;
  final int insertId;
  final int serverStatus;
  final String message;

  OkPacket({this.affectedRows, this.insertId, this.serverStatus, this.message});

  factory OkPacket.fromBuffer(ReadBuffer buffer) {
    buffer.seek(1);
    int affectedRows = buffer.readLengthCodedBinary();
    int insertId = buffer.readLengthCodedBinary();
    int serverStatus = buffer.uint16;
    String message = buffer.stringToEnd;

    return OkPacket(
        affectedRows: affectedRows,
        insertId: insertId,
        serverStatus: serverStatus,
        message: message);
  }

  String toString() => "OK: affected rows: $affectedRows, "
      "insert id: $insertId, "
      "server status: $serverStatus, "
      "message: $message";
}
