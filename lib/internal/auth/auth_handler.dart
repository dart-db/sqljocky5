library sqljocky.auth_handler;

import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'package:sqljocky5/constants.dart';
import 'package:typed_buffer/typed_buffer.dart';
import '../handlers/handler.dart';

class AuthHandler extends Handler {
  final String username;
  final String password;
  final String db;
  final List<int> scrambleBuffer;
  final int clientFlags;
  final int maxPacketSize;
  final int characterSet;
  final bool _ssl;

  AuthHandler(this.username, this.password, this.db, this.scrambleBuffer,
      this.clientFlags, this.maxPacketSize, this.characterSet,
      {bool ssl = false})
      : _ssl = ssl;

  List<int> getHash() {
    List<int> hash;
    if (password == null) {
      hash = <int>[];
    } else {
      final hashedPassword = sha1.convert(utf8.encode(password)).bytes;
      final doubleHashedPassword = sha1.convert(hashedPassword).bytes;

      final bytes = List<int>.from(scrambleBuffer)
        ..addAll(doubleHashedPassword);
      final List<int> hashedSaltedPassword = sha1.convert(bytes).bytes;

      hash = List<int>(hashedSaltedPassword.length);
      for (int i = 0; i < hash.length; i++) {
        hash[i] = hashedSaltedPassword[i] ^ hashedPassword[i];
      }
    }
    return hash;
  }

  Uint8List createRequest() {
    // Calculate the mysql password hash
    List<int> hash = getHash();

    List<int> encodedUsername = username == null ? [] : utf8.encode(username);
    List<int> encodedDb;

    int size = hash.length + encodedUsername.length + 2 + 32;
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
    buffer.byte = hash.length;
    buffer.writeList(hash);

    if (db != null) buffer.nullTerminatedList = encodedDb;

    return buffer.data;
  }
}
