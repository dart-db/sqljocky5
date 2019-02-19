int measureLengthCodedBinary(int value) {
  if (value < 251) {
    return 1;
  }
  if (value < (2 << 15)) {
    return 3;
  }
  if (value < (2 << 23)) {
    return 4;
  }
  if (value < (2 << 63)) {
    return 5;
  }
  throw ArgumentError('value is out of range');
}
