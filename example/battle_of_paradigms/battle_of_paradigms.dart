import 'dart:async';

import 'package:frappe/frappe.dart';

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
  Entry? getByPoint(Point point);

  Document insert(String id, Element polygon);
}

abstract class DocumentListener {
  void documentUpdated(Document document);
}

abstract class Paradigm {
  void mouseEvent(MouseEvent event);

  FutureOr<void> dispose();
}

class FrpParadigm implements Paradigm {
  final EventStreamSink<MouseEvent> mouseEventStreamSink = EventStreamSink();
  ListenSubscription? documentUpdateSubscription;

  FrpParadigm(Document initDocument, DocumentListener documentListener) {
    // TODO sistemare ValueStateReference(initDocument);
    final documentStateReference = ValueStateLink<Document>();

    final idleStream = EventStream<Document>.never();

    final startDragStream = mouseEventStreamSink.stream
        .where((event) => event.type == MouseEventType.DOWN)
        .snapshot<Document, EventStream<Document>?>(
            documentStateReference.state, (startEvent, document) {
      final entry = document.getByPoint(startEvent.point);

      return entry != null
          ? mouseEventStreamSink.stream
              .where((event) => event.type == MouseEventType.MOVE)
              .snapshot<Document, Document>(
                  documentStateReference.state,
                  (dragEvent, document) => document.insert(
                      entry.id,
                      entry.element
                          .translate(startEvent.point, dragEvent.point)))
          : null;
    }).whereType<EventStream<Document>>();

    final endDragStream = mouseEventStreamSink.stream
        .where((event) => event.type == MouseEventType.UP)
        .mapTo(idleStream);

    final documentUpdatedStream = ValueState.switchStream(
        startDragStream.orElse(endDragStream).toState(idleStream));

    documentUpdateSubscription = documentUpdatedStream
        .listen((document) => documentListener.documentUpdated(document));
  }

  @override
  void mouseEvent(MouseEvent event) => mouseEventStreamSink.send(event);

  @override
  void dispose() {
    documentUpdateSubscription?.cancel();

    mouseEventStreamSink.close();
  }
}
