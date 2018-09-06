# SQLJocky5

MySQL client for Dart.

## Creating a connection

```dart
  var s = ConnectionSettings(
    user: "root",
    password: "dart_jaguar",
    host: "localhost",
    port: 3306,
    db: "example",
  );
  var conn = await MySqlConnection.connect(s);
```

## Closing a connection

```dart
  await conn.close();
```

## Execute a query

```dart
Results results = await conn.execute('select name, email from users');
```

`Results` is an iterable of `Row`. Columns can be accessed from `Row` using
integer index or by name.

```dart
results.forEach((Row row) {
  // Access columns by index
  print('Name: ${row[0]}, email: ${row[1]}');
  // Access columns by name
  print('Name: ${row.name}, email: ${row.email}');
});
```

## Prepared query

```dart
await conn.prepared('insert into users (name, email, age) values (?, ?, ?)',
  ['Bob', 'bob@bob.com', 25]);
```

## Insert id

An insert query's results will be empty, but will have an id if there was
an auto-increment column in the table:

```dart
print("New user's id: ${result.insertId}");
```

## Prepared multiple queries

```dart
var results = await query.preparedMulti(
  'insert into users (name, email, age) values (?, ?, ?)',
  [['Bob', 'bob@bob.com', 25],
   ['Bill', 'bill@bill.com', 26],
   ['Joe', 'joe@joe.com', 37]]);
```


## Transactions

```dart
Transaction trans = await pool.begin();
try {
  var result1 = await trans.execute('...');
  var result2 = await trans.execute('...');
  await trans.commit();
} catch(e) {
  await trans.rollback();
}
```

### Safe transaction

```dart
await pool.transaction((trans) {
  var result1 = await trans.execute('...');
  var result2 = await trans.execute('...');
});
```

# TODO

* Compression
* COM_SEND_LONG_DATA
* CLIENT_MULTI_STATEMENTS and CLIENT_MULTI_RESULTS for stored procedures
* Better handling of various data types, especially BLOBs, which behave differently when using straight queries and prepared queries.
* Implement the rest of mysql's commands
* Handle character sets properly? Currently defaults to UTF8 for the connection character set. Is it
necessary to support anything else?
* Improve performance where possible
* Geometry type
* Decimal type should probably use a bigdecimal type of some sort
* MySQL 4 types (old decimal, anything else?)
* Test against multiple mysql versions
