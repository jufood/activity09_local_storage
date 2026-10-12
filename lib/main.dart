import 'package:flutter/material.dart';
import 'database_helper.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final helper = DatabaseHelper();

  try {
    await helper.init();
    runApp(DirectoryApp(helper: helper));
  } catch (error, stackTrace) {
    debugPrint('Database initialization failed: $error\n$stackTrace');
    runApp(const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text('Could not open local storage.'),
        ),
      ),
    ));
  }
}

class DirectoryApp extends StatelessWidget {
  const DirectoryApp({super.key, required this.helper});

  final DatabaseHelper helper;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fall Festival Roster',
      debugShowCheckedModeBanner: false,
      home: HomePage(helper: helper),
    );
  }
}

class RosterPage extends StatefulWidget {
  const RosterPage({super.key, required this.helper});

  final DatabaseHelper helper;

  @override
  State<RosterPage> createState() => _RosterPageState();
}

class _RosterPageState extends State<RosterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();

  List<Map<String, dynamic>> _rows = [];
  int _count = 0;
  int? _editingId;

  bool _busy = false;
  bool _loaded = false;
  String? _error;
  String _message = '';

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<bool> _loadRows() async {
    try {
      final rows = await widget.helper.queryAllRows();
      final count = await widget.helper.queryRowCount();

      if (!mounted) return false;

      setState(() {
        _rows = rows;
        _count = count;
        _loaded = true;
        _error = null;
      });

      return true;
    } catch (error, stackTrace) {
      debugPrint('Read failed: $error\n$stackTrace');

      if (!mounted) return false;

      setState(() {
        _error = 'Could not load guests. Please retry.';
        _loaded = true;
      });

      return false;
    }
  }

  Future<void> _refresh() async {
    if (_busy) return;

    setState(() {
      _busy = true;
      _message = '';
    });

    try {
      await _loadRows();
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _clearForm() {
    _nameController.clear();
    _ageController.clear();
    _formKey.currentState?.reset();

    setState(() {
      _editingId = null;
    });
  }

  void _startEdit(Map<String, dynamic> row) {
    if (_busy) return;

    setState(() {
      _editingId = row[DatabaseHelper.columnId] as int;
      _nameController.text =
          row[DatabaseHelper.columnName] as String;
      _ageController.text =
          row[DatabaseHelper.columnAge].toString();
      _message = 'Editing guest ID $_editingId';
    });

    _formKey.currentState?.reset();
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter a name.';
    }
    return null;
  }

  String? _validateAge(String? value) {
    final age = int.tryParse(value?.trim() ?? '');

    if (age == null) {
      return 'Enter a whole number.';
    }

    if (age < 0 || age > 130) {
      return 'Age must be between 0 and 130.';
    }

    return null;
  }

  Future<void> _saveGuest() async {
    if (_busy) return;

    if (!_formKey.currentState!.validate()) {
      setState(() {
        _message = 'Invalid input. Nothing was saved.';
      });
      return;
    }

    final name = _nameController.text.trim();
    final age = int.parse(_ageController.text.trim());
    final editingId = _editingId;

    setState(() => _busy = true);

    try {
      int result;

      if (editingId == null) {
        result = await widget.helper.insert({
          DatabaseHelper.columnName: name,
          DatabaseHelper.columnAge: age,
        });
      } else {
        result = await widget.helper.update({
          DatabaseHelper.columnId: editingId,
          DatabaseHelper.columnName: name,
          DatabaseHelper.columnAge: age,
        });
      }

      if (!mounted) return;

      if (editingId != null && result == 0) {
        setState(() {
          _message = 'Guest not found. Nothing updated.';
        });
        await _loadRows();
        return;
      }

      _clearForm();

      final refreshed = await _loadRows();
      if (!mounted) return;

      setState(() {
        _message = refreshed
            ? editingId == null
                ? 'Guest added. ID: $result'
                : 'Guest updated. Rows affected: $result'
            : 'Saved, but refresh failed. Tap Refresh.';
      });
    } catch (error, stackTrace) {
      debugPrint('Save failed: $error\n$stackTrace');

      if (!mounted) return;

      setState(() {
        _message = 'Save failed. Please retry.';
      });
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _deleteGuest(Map<String, dynamic> row) async {
    if (_busy) return;

    final id = row[DatabaseHelper.columnId] as int;
    final name = row[DatabaseHelper.columnName] as String;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Guest?'),
        content: Text('Delete $name (ID: $id)?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true || _busy) return;

    setState(() => _busy = true);

    try {
      final deleted = await widget.helper.delete(id);

      if (!mounted) return;

      if (deleted == 0) {
        setState(() {
          _message = 'Guest not found. Nothing deleted.';
        });
        await _loadRows();
        return;
      }

      if (_editingId == id) {
        _clearForm();
      }

      final refreshed = await _loadRows();
      if (!mounted) return;

      setState(() {
        _message = refreshed
            ? 'Guest deleted. Rows affected: $deleted'
            : 'Deleted, but refresh failed. Tap Refresh.';
      });
    } catch (error, stackTrace) {
      debugPrint('Delete failed: $error\n$stackTrace');

      if (!mounted) return;

      setState(() {
        _message = 'Delete failed. Please retry.';
      });
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fall Festival Roster'),
        backgroundColor: Colors.orange.shade100,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameController,
                    enabled: !_busy,
                    decoration: const InputDecoration(
                      labelText: 'Guest Name',
                      border: OutlineInputBorder(),
                    ),
                    validator: _validateName,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _ageController,
                    enabled: !_busy,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Age',
                      border: OutlineInputBorder(),
                    ),
                    validator: _validateAge,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _busy ? null : _saveGuest,
                    child: Text(
                      _editingId == null ? 'Add Guest' : 'Save Edit',
                    ),
                  ),
                ),
                if (_editingId != null) ...[
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: _busy ? null : _clearForm,
                    child: const Text('Cancel Edit'),
                  ),
                ],
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _busy ? null : _refresh,
                  tooltip: 'Refresh',
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Total Guests: $_count',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (_message.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(_message),
              ),
            const Divider(),
            Expanded(
              child: _busy && !_loaded
                  ? const Center(
                      child: CircularProgressIndicator(),
                    )
                  : _error != null
                      ? Center(child: Text(_error!))
                      : !_loaded
                          ? const Center(
                              child: CircularProgressIndicator(),
                            )
                          : _rows.isEmpty
                              ? const Center(
                                  child: Text('No festival guests yet.'),
                                )
                              : ListView.builder(
                                  itemCount: _rows.length,
                                  itemBuilder: (context, index) {
                                    final row = _rows[index];
                                    final id =
                                        row[DatabaseHelper.columnId];

                                    return Card(
                                      child: ListTile(
                                        title: Text(
                                          row[DatabaseHelper.columnName]
                                              .toString(),
                                        ),
                                        subtitle: Text(
                                          'ID: $id | Age: '
                                          '${row[DatabaseHelper.columnAge]}',
                                        ),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              onPressed: _busy
                                                  ? null
                                                  : () => _startEdit(row),
                                              icon: const Icon(Icons.edit),
                                            ),
                                            IconButton(
                                              onPressed: _busy
                                                  ? null
                                                  : () => _deleteGuest(row),
                                              icon: const Icon(Icons.delete),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
            ),
          ],
        ),
      ),
    );
  }
}


