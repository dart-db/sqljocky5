import 'dart:async';
import 'package:sqljocky5/sqljocky.dart';

Future<void> readData(MySqlConnection conn) async {
  Results result = await conn
      .execute('SELECT p.id, p.name, p.age, t.name AS pet, t.species '
          'FROM people p '
          'LEFT JOIN pets t ON t.owner_id = p.id')
      .deStream();
  print(result);
  print(result.map((r) => r.byName('name')));
}

main() async {
  var s = ConnectionSettings(
    user: "root",
    password: "dart_jaguar",
    host: "localhost",
    port: 3306,
    db: "example",
  );

  // create a connection
  print("Opening connection ...");
  final conn = await MySqlConnection.connect(s);
  print("Opened connection!");

  final tx = await conn.begin();
  print("Started transaction!");

  await Future.delayed(Duration(seconds: 10));

  try {
    Results result = await tx
        .execute('SELECT p.id, p.name, p.age, t.name AS pet, t.species '
            'FROM people p '
            'LEFT JOIN pets t ON t.owner_id = p.id')
        .deStream();
    print(result);
    print(result.map((r) => r.byName('name')));
    await tx.commit();
  } catch (e) {
    print("Exception!");
  }

  await conn.close();
}
