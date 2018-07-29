const int headerSize = 4;

class PacketNumber {
  int packNum;

  int compressedPackNum;

  PacketNumber({this.packNum = -1, this.compressedPackNum = -1});

  void reset() {
    packNum = -1;
    compressedPackNum = -1;
  }
}
