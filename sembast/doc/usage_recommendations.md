## Size

Due to its design, sembast is suitable for small to medium databases and will significantly degrade in performance for
big databases (especially load time, a 500K records database could take a minute to open).
There are no hard limits but here are opinionated suggestions:
- sembast io: <100K records, <100Mb
- sembast_web: <30K records, size limited by any indexedDB limitation (depending on the browser)

While binary data is supported you should avoid storing big records and consider saving images and big blob in
separate files and only keeping a reference in the database.

## Keep your records small

It is better to have 10 000 records of 1 KB than a 10 MB record! Big records might imply more UI janks.

## Use transactions

For performance reason it is important to use transactions as soon as you have more than one write to perform.

One recommendation is to limit your transactions:
- 100 add/updates/delete
- If you are doing more than 10000 writes, you could split in 10 transactions of 1000 writes

## Bulk insert

There are 2 ways to do bulk insert:
- use [`store.addAll`](https://pub.dev/documentation/sembast/latest/sembast/SembastStoreRefExtension/addAll.html)
- use a [transaction](https://github.com/tekartik/sembast.dart/blob/master/sembast/doc/transactions.md)

## Optimization

### Disable sembast cooperator

sembast has a weird cooperator concept to let other async task run
even during heavy operations. This is mainly to allow flutter app running without glitches.

In some scenario, you can disable sembast cooperator.
If you don't need such feature (pure io application), you can call:

```dart
disableSembastCooperator();
```

In flutter application, if you decide to open the database during the splash screen before
calling `runApp`, you can temporarily disable it:

```dart
Future<void> main() async {
  // disable cooperator during splash screen
  disableSembastCooperator();
  
  // open you database

  // renable cooperator once open
  enableSembastCooperator();
  runApp(MyApp());
}
```