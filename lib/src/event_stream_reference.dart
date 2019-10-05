import 'package:optional/optional.dart';

import 'event_stream.dart';

class EventStreamReference<E> {
  EventStreamReference() {
    // TODO implementare
    throw UnimplementedError();
  }

  // TODO implementare
  EventStream<E> get stream => throw UnimplementedError();

  // TODO implementare
  bool get isLinked => throw UnimplementedError();

  // TODO implementare
  void link(EventStream<E> stream) => throw UnimplementedError();
}

class OptionalEventStreamReference<E>
    extends EventStreamReference<Optional<E>> {
  OptionalEventStreamReference() {
    // TODO implementare
    throw UnimplementedError();
  }

  @override
  OptionalEventStream<E> get stream => super.stream;

  @override
  void link(covariant OptionalEventStream<E> stream) => super.link(stream);
}
