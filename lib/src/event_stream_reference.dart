import 'package:optional/optional.dart';

import 'broadcast_stream.dart';
import 'event_stream.dart';

class EventStreamReference<E> {
  final EventStream<E> stream;

  EventStreamReference()
      : this._(createEventStreamFromBroadcastStream<E>(
            ReferenceBroadcastStream<E>(keepLastData: false)));

  EventStreamReference._(this.stream);

  bool get isLinked => _referenceStream.isLinked;

  void link(EventStream<E> stream) =>
      _referenceStream.link(stream.legacyStream);

  ReferenceBroadcastStream<E> get _referenceStream => stream.legacyStream;
}

class OptionalEventStreamReference<E>
    extends EventStreamReference<Optional<E>> {
  OptionalEventStreamReference()
      : super._(createOptionalEventStreamFromBroadcastStream<E>(
            ReferenceBroadcastStream<Optional<E>>(keepLastData: false)));

  @override
  OptionalEventStream<E> get stream => super.stream;

  @override
  void link(covariant OptionalEventStream<E> stream) => super.link(stream);
}
