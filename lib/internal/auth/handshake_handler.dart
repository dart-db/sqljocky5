library sqljocky.handshake_handler;

import 'dart:math' as math;

import 'dart:convert';
import 'package:crypto/crypto.dart';

import 'package:typed_buffer/typed_buffer.dart';
import '../handlers/handler.dart';
import 'package:sqljocky5/public/exceptions/client_error.dart';
import 'package:sqljocky5/constants.dart';
import 'ssl_handler.dart';
import 'auth_handler.dart';

abstract class AuthPluginNames {
  static const mysqlNativePassword = "mysql_native_password";
  static const cachingSha2Password = "caching_sha2_password";
}

class HandshakeHandler extends Handler {
  static const String MYSQL_NATIVE_PASSWORD = "mysql_native_password";

  final String _user;
  final String _password;
  final String _db;
  final int _maxPacketSize;
  final int _characterSet;

  int protocolVersion;
  String serverVersion;
  int threadId;
  List<int> scrambleBuffer;
  int serverCapabilities;
  int serverLanguage;
  int serverStatus;
  int scrambleLength;
  String pluginName;
  bool useCompression = false;
  bool useSSL = false;

  HandshakeHandler(String this._user, String this._password,
      int this._maxPacketSize, int this._characterSet,
      [String db, bool useCompression, bool useSSL])
      : _db = db,
        this.useCompression = useCompression,
        this.useSSL = useSSL;

  /**
   * The server initiates the handshake after the client connects,
   * so a request will never be created.
   */
  Uint8List createRequest() {
    throw MySqlClientError("Cannot create a handshake request");
  }

  void readResponseBuffer(ReadBuffer response) {
    response.seek(0);
    protocolVersion = response.byte;
    if (protocolVersion != 10) {
      throw MySqlClientError("Protocol not supported");
    }
    serverVersion = response.nullTerminatedUtf8String;
    threadId = response.uint32;
    var scrambleBuffer1 = response.readList(8);
    response.skip(1);
    serverCapabilities = response.uint16;
    if (response.hasMore) {
      serverLanguage = response.byte;
      serverStatus = response.uint16;
      serverCapabilities += (response.uint16 << 0x10);

      //var secure = serverCapabilities & CLIENT_SECURE_CONNECTION;
      //var plugin = serverCapabilities & CLIENT_PLUGIN_AUTH;

      scrambleLength = response.byte;
      response.skip(10);
      if (serverCapabilities & CLIENT_SECURE_CONNECTION > 0) {
        var scrambleBuffer2 =
            response.readList(math.max(13, scrambleLength - 8) - 1);

        // read null-terminator
        response.byte;
        scrambleBuffer =
            List<int>(scrambleBuffer1.length + scrambleBuffer2.length);
        scrambleBuffer.setRange(0, 8, scrambleBuffer1);
        scrambleBuffer.setRange(8, 8 + scrambleBuffer2.length, scrambleBuffer2);
      } else {
        scrambleBuffer = scrambleBuffer1;
      }

      if (serverCapabilities & CLIENT_PLUGIN_AUTH > 0) {
        pluginName = response.stringToEnd;
        if (pluginName.codeUnitAt(pluginName.length - 1) == 0) {
          pluginName = pluginName.substring(0, pluginName.length - 1);
        }
      }
    }
  }

  /// After receiving the handshake packet, if all is well, an [_AuthHandler]
  /// is created and returned to handle authentication.
  ///
  /// Currently, if the client protocol version is not 4.1, an
  /// exception is thrown.
  HandlerResponse processResponse(ReadBuffer response) {
    checkResponse(response);

    readResponseBuffer(response);

    if ((serverCapabilities & CLIENT_PROTOCOL_41) == 0) {
      throw MySqlClientError("Unsupported protocol (must be 4.1 or newer");
    }

    if ((serverCapabilities & CLIENT_SECURE_CONNECTION) == 0) {
      throw MySqlClientError("Old Password Authentication is not supported");
    }

    List<int> pwdHash = [];

    if ((serverCapabilities & CLIENT_PLUGIN_AUTH) != 0) {
      if (pluginName == AuthPluginNames.mysqlNativePassword) {
        pwdHash = makeMysqlNativePassword(scrambleBuffer, _password);
      } else if (pluginName == AuthPluginNames.cachingSha2Password) {
        pwdHash = makeCachingSha2Password(scrambleBuffer, _password);
      } else {
        throw MySqlClientError(
            "Authentication plugin not supported: $pluginName");
      }
    }

    int clientFlags = CLIENT_PROTOCOL_41 |
        CLIENT_LONG_PASSWORD |
        CLIENT_LONG_FLAG |
        CLIENT_TRANSACTIONS |
        CLIENT_SECURE_CONNECTION;

    if (useCompression && (serverCapabilities & CLIENT_COMPRESS) != 0) {
      clientFlags |= CLIENT_COMPRESS;
    } else {
      useCompression = false;
    }

    if (useSSL && (serverCapabilities & CLIENT_SSL) != 0) {
      clientFlags |= CLIENT_SSL | CLIENT_SECURE_CONNECTION;
    } else {
      useSSL = false;
    }

    if (useSSL) {
      return HandlerResponse(
          nextHandler: SSLHandler(
              clientFlags,
              _maxPacketSize,
              _characterSet,
              AuthHandler(
                _user,
                pwdHash,
                _db,
                clientFlags,
                _maxPacketSize,
                _characterSet,
              )));
    }

    return HandlerResponse(
        nextHandler: AuthHandler(
            _user, pwdHash, _db, clientFlags, _maxPacketSize, _characterSet));
  }
}

/// Hash password using 4.1+ method (SHA1)
List<int> makeMysqlNativePassword(List<int> scrambler, String password) {
  if (password == null) return [];

  // SHA1(password)
  final shaPwd = sha1.convert(utf8.encode(password)).bytes;
  // SHA1(SHA1(password))
  final shaShaPwd = sha1.convert(shaPwd).bytes;

  final bytes = List<int>.from(scrambler)..addAll(shaShaPwd);

  // SHA1(scramble, SHA1(SHA1(password)))
  final List<int> hash = sha1.convert(bytes).bytes;

  // XOR(SHA1(password), SHA1(scramble, SHA1(SHA1(password))))
  for (int i = 0; i < hash.length; i++) hash[i] ^= shaPwd[i];
  return hash;
}

/// Hash password using MySQL 8+ method (SHA256)
/// XOR(SHA256(password), SHA256(SHA256(SHA256(password)), scramble))
List<int> makeCachingSha2Password(List<int> scrambler, String password) {
  if (password == null) return [];

  // SHA256(password)
  final List<int> shaPwd = sha256.convert(utf8.encode(password)).bytes;
  // SHA256(SHA256(password))
  final List<int> shaShaPwd = sha256.convert(shaPwd).bytes;
  // SHA256(SHA256(SHA256(password)), scramble)
  final List<int> res =
      sha256.convert(List.from(shaShaPwd)..addAll(scrambler)).bytes;
  // XOR(SHA256(password), SHA256(SHA256(SHA256(password)), scramble))
  for (int i = 0; i < res.length; i++) res[i] ^= shaPwd[i];
  return res;
}
