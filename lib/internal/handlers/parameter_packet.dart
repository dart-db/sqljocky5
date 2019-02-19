library sqljocky.parameter_packet;

import 'package:typed_buffer/typed_buffer.dart';

// not using this one yet
class ParameterPacket {
  final int type;
  final int flags;
  final int decimals;
  final int length;

  ParameterPacket({this.type, this.flags, this.decimals, this.length});

  factory ParameterPacket.fromBuffer(ReadBuffer buffer) {
    int type = buffer.uint16;
    int flags = buffer.uint16;
    int decimals = buffer.byte;
    int length = buffer.uint32;

    return ParameterPacket(
        type: type, flags: flags, decimals: decimals, length: length);
  }
}
