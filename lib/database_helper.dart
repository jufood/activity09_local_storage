
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';

class DatabaseHelper {
  static const _databaseName = 'MyDatabase.db';
  static const _databaseVersion = 2;

  // Activity 08: Original guest table
  static const table = 'my_table';
  static const columnId = '_id';
  static const columnName = 'name';
  static const columnAge = 'age';

  // Activity 09: New tables
  static const foldersTable = 'folders';
  static const cardsTable = 'cards';

  late Database _db;

  // Open or upgrade the existing database.
  Future<void> init() async {
    final documentsDirectory =
        await getApplicationDocumentsDirectory();

    final path = join(
      documentsDirectory.path,
      _databaseName,
    );

    _db = await openDatabase(
      path,
      version: _databaseVersion,

      // Enable foreign key enforcement.
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },

      // Fresh installation: create all tables.
      onCreate: _onCreate,

      // Existing installation: preserve Activity 08 data.
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createCatalogueTables(db);
        }
      },
    );
  }

  // Create the complete database on a fresh installation.
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $table (
        $columnId INTEGER PRIMARY KEY,
        $columnName TEXT NOT NULL,
        $columnAge INTEGER NOT NULL
      )
    ''');

    await _createCatalogueTables(db);
  }

  // Create Activity 09 parent/child tables.
  Future<void> _createCatalogueTables(Database db) async {
    await db.execute('''
      CREATE TABLE $foldersTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE $cardsTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        suit TEXT NOT NULL,
        notes TEXT NOT NULL DEFAULT '',
        image_ref TEXT,
        folder_id INTEGER NOT NULL,
        FOREIGN KEY (folder_id)
          REFERENCES $foldersTable(id)
          ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_cards_folder_id
      ON $cardsTable(folder_id)
    ''');
  }

  // --------------------------------------------------
  // Activity 08: Original guest CRUD methods
  // --------------------------------------------------

  // CREATE: Insert a new guest.
  Future<int> insert(Map<String, dynamic> row) async {
    return await _db.insert(table, row);
  }

  // READ: Get all guests.
  Future<List<Map<String, dynamic>>> queryAllRows() async {
    return await _db.query(
      table,
      orderBy: '$columnId ASC',
    );
  }

  // READ: Get the number of guests.
  Future<int> queryRowCount() async {
    final results =
        await _db.rawQuery('SELECT COUNT(*) FROM $table');

    return Sqflite.firstIntValue(results) ?? 0;
  }

  // UPDATE: Update a guest by ID.
  Future<int> update(Map<String, dynamic> row) async {
    final int id = row[columnId] as int;

    return await _db.update(
      table,
      row,
      where: '$columnId = ?',
      whereArgs: [id],
    );
  }

  // DELETE: Delete a guest by ID.
  Future<int> delete(int id) async {
    return await _db.delete(
      table,
      where: '$columnId = ?',
      whereArgs: [id],
    );
  }

  // --------------------------------------------------
  // Activity 09: Folder CRUD methods
  // --------------------------------------------------

  // CREATE: Insert a folder.
  Future<int> insertFolder(String name) async {
    return await _db.insert(
      foldersTable,
      {
        'name': name.trim(),
        'created_at': DateTime.now().toIso8601String(),
      },
    );
  }

  // READ: Get folders and their card counts.
  Future<List<Map<String, Object?>>> getFoldersWithCounts() async {
    return await _db.rawQuery('''
      SELECT
        f.id,
        f.name,
        f.created_at,
        COUNT(c.id) AS card_count
      FROM $foldersTable f
      LEFT JOIN $cardsTable c
        ON c.folder_id = f.id
      GROUP BY f.id, f.name, f.created_at
      ORDER BY f.name COLLATE NOCASE ASC
    ''');
  }

  // DELETE: Delete a folder by ID.
  // Its cards are removed by ON DELETE CASCADE.
  Future<int> deleteFolder(int id) async {
    return await _db.delete(
      foldersTable,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --------------------------------------------------
  // Activity 09: Card CRUD methods
  // --------------------------------------------------

  // CREATE: Insert a new card.
  Future<int> insertCard(Map<String, dynamic> card) async {
    return await _db.insert(cardsTable, card);
  }

  // READ: Get cards belonging to a folder.
  Future<List<Map<String, Object?>>> getCards(int folderId) async {
    return await _db.query(
      cardsTable,
      where: 'folder_id = ?',
      whereArgs: [folderId],
      orderBy: 'title COLLATE NOCASE ASC, id ASC',
    );
  }

  // UPDATE: Update a card by its unique ID.
  Future<int> updateCard(Map<String, dynamic> card) async {
    final id = card['id'] as int;

    final values = Map<String, dynamic>.from(card);
    values.remove('id');

    return await _db.update(
      cardsTable,
      values,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // DELETE: Delete a card by ID.
  Future<int> deleteCard(int id) async {
    return await _db.delete(
      cardsTable,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --------------------------------------------------
  // Activity 09: Database verification methods
  // --------------------------------------------------

  // Check database version.
  Future<int> getDatabaseVersion() async {
    final results = await _db.rawQuery('PRAGMA user_version');
    return results.first['user_version'] as int;
  }

  // Check foreign-key enforcement.
  Future<int> getForeignKeysStatus() async {
    final results = await _db.rawQuery('PRAGMA foreign_keys');
    return results.first['foreign_keys'] as int;
  }

  // Check the relationship and delete rule.
  Future<List<Map<String, Object?>>> getCardForeignKeys() async {
    return await _db.rawQuery(
      'PRAGMA foreign_key_list(cards)',
    );
  }

  // Check the indexes on cards.
  Future<List<Map<String, Object?>>> getCardIndexes() async {
    return await _db.rawQuery(
      'PRAGMA index_list(cards)',
    );
  }
}
