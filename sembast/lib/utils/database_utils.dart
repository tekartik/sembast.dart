import 'package:sembast/sembast.dart';
import 'package:sembast/src/api/protected/database.dart';

/// Get the list of non empty store names.
Iterable<String> getNonEmptyStoreNames(Database database) =>
    (database as SembastDatabase).nonEmptyStoreNames;
