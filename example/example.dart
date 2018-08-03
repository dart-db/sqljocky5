import 'package:sqljocky5/sqljocky.dart';
import 'package:options_file/options_file.dart';
import 'dart:async';

/// Drops the tables if they already exist
Future<void> dropTables(MySqlConnection conn) async {
  print("Dropping tables ...");
  await conn.execute("DROP TABLE IF EXISTS pets, people");
  print("Dropped tables!");
}

Future<void> createTables(MySqlConnection conn) async {
  print("Creating tables ...");
  await conn.execute('CREATE TABLE people (id INTEGER NOT NULL auto_increment, '
      'name VARCHAR(255), '
      'age INTEGER, '
      'PRIMARY KEY (id))');
  await conn.execute('CREATE TABLE pets (id INTEGER NOT NULL auto_increment, '
      'name VARCHAR(255), '
      'species TEXT, '
      'owner_id INTEGER, '
      'PRIMARY KEY (id),'
      'FOREIGN KEY (owner_id) REFERENCES people (id))');
  print("Created table!");
}

Future<void> insertRows(MySqlConnection conn) async {
  print("Inserting rows ...");
  List<Results> r1 =
      await conn.queryMulti("INSERT INTO people (name, age) VALUES (?, ?)", [
    ["Dave", 15],
    ["John", 16],
    ["Mavis", 93],
  ]);
  print("People table insert ids: " + r1.map((r) => r.insertId).toString());
  List<Results> r2 = await conn.queryMulti(
      "INSERT INTO pets (name, species, owner_id) VALUES (?, ?, ?)", [
    ["Rover", "Dog", 1],
    ["Daisy", "Cow", 2],
    ["Spot", "Dog", 2]
  ]);
  print("Pet table insert ids: " + r2.map((r) => r.insertId).toString());
  print("Rows inserted!");
}

Future<void> readData(MySqlConnection conn) async {
  Results result =
      await conn.execute('SELECT p.id, p.name, p.age, t.name AS pet, t.species '
          'FROM people p '
          'LEFT JOIN pets t ON t.owner_id = p.id');
  print(result);
  print(result.map((r) => r.byName('name')));
}

main() async {
  var options = OptionsFile('connection.options');

  var s = ConnectionSettings(
    user: options.getString('user'),
    password: options.getString('password', null),
    port: options.getInt('port', 3306),
    db: options.getString('db'),
    host: options.getString('host', 'localhost'),
  );

  // create a connection
  print("Opening connection ...");
  var conn = await MySqlConnection.connect(s);
  print("Opened connection!");

  await dropTables(conn);
  await createTables(conn);
  await insertRows(conn);
  await readData(conn);

  await conn.close();
}