// Activity 09: Keep the original Activity 08 guest screen accessible.
class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.helper});
  final DatabaseHelper helper;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selected,
        children: [
          RosterPage(helper: widget.helper),
          FolderPage(helper: widget.helper),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selected,
        onDestinationSelected: (index) => setState(() => _selected = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.people), label: 'Guests (Part I)'),
          NavigationDestination(icon: Icon(Icons.folder), label: 'Folders (Part II)'),
        ],
      ),
    );
  }
}

// Typed models keep row conversion out of widgets.
class FolderRecord {
  const FolderRecord({required this.id, required this.name, required this.createdAt, required this.cardCount});
  final int id;
  final String name;
  final String createdAt;
  final int cardCount;

  factory FolderRecord.fromMap(Map<String, Object?> map) => FolderRecord(
        id: map['id'] as int,
        name: map['name'] as String,
        createdAt: map['created_at'] as String,
        cardCount: (map['card_count'] as num).toInt(),
      );

  Map<String, Object?> toMap() => {'id': id, 'name': name, 'created_at': createdAt};
}

class CardRecord {
  const CardRecord({required this.id, required this.title, required this.suit,
    required this.notes, required this.imageRef, required this.folderId});
  final int id;
  final String title;
  final String suit;
  final String notes;
  final String? imageRef;
  final int folderId;

