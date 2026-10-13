import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';

/// A minimal key/value sink for small JSON snapshots.
///
/// Deliberately tiny and synchronous-shaped so a controller can depend on the
/// abstraction and never on a plugin. Tests use [MemorySnapshotStore]; the app
/// uses [FileSnapshotStore].
abstract interface class SnapshotStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> remove(String key);

  /// Drops everything this store owns. Used on sign-out so one account's
  /// saved data never survives into the next session.
  Future<void> clear();
}

/// In-memory sink. The default in tests and the fallback when the platform has
/// no writable directory (web).
class MemorySnapshotStore implements SnapshotStore {
  final Map<String, String> _values = {};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    _values.remove(key);
  }

  @override
  Future<void> clear() async => _values.clear();
}

/// App-private file sink, used on mobile and desktop.
///
/// The cache lives in the platform's own application documents directory, which
/// the OS sandboxes per app: it is not world-readable and it is removed with
/// the app. Nothing here is a system of record — every value written is a copy
/// of data the server already returned to this signed-in account, and it is
/// cleared on sign-out.
class FileSnapshotStore implements SnapshotStore {
  const FileSnapshotStore({this.directory});

  /// Overridable so a caller (and a test) can supply its own directory.
  final Future<Directory> Function()? directory;

  static const _fileName = 'fixnow-last-good-cache.json';

  Future<File> _file() async {
    final base = directory != null
        ? await directory!()
        : await getApplicationDocumentsDirectory();
    if (!base.existsSync()) {
      await base.create(recursive: true);
    }
    return File('${base.path}${Platform.pathSeparator}$_fileName');
  }

  Future<Map<String, String>> _load() async {
    try {
      final file = await _file();
      if (!file.existsSync()) return {};
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) return {};
      return {
        for (final entry in decoded.entries)
          if (entry.key is String && entry.value is String)
            entry.key as String: entry.value as String,
      };
    } catch (_) {
      // A corrupt or unreadable cache file is not an error the user should see:
      // the app simply has no saved data and goes to the network.
      return {};
    }
  }

  Future<void> _save(Map<String, String> values) async {
    try {
      final file = await _file();
      if (values.isEmpty) {
        if (file.existsSync()) await file.delete();
        return;
      }
      await file.writeAsString(jsonEncode(values), flush: true);
    } catch (_) {
      // Best-effort: failing to persist must never fail a live request.
    }
  }

  @override
  Future<String?> read(String key) async => (await _load())[key];

  @override
  Future<void> write(String key, String value) async {
    final values = await _load();
    values[key] = value;
    await _save(values);
  }

  @override
  Future<void> remove(String key) async {
    final values = await _load();
    if (values.remove(key) != null) await _save(values);
  }

  @override
  Future<void> clear() async => _save(const {});
}

/// The last value the server returned for a screen, plus when it arrived.
class LastGoodSnapshot {
  const LastGoodSnapshot({required this.data, required this.savedAt});

  final Object? data;
  final DateTime savedAt;
}

/// Offline-first storage for "the last thing that was true".
///
/// DESIGN.md §28 requires the last verified booking state to stay visible when
/// the connection drops, marked with its update time and flagged as possibly
/// out of date. This is the mechanism: a controller writes on every successful
/// read and falls back to this on a network failure.
///
/// Two properties matter more than the storage itself:
///
/// * **Corruption is never fatal.** Every failure path — unreadable file,
///   truncated JSON, an envelope from a future version — returns null so the
///   screen falls back to the normal offline state instead of crashing.
/// * **Snapshots are scoped to the signed-in account.** A device shared by two
///   accounts must never show the first customer's bookings to the second, so
///   the user id is part of the key and a signed-out session reads nothing.
class LastGoodCache {
  LastGoodCache({
    required SnapshotStore store,
    String? Function()? scope,
    DateTime Function()? clock,
  }) : _store = store,
       _scope = scope,
       _clock = clock ?? DateTime.now;

  /// Bumped when the envelope changes so an old file is discarded, not
  /// misread. Included in the stored key, so no migration is needed.
  static const envelopeVersion = 1;

  final SnapshotStore _store;
  final String? Function()? _scope;
  final DateTime Function() _clock;

  String? _key(String name) {
    final user = _scope?.call();
    // Signed out: no account owns a snapshot, so nothing is read or written.
    if (user == null || user.isEmpty) return null;
    return '$name.v$envelopeVersion.$user';
  }

  Future<LastGoodSnapshot?> read(String name) async {
    final key = _key(name);
    if (key == null) return null;
    try {
      final raw = await _store.read(key);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      if (decoded['v'] != envelopeVersion) return null;
      final savedAt = DateTime.tryParse(decoded['savedAt']?.toString() ?? '');
      if (savedAt == null) return null;
      if (!decoded.containsKey('data')) return null;
      return LastGoodSnapshot(data: decoded['data'], savedAt: savedAt);
    } catch (_) {
      return null;
    }
  }

  Future<void> write(String name, Object? data) async {
    final key = _key(name);
    if (key == null) return;
    try {
      await _store.write(
        key,
        jsonEncode({
          'v': envelopeVersion,
          'savedAt': _clock().toUtc().toIso8601String(),
          'data': data,
        }),
      );
    } catch (_) {
      // Best-effort. A cache that cannot be written must not fail a request
      // that already succeeded.
    }
  }

  Future<void> remove(String name) async {
    final key = _key(name);
    if (key == null) return;
    try {
      await _store.remove(key);
    } catch (_) {}
  }

  /// Wipes every snapshot. Called on sign-out.
  Future<void> clear() async {
    try {
      await _store.clear();
    } catch (_) {}
  }
}

/// Plain-language age of a snapshot, for the "updated Xm ago" stamp.
///
/// Deliberately coarse: at the resolution a person can hold in their head, and
/// never negative, so a device clock that moved backwards cannot claim data is
/// from the future.
String offlineSnapshotAgeLabel(DateTime savedAt, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  final gap = reference.difference(savedAt);
  if (gap.isNegative || gap.inMinutes < 1) return 'just now';
  if (gap.inMinutes < 60) return '${gap.inMinutes}m ago';
  if (gap.inHours < 24) return '${gap.inHours}h ago';
  return '${gap.inDays}d ago';
}

/// The platform's best available sink: a real file on mobile and desktop,
/// memory on web (there is no app-private documents directory there).
///
/// Kept as a factory so nothing above it depends on `dart:io`, which cannot be
/// imported on web.
SnapshotStore createDefaultSnapshotStore() => kIsWeb
    ? MemorySnapshotStore()
    : const FileSnapshotStore();