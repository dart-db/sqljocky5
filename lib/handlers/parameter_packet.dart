library sqljocky.parameter_packet;

import 'package:typed_buffer/typed_buffer.dart';

// not using this one yet
class ParameterPacket {
  int _type;
  int _flags;
  int _decimals;
  int _length;

  int get type => _type;
  int get flags => _flags;
  int get decimals => _decimals;
  int get length => _length;

  ParameterPacket(ReadBuffer buffer) {
    _type = buffer.uint16;
    _flags = buffer.uint16;
    _decimals = buffer.byte;
    _length = buffer.uint32;
  }
}