  factory CardRecord.fromMap(Map<String, Object?> map) => CardRecord(
        id: map['id'] as int,
        title: map['title'] as String,
        suit: map['suit'] as String,
        notes: map['notes'] as String,
        imageRef: map['image_ref'] as String?,
        folderId: map['folder_id'] as int,
      );

  Map<String, Object?> toMap() => {
        'id': id, 'title': title, 'suit': suit, 'notes': notes,
        'image_ref': imageRef, 'folder_id': folderId,
      };
}

class FolderPage extends StatefulWidget {
  const FolderPage({super.key, required this.helper});
  final DatabaseHelper helper;

  @override
  State<FolderPage> createState() => _FolderPageState();
}

class _FolderPageState extends State<FolderPage> {
  List<FolderRecord> _folders = [];
  bool _busy = false;
  bool _loaded = false;
  String? _error;
  String _message = '';

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    if (_busy) return;
    setState(() { _busy = true; _error = null; });
    try {
      final rows = await widget.helper.getFoldersWithCounts();
      if (!mounted) return;
      setState(() { _folders = rows.map(FolderRecord.fromMap).toList(); _loaded = true; });
    } catch (error, trace) {
      debugPrint('Folder read failed: $error\n$trace');
      if (mounted) setState(() { _loaded = true; _error = 'Could not load folders: $error'; });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addFolder() async {
    if (_busy) return;
    String enteredName = '';
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Create Folder'),
        content: TextField(
          autofocus: true,
          onChanged: (value) => enteredName = value,
          decoration: const InputDecoration(labelText: 'Folder name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, enteredName),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (!mounted || name == null) return;
    if (name.trim().isEmpty) {
      setState(() => _message = 'Folder name cannot be blank. Nothing saved.');
      return;
    }
    setState(() => _busy = true);
    String result;
    try {
      final id = await widget.helper.insertFolder(name.trim());
      result = 'Folder created, ID: $id';
    } catch (error, trace) {
      debugPrint('Create folder failed: $error\n$trace');
      result = 'Could not create folder (check for duplicate name): $error';
    }
    if (!mounted) return;
    setState(() { _busy = false; _message = result; });
    await _refresh();
  }

  Future<void> _deleteFolder(FolderRecord folder) async {
    if (_busy) return;
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Folder?'),
        content: Text('Delete "${folder.name}" (ID ${folder.id}) and ALL its cards?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Delete')),
        ],
      ),
    );
    if (!mounted || yes != true) return;
    setState(() => _busy = true);
    String result;
    try {
      final affected = await widget.helper.deleteFolder(folder.id);
      result = affected == 1 ? 'Folder deleted; rows affected: $affected' : 'Folder not found; rows affected: $affected';
    } catch (error, trace) {
      debugPrint('Delete folder failed: $error\n$trace');
      result = 'Delete failed: $error';
    }
    if (!mounted) return;
    setState(() { _busy = false; _message = result; });
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Card Catalogue'), backgroundColor: Colors.orange.shade100,
        actions: [IconButton(onPressed: _busy ? null : _refresh, icon: const Icon(Icons.refresh), tooltip: 'Refresh')]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : _addFolder,
        icon: const Icon(Icons.create_new_folder), label: const Text('Add Folder')),
      body: Column(children: [
        if (_message.isNotEmpty) Padding(padding: const EdgeInsets.all(12), child: Text(_message)),
        if (_busy) const LinearProgressIndicator(),
        Expanded(child: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : _error != null
            ? Center(child: Text(_error!))
            : _folders.isEmpty
              ? const Center(child: Text('No folders yet. Tap Add Folder.'))
              : ListView.builder(itemCount: _folders.length, itemBuilder: (context, index) {
                  final folder = _folders[index];
                  return Card(child: ListTile(
                    leading: const Icon(Icons.folder),
                    title: Text(folder.name),
                    subtitle: Text('ID: ${folder.id} | Cards: ${folder.cardCount}'),
                    onTap: _busy ? null : () async {
                      await Navigator.of(context).push(MaterialPageRoute<void>(
                        builder: (_) => CardPage(helper: widget.helper, folder: folder)));
                      if (mounted) await _refresh();
                    },
                    trailing: IconButton(
                      onPressed: _busy ? null : () => _deleteFolder(folder),
                      icon: const Icon(Icons.delete), tooltip: 'Delete folder'),
                  ));
                })),
      ]),
    );
  }
}

