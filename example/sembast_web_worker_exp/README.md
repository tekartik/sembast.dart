# Sembast Web worker example

You have to build the app and the worker.

To build:
```shell
webdev build -o web:build
```

To serve the built result:
```shell
cd build
dart pub global activate dhttpd
dart pub global run dhttpd
```

And go to the URL: http://localhost:8080