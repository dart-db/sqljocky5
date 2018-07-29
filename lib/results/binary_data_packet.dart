library sqljocky.binary_data_packet;

import 'package:sqljocky5/constants.dart';
import 'package:sqljocky5/results/blob.dart';
import 'package:typed_buffer/typed_buffer.dart';

import '../results/field.dart';

List<dynamic> parseBinaryDataResponse(ReadBuffer buffer, List<Field> fields) {
  buffer.skip(1);
  var nulls = buffer.readList(((fields.length + 7 + 2) / 8).floor().toInt());
  var nullMap = new List<bool>(fields.length);
  var shift = 2;
  var byte = 0;

  for (var i = 0; i < fields.length; i++) {
    var mask = 1 << shift;
    nullMap[i] = (nulls[byte] & mask) != 0;
    shift++;
    if (shift > 7) {
      shift = 0;
      byte++;
    }
  }

  final values = new List(fields.length);
  for (var i = 0; i < fields.length; i++) {
    if (nullMap[i]) {
      values[i] = null;
      continue;
    }
    var field = fields[i];
    values[i] = _readField(field, buffer);
  }

  return values;
}

dynamic _readField(Field field, ReadBuffer buffer) {
  switch (field.type) {
    case FIELD_TYPE_BLOB:
      var len = buffer.readLengthCodedBinary();
      var value = new Blob.fromBytes(buffer.readList(len));
      return value;
    case FIELD_TYPE_TINY:
      var value = buffer.byte;
      return value;
    case FIELD_TYPE_SHORT:
      var value = buffer.int16;
      return value;
    case FIELD_TYPE_INT24:
      var value = buffer.int32;
      return value;
    case FIELD_TYPE_LONG:
      var value = buffer.int32;
      return value;
    case FIELD_TYPE_LONGLONG:
      var value = buffer.int64;
      return value;
    case FIELD_TYPE_NEWDECIMAL:
      var len = buffer.byte;
      var num = buffer.readString(len);
      var value = double.parse(num);
      return value;
    case FIELD_TYPE_FLOAT:
      var value = buffer.float;
      return value;
    case FIELD_TYPE_DOUBLE:
      var value = buffer.double_;
      return value;
    case FIELD_TYPE_BIT:
      var len = buffer.byte;
      var list = buffer.readList(len);
      var value = 0;
      for (var num in list) {
        value = (value << 8) + num;
      }
      return value;
    case FIELD_TYPE_DATETIME:
    case FIELD_TYPE_DATE:
    case FIELD_TYPE_TIMESTAMP:
      var len = buffer.byte;
      var date = buffer.readList(len);
      var year = 0;
      var month = 0;
      var day = 0;
      var hours = 0;
      var minutes = 0;
      var seconds = 0;
      var billionths = 0;

      if (date.length > 0) {
        year = date[0] + (date[1] << 0x08);
        month = date[2];
        day = date[3];
        if (date.length > 4) {
          hours = date[4];
          minutes = date[5];
          seconds = date[6];
          if (date.length > 7) {
            billionths = date[7] +
                (date[8] << 0x08) +
                (date[9] << 0x10) +
                (date[10] << 0x18);
          }
        }
      }

      var value = new DateTime(
          year, month, day, hours, minutes, seconds, billionths ~/ 1000000);
      return value;
    case FIELD_TYPE_TIME:
      var len = buffer.byte;
      var time = buffer.readList(len);

      var sign = 1;
      var days = 0;
      var hours = 0;
      var minutes = 0;
      var seconds = 0;
      var billionths = 0;

      if (time.length > 0) {
        sign = time[0] == 1 ? -1 : 1;
        days =
            time[1] + (time[2] << 0x08) + (time[3] << 0x10) + (time[4] << 0x18);
        hours = time[5];
        minutes = time[6];
        seconds = time[7];
        if (time.length > 8) {
          billionths = time[8] +
              (time[9] << 0x08) +
              (time[10] << 0x10) +
              (time[11] << 0x18);
        }
      }
      var value = new Duration(
          days: days * sign,
          hours: hours * sign,
          minutes: minutes * sign,
          seconds: seconds * sign,
          milliseconds: (billionths ~/ 1000000) * sign);
      return value;
    case FIELD_TYPE_YEAR:
      var value = buffer.int16;
      return value;
    case FIELD_TYPE_STRING:
      var value = buffer.readLengthCodedString();
      return value;
    case FIELD_TYPE_VAR_STRING:
      var value = buffer.readLengthCodedString();
      return value;
    case FIELD_TYPE_GEOMETRY:
      var len = buffer.byte;
      //TODO
      var value = buffer.readList(len);
      return value;
    case FIELD_TYPE_NEWDATE:
    case FIELD_TYPE_DECIMAL:
    //TODO pre 5.0.3 will return old decimal values
    case FIELD_TYPE_SET:
    case FIELD_TYPE_ENUM:
    case FIELD_TYPE_TINY_BLOB:
    case FIELD_TYPE_MEDIUM_BLOB:
    case FIELD_TYPE_LONG_BLOB:
    case FIELD_TYPE_VARCHAR:
      //Are there any other types a mysql server can return?
      break;
    default:
      break;
  }
  return null;
}