class CardPage extends StatefulWidget {
  const CardPage({super.key, required this.helper, required this.folder});
  final DatabaseHelper helper;
  final FolderRecord folder;

  @override
  State<CardPage> createState() => _CardPageState();
}

class _CardPageState extends State<CardPage> {
  List<CardRecord> _cards = [];
  bool _busy = false;
  bool _loaded = false;
  String? _error;
  String _message = '';

  @override
  void initState() { super.initState(); _refresh(); }

  Future<void> _refresh() async {
    if (_busy) return;
    setState(() { _busy = true; _error = null; });
    try {
      final rows = await widget.helper.getCards(widget.folder.id);
      if (mounted) setState(() { _cards = rows.map(CardRecord.fromMap).toList(); _loaded = true; });
    } catch (error, trace) {
      debugPrint('Card read failed: $error\n$trace');
      if (mounted) setState(() { _loaded = true; _error = 'Could not load cards: $error'; });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editCard([CardRecord? card]) async {
    if (_busy) return;
    final result = await Navigator.push<String>(context, MaterialPageRoute(
      builder: (_) => CardFormPage(helper: widget.helper, folder: widget.folder, existing: card)));
    if (!mounted) return;
    if (result != null) {
      setState(() => _message = result);
      await _refresh();
    }
  }

  Future<void> _deleteCard(CardRecord card) async {
    if (_busy) return;
    final yes = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
      title: const Text('Delete Card?'),
      content: Text('Delete "${card.title}" (ID ${card.id})?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Delete')),
      ],
    ));
    if (!mounted || yes != true) return;
    setState(() => _busy = true);
    String result;
    try {
      final affected = await widget.helper.deleteCard(card.id);
      result = affected == 1 ? 'Card deleted; rows affected: 1' : 'Card not found; rows affected: 0';
    } catch (error, trace) {
      debugPrint('Delete card failed: $error\n$trace');
      result = 'Card delete failed: $error';
    }
    if (!mounted) return;
    setState(() { _busy = false; _message = result; });
    await _refresh();
  }

  Widget _imageOrSuit(CardRecord card) {
    const symbols = {'Hearts': '♥', 'Diamonds': '♦', 'Clubs': '♣', 'Spades': '♠'};
    final symbol = Text(symbols[card.suit] ?? '?', style: const TextStyle(fontSize: 32));
    final ref = card.imageRef?.trim() ?? '';
    if (ref.isEmpty) return SizedBox(width: 52, child: Center(child: symbol));
    final uri = Uri.tryParse(ref);
    if (uri != null && (uri.scheme == 'https' || uri.scheme == 'http') && uri.host.isNotEmpty) {
      return SizedBox(width: 52, height: 52, child: Image.network(ref,
        fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => symbol));
    }
    if (ref.startsWith('assets/')) {
      return SizedBox(width: 52, height: 52, child: Image.asset(ref,
        fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => symbol));
    }
    return SizedBox(width: 52, child: Center(child: symbol));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('${widget.folder.name} Cards'),
      actions: [IconButton(onPressed: _busy ? null : _refresh, icon: const Icon(Icons.refresh))]),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _busy ? null : () => _editCard(), icon: const Icon(Icons.add), label: const Text('Add Card')),
    body: Column(children: [
      if (_message.isNotEmpty) Padding(padding: const EdgeInsets.all(12), child: Text(_message)),
      if (_busy) const LinearProgressIndicator(),
      Padding(padding: const EdgeInsets.all(8), child: Text('Folder ID: ${widget.folder.id} | Cards: ${_cards.length}')),
      Expanded(child: !_loaded
        ? const Center(child: CircularProgressIndicator())
        : _error != null ? Center(child: Text(_error!))
        : _cards.isEmpty ? const Center(child: Text('This folder has no cards.'))
        : ListView.builder(itemCount: _cards.length, itemBuilder: (context, index) {
            final card = _cards[index];
            return Card(child: ListTile(
              leading: _imageOrSuit(card),
              title: Text(card.title),
              subtitle: Text('ID: ${card.id} | ${card.suit}${card.notes.isEmpty ? '' : '\n${card.notes}'}'),
              isThreeLine: card.notes.isNotEmpty,
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(onPressed: _busy ? null : () => _editCard(card), icon: const Icon(Icons.edit)),
                IconButton(onPressed: _busy ? null : () => _deleteCard(card), icon: const Icon(Icons.delete)),
              ]),
            ));
          })),
    ]),
  );
}

