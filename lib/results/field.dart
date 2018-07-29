library results.field;

import 'package:sqljocky5/comm/buffer.dart';

/// A MySQL field
class Field {
  /// The name of the field
  final String name;

  final String catalog;
  final String db;
  final String table;
  final String orgTable;

  final String orgName;
  final int characterSet;
  final int length;
  final int type;
  final int flags;
  final int decimals;
  final int defaultValue;

  Field(this.name,
      {this.catalog,
      this.db,
      this.table,
      this.orgTable,
      this.orgName,
      this.characterSet,
      this.length,
      this.type,
      this.flags,
      this.decimals,
      this.defaultValue});

  factory Field.fromBuffer(Buffer buffer) {
    String catalog = buffer.readLengthCodedString();
    String db = buffer.readLengthCodedString();
    String table = buffer.readLengthCodedString();
    String orgTable = buffer.readLengthCodedString();
    String name = buffer.readLengthCodedString();
    String orgName = buffer.readLengthCodedString();
    buffer.skip(1);
    int characterSet = buffer.readUint16();
    int length = buffer.readUint32();
    int type = buffer.readByte();
    int flags = buffer.readUint16();
    int decimals = buffer.readByte();
    buffer.skip(2);
    int defaultValue;
    if (buffer.canReadMore()) defaultValue = buffer.readLengthCodedBinary();

    return Field(name,
        catalog: catalog,
        db: db,
        table: table,
        orgTable: orgTable,
        orgName: orgName,
        characterSet: characterSet,
        length: length,
        type: type,
        flags: flags,
        decimals: decimals,
        defaultValue: defaultValue);
  }

  String toString() =>
      "Catalog: $catalog, DB: $db, Table: $table, Org Table: $orgTable, "
      "Name: $name, Org Name: $orgName, Character Set: $characterSet, "
      "Length: $length, Type: $type, Flags: $flags, Decimals: $decimals, "
      "Default Value: $defaultValue";
}
