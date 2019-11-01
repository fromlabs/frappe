import 'dart:async';

import 'package:frappe/frappe.dart';
import 'package:optional/optional.dart';

class Point {
  final int x;
  final int y;

  Point(this.x, this.y);
}

enum MouseEventType { DOWN, UP, MOVE }

class MouseEvent {
  final MouseEventType type;

  final Point point;

  MouseEvent(this.type, this.point);
}

abstract class Element {
  bool contains(Point point);

  Element translate(Point origin, Point point);
}

class Entry {
  final String id;
  final Element element;

  Entry(this.id, this.element);
}

abstract class Document {
  Optional<Entry> getByPoint(Point point);

  Document insert(String id, Element polygon);
}

abstract class DocumentListener {
  void documentUpdated(Document document);
}

abstract class Paradigm {
  void mouseEvent(MouseEvent event);

  Future<void> dispose();
}

class FrpParadigm implements Paradigm {
  final EventStreamSink<MouseEvent> mouseEventStreamSink = EventStreamSink();
  ListenSubscription documentUpdateSubscription;

  FrpParadigm(Document initDocument, DocumentListener documentListener) {
    // TODO sistemare ValueStateReference(initDocument);
    ValueStateLink<Document> documentStateReference =
        ValueStateLink();

    EventStream<Document> idleStream = EventStream.never();

    EventStream<EventStream<Document>> startDragStream = mouseEventStreamSink
        .stream
        .where((event) => event.type == MouseEventType.DOWN)
        .snapshot<Document, Optional<EventStream<Document>>>(
            documentStateReference.state, (startEvent, document) => document.getByPoint(startEvent.point).map((entry) =>
              mouseEventStreamSink.stream
                  .where((event) => event.type == MouseEventType.MOVE)
                  .snapshot<Document, Document>(
                      documentStateReference.state,
                      (dragEvent, document) => document.insert(
                          entry.id,
                          entry.element
                              .translate(startEvent.point, dragEvent.point)))))
        .asOptional<EventStream<Document>>()
        .mapWhereOptional();

    EventStream<EventStream<Document>> endDragStream = mouseEventStreamSink
        .stream
        .where((event) => event.type == MouseEventType.UP)
        .mapTo(idleStream);

    EventStream<Document> documentUpdatedStream = ValueState.switchStream(
        startDragStream.orElse(endDragStream).toState(idleStream));

    documentUpdateSubscription = documentUpdatedStream
        .listen((document) => documentListener.documentUpdated(document));
  }

  @override
  void mouseEvent(MouseEvent event) => mouseEventStreamSink.send(event);

  @override
  Future<void> dispose() async {
    await documentUpdateSubscription.cancel();

    await mouseEventStreamSink.close();
  }
}
