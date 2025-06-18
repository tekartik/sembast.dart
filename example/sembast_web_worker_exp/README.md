# SDB Web worker example

You have to build the app and the worker.

To build:
```shell
webdev build -o example:build
```

To serve the built result:
```shell
cd build
dart pub global activate dhttpd
dart pub global run dhttpd
```
