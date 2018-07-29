import 'package:sqljocky5/sqljocky.dart';
import 'package:options_file/options_file.dart';
import 'dart:async';

/// Drops the tables if they already exist
Future<void> dropTables(MySqlConnection conn) async {
  print("Dropping tables ...");
  await conn.query("DROP TABLE IF EXISTS pets, people");
  print("Dropped tables!");
}

Future<void> createTables(MySqlConnection conn) async {
  print("Creating tables ...");

  await conn.query('CREATE TABLE people (id INTEGER NOT NULL auto_increment, '
      'name VARCHAR(255), '
      'age INTEGER, '
      'PRIMARY KEY (id))');
  await conn.query('CREATE TABLE pets (id INTEGER NOT NULL auto_increment, '
      'name VARCHAR(255), '
      'species TEXT, '
      'owner_id INTEGER, '
      'PRIMARY KEY (id),'
      'FOREIGN KEY (owner_id) REFERENCES people (id))');
  print("Created table!");
}

/*
class Example {
  ConnectionPool pool;

  Example(this.pool);

  Future run() async {
    // add some data
    await addData();
    // and read it back out
    await readData();
  }

  Future addData() async {
    var query =
        await pool.prepare("insert into people (name, age) values (?, ?)");
    print("prepared query 1");
    var parameters = [
      ["Dave", 15],
      ["John", 16],
      ["Mavis", 93]
    ];
    await query.executeMulti(parameters);

    print("executed query 1");
    query = await pool
        .prepare("insert into pets (name, species, owner_id) values (?, ?, ?)");

    print("prepared query 2");
    parameters = [
      ["Rover", "Dog", 1],
      ["Daisy", "Cow", 2],
      ["Spot", "Dog", 2]
    ];
//          ["Spot", "D\u0000og", 2]];
    await query.executeMulti(parameters);

    print("executed query 2");
  }

  Future readData() async {
    print("querying");
    var result =
        await pool.query('select p.id, p.name, p.age, t.name, t.species '
            'from people p '
            'left join pets t on t.owner_id = p.id');
    print("got results");
    return result.forEach((row) {
      if (row[3] == null) {
        print("ID: ${row[0]}, Name: ${row[1]}, Age: ${row[2]}, No Pets");
      } else {
        print(
            "ID: ${row[0]}, Name: ${row[1]}, Age: ${row[2]}, Pet Name: ${row[3]}, Pet Species ${row[4]}");
      }
    });
  }
}
*/

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

  await conn.close();
}
