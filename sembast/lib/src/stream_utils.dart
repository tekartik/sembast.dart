import 'dart:async';

/// Join all streams into one. First emit when all values are received once.
Stream<List<T>> streamJoinAll<T>(List<Stream<T>> streams) {
  late StreamController<List<T>> controller;
  controller = StreamController<List<T>>(
    sync: true,
    onListen: () {
      var filled = streams.map((e) => false).toList();
      var done = streams.map((e) => false).toList();
      var values = streams.map<T?>((e) => null).toList();

      var allFilled = false;
      var subscriptions = <StreamSubscription>[];
      for (var i = 0; i < streams.length; i++) {
        var index = i;
        var stream = streams[i];
        subscriptions.add(
          stream.listen(
            (event) {
              if (!allFilled) {
                filled[index] = true;
                allFilled = filled.every((e) => e);
              }
              values[index] = event;
              if (allFilled) {
                controller.add(List<T>.from(values));
              }
            },
            onDone: () {
              done[index] = true;

              subscriptions[index].cancel();
              var allDone = done.every((e) => e);

              if (allDone) {
                controller.close();
              }
            },
          ),
        );
      }
      controller.onCancel = () {
        for (var subscription in subscriptions) {
          subscription.cancel();
        }
      };
    },
  );
  return controller.stream;
}
