library sqljocky.ok_packet;

import 'package:typed_buffer/typed_buffer.dart';

class OkPacket {
  int _affectedRows;
  int _insertId;
  int _serverStatus;
  String _message;

  int get affectedRows => _affectedRows;
  int get insertId => _insertId;
  int get serverStatus => _serverStatus;
  String get message => _message;

  OkPacket(ReadBuffer buffer) {
    buffer.seek(1);
    _affectedRows = buffer.readLengthCodedBinary();
    _insertId = buffer.readLengthCodedBinary();
    _serverStatus = buffer.uint16;
    _message = buffer.stringToEnd;
  }

  String toString() =>
      "OK: affected rows: $affectedRows, insert id: $insertId, server status: $serverStatus, message: $message";
}