class CardFormPage extends StatefulWidget {
  const CardFormPage({super.key, required this.helper, required this.folder, this.existing});
  final DatabaseHelper helper;
  final FolderRecord folder;
  final CardRecord? existing;

  @override
  State<CardFormPage> createState() => _CardFormPageState();
}

class _CardFormPageState extends State<CardFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _notes;
  late final TextEditingController _image;
  String _suit = 'Hearts';
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final old = widget.existing;
    _title = TextEditingController(text: old?.title ?? '');
    _notes = TextEditingController(text: old?.notes ?? '');
    _image = TextEditingController(text: old?.imageRef ?? '');
    _suit = old?.suit ?? 'Hearts';
  }

  @override
  void dispose() { _title.dispose(); _notes.dispose(); _image.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() { _busy = true; _error = null; });
    final fields = <String, dynamic>{
      'title': _title.text.trim(), 'suit': _suit, 'notes': _notes.text.trim(),
      'image_ref': _image.text.trim().isEmpty ? null : _image.text.trim(),
      'folder_id': widget.folder.id,
    };
    try {
      final existing = widget.existing;
      late final String result;
      if (existing == null) {
        final id = await widget.helper.insertCard(fields);
        result = 'Card added, ID: $id';
      } else {
        fields['id'] = existing.id;
        final affected = await widget.helper.updateCard(fields);
        result = affected == 1
            ? 'Card updated, ID: ${existing.id}; rows affected: $affected'
            : 'Card ID ${existing.id} not found; nothing updated.';
      }
      if (mounted) Navigator.pop(context, result);
    } catch (error, trace) {
      debugPrint('Card save failed: $error\n$trace');
      if (mounted) setState(() => _error = 'Save failed; nothing changed: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.existing == null ? 'Add Card' : 'Edit Card ID ${widget.existing!.id}')),
    body: Form(key: _formKey, child: ListView(padding: const EdgeInsets.all(16), children: [
      Text('Folder: ${widget.folder.name} (ID ${widget.folder.id})'),
      const SizedBox(height: 16),
      TextFormField(controller: _title, enabled: !_busy, decoration: const InputDecoration(
        labelText: 'Title', border: OutlineInputBorder()),
        validator: (text) => (text == null || text.trim().isEmpty) ? 'Title cannot be blank' : null),
      const SizedBox(height: 16),
      DropdownButtonFormField<String>(
        initialValue: _suit,
        decoration: const InputDecoration(labelText: 'Suit', border: OutlineInputBorder()),
        items: const ['Hearts', 'Diamonds', 'Clubs', 'Spades']
          .map((suit) => DropdownMenuItem(value: suit, child: Text(suit))).toList(),
        onChanged: _busy ? null : (value) { if (value != null) setState(() => _suit = value); }),
      const SizedBox(height: 16),
      TextFormField(controller: _notes, enabled: !_busy, maxLines: 2,
        decoration: const InputDecoration(labelText: 'Notes (optional)', border: OutlineInputBorder())),
      const SizedBox(height: 16),
      TextFormField(controller: _image, enabled: !_busy,
        decoration: const InputDecoration(labelText: 'Image reference (optional)',
          helperText: 'Leave empty for suit symbol', border: OutlineInputBorder())),
      if (_error != null) Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(_error!,
        style: const TextStyle(color: Colors.red))),
      const SizedBox(height: 20),
      FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'Saving...' : 'Save')),
      TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('Cancel')),
    ])),
  );
}
