import 'dart:collection';

List<T> toUnmodifiableList<T>(Iterable<T> elements) =>
    elements is UnmodifiableListView<T>
        ? elements
        : UnmodifiableListView<T>(elements);
