import 'package:meta/meta.dart';

/* 
Con i nodi dobbiamo gestire:
+ dipendenze per la valutazione (non cicliche altrimenti errore)
- riferimenti per la finalizzazione (anche cicliche)
- transazioni per la valutazione
*/

// riguarda solo l'evaluation dei nodi
abstract class Transaction {
  bool get isClosed;

  static T run<T>(T Function(Transaction) runner) {
    // TODO implementare
    return runner(null);
  }
}

abstract class Node<S> {
  final Transaction _transaction;

  final Map<dynamic, Node> _parentNodes = Map.identity();

  final Map<Node, Set> _childNodes = Map.identity();

  Node(Transaction transaction) : _transaction = transaction;

  void _linkParent(key, Node parent) {
    parent._checkCycle(this);

    _parentNodes[key] = parent;

    parent._linkChild(this, key);
  }

  void _unlinkParent(key) {
    final parent = _parentNodes.remove(key);

    if (parent != null) {
      parent._unlinkChild(this, key);
    }
  }

  void _linkChild(Node child, key) {
    _childNodes.putIfAbsent(child, () => Set.identity()).add(key);
  }

  void _unlinkChild(Node child, key) {
    final keys = _childNodes[child];

    if (keys != null) {
      keys.remove(key);

      if (keys.isEmpty) {
        _childNodes.remove(child);
      }
    }
  }

  void _checkCycle(Node ascendant) {
    if (ascendant != this) {
      for (final parent in _parentNodes.values) {
        parent._checkCycle(ascendant);
      }
    } else {
      throw ArgumentError('Cycle dependency');
    }
  }
}

class IndexedNode<S> extends Node<S> {
  final List<int> _parentKeys = [];
  int _id = 0;

  IndexedNode(Transaction transaction) : super(transaction);

  void link(Node parent, Transaction transaction) {
    _parentKeys.add(_id);

    _linkParent(_id, parent);

    _id++;
  }

  void unlink(int index, Transaction transaction) {
    int key = _parentKeys.removeAt(index);

    _unlinkParent(key);
  }
}

class NamedNode<S> extends Node<S> {
  NamedNode(Transaction transaction) : super(transaction);

  void link(key, Node parent, Transaction transaction) {
    _unlinkParent(key);

    _linkParent(key, parent);
  }

  void unlink(key, Transaction transaction) {
    _unlinkParent(key);
  }
}
