library sqljocky.auth_handler;

import 'dart:convert';

import 'package:sqljocky5/constants.dart';
import 'package:typed_buffer/typed_buffer.dart';
import '../handlers/handler.dart';

class AuthHandler extends Handler {
  final String username;
  final List<int> pwdHash;
  final String db;
  final int clientFlags;
  final int maxPacketSize;
  final int characterSet;
  final bool _ssl;

  AuthHandler(this.username, this.pwdHash, this.db, this.clientFlags,
      this.maxPacketSize, this.characterSet,
      {bool ssl = false})
      : _ssl = ssl;

  Uint8List createRequest() {
    List<int> encodedUsername = username == null ? [] : utf8.encode(username);
    List<int> encodedDb;

    int size = pwdHash.length + encodedUsername.length + 2 + 32;
    int clientFlags = this.clientFlags;
    if (db != null) {
      encodedDb = utf8.encode(db);
      size += encodedDb.length + 1;
      clientFlags |= CLIENT_CONNECT_WITH_DB;
    }

    var buffer = FixedWriteBuffer(size);
    buffer.seekWrite(0);
    buffer.uint32 = clientFlags;
    buffer.uint32 = maxPacketSize;
    buffer.byte = characterSet;
    buffer.fill(23, 0);
    buffer.nullTerminatedList = encodedUsername;
    buffer.byte = pwdHash.length;
    buffer.writeList(pwdHash);

    if (db != null) buffer.nullTerminatedList = encodedDb;

    return buffer.data;
  }
}
