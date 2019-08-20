import 'dart:async';

import 'package:meta/meta.dart';

import 'internal_util.dart';
import 'typedef.dart';

void assertEmptyBroadcastStreamSubscribers() {
  assert(_broadcastStreamSubscribers.isEmpty,
      'Not canceled broadcast stream subscribers: ${_broadcastStreamSubscribers.length}');
}

class ConstantBroadcastStream<T> extends UnbindableBroadcastStream<T> {
  ConstantBroadcastStream(T initData)
      : super(initData: initData, keepLastData: true);
}

class NeverBroadcastStream<T> extends UnbindableBroadcastStream<T> {
  NeverBroadcastStream() : super(keepLastData: false);
}

class SinkBroadcastStream<T> extends UnbindableBroadcastStream<T> {
  SinkBroadcastStream({@required bool keepLastData, T initData})
      : super(initData: initData, keepLastData: keepLastData);

  bool get isClosed => _isClosed;

  Future<void> close() => _close();

  void send(T data) => _add(data);

  void sendError(error, [StackTrace stackTrace]) =>
      _addError(error, stackTrace);
}

class DistinctBroadcastStream<T> extends SingleForwardingBroadcastStream<T> {
  final Equalizer<T> _distinctEquals;

  DistinctBroadcastStream(BroadcastStream<T> stream,
      {@required bool keepLastData, Equalizer<T> distinctEquals})
      : _distinctEquals = distinctEquals,
        super(
          stream,
          keepLastData: keepLastData,
          initData: keepLastData ? stream.lastData : null,
        );

  @override
  void _onData(T data) {
    if ((_distinctEquals != null && !_distinctEquals(data, lastData)) ||
        (_distinctEquals == null && data != lastData)) {
      super._onData(data);
    }
  }
}

class FromBroadcastStream<T> extends SingleForwardingBroadcastStream<T> {
  FromBroadcastStream(
    Stream<T> stream, {
    @required bool keepLastData,
    T initData,
  }) : super(stream, initData: initData, keepLastData: keepLastData);
}

class ReferenceBroadcastStream<T> extends SingleForwardingBroadcastStream<T> {
  ReferenceBroadcastStream({
    @required bool keepLastData,
    T initData,
  }) : super.defer(initData: initData, keepLastData: keepLastData);

  bool get isLinked => _stream != null;

  void link(BroadcastStream<T> stream) => _broadcast(stream);
}

class StartWithBroadcastStream<T> extends SingleForwardingBroadcastStream<T> {
  final T _startData;

  StartWithBroadcastStream(
    Stream<T> stream, {
    T startData,
  })  : _startData = startData,
        super(stream, keepLastData: false);

  @override
  void _bind() {
    _add(_startData);

    super._bind();
  }
}

class SwitchBroadcastStream<MT, T>
    extends SingleBindableBroadcastStream<MT, T> {
  final BroadcastStream<T> Function(MT mainEvent) _streamMapper;
  bool _isMainClosed = false;
  bool _isElementClosed = false;
  StreamSubscription<T> _elementStreamSubscription;

  SwitchBroadcastStream(BroadcastStream<MT> mainStream, this._streamMapper,
      {@required bool keepLastData})
      : super(
          mainStream,
          keepLastData: keepLastData,
          initData:
              keepLastData ? _streamMapper(mainStream.lastData).lastData : null,
        );

  BroadcastStream<MT> get _mainStream => _stream;

  @override
  void _bind() {
    super._bind();

    _listenData(_mainStream.lastData);
  }

  @override
  Future<void> _unbind() async {
    await _cancelData();

    await super._unbind();
  }

  @override
  void _onData(MT data) {
    _cancelData();

    _listenData(data);
  }

  @override
  void _onDone() {
    _isMainClosed = true;

    if (_isElementClosed || _elementStreamSubscription == null) {
      _close();
    }
  }

  void _listenData(MT data) {
    final stream = _streamMapper(data);

    final subscription = stream.listen(
      _add,
      onError: _addError,
      onDone: () {
        _isElementClosed = true;

        if (_isMainClosed) {
          _close();
        }
      },
    );

    _elementStreamSubscription = BroadcastStreamSubscription<T>(subscription);
  }

  Future<void> _cancelData() async {
    await _elementStreamSubscription?.cancel();
  }
}

class CombineBroadcastStream<T>
    extends MultiBindableBroadcastStream<dynamic, T> {
  final Combiners<T> _combiner;

  Future<void> _collectFuture;
  T _lastResult;

  factory CombineBroadcastStream(
      Iterable<BroadcastStream> streams, Combiners<T> combiner) {
    final streamList = toUnmodifiableList(streams);

    return CombineBroadcastStream._(streamList, combiner);
  }

  CombineBroadcastStream._(List<BroadcastStream> streams, this._combiner)
      : super(streams,
            keepLastData: true,
            initData: _combineLastData<T>(streams, _combiner));

  static _combineLastData<T>(
          List<BroadcastStream> streams, Combiners<T> combiner) =>
      combiner(streams.map((stream) => stream.lastData));

  @override
  void _onData(int index, data) {
    _lastResult = _combineLastData<T>(_streams, _combiner);

    if (_collectFuture == null) {
      _collectFuture = Future<void>.microtask(() {
        _add(_lastResult);

        _lastResult = null;
        _collectFuture = null;
      });
    }
  }
}

class MergeBroadcastStream<T> extends MultiBindableBroadcastStream<T, T> {
  final Merger<T> _merger;

  Future<void> _collectFuture;
  int _lastResultIndex;
  T _lastResult;

  factory MergeBroadcastStream(Iterable<BroadcastStream<T>> streams,
      [Merger<T> merger]) {
    final streamList = toUnmodifiableList(streams);

    return MergeBroadcastStream._(streamList, merger ?? (left, right) => left);
  }

  MergeBroadcastStream._(List<BroadcastStream<T>> streams, this._merger)
      : super(streams, keepLastData: false);

  @override
  void _onData(int index, data) {
    if (_collectFuture == null) {
      _lastResultIndex = index;
      _lastResult = data;

      _collectFuture = Future<void>.microtask(() {
        _add(_lastResult);

        _lastResultIndex = null;
        _lastResult = null;
        _collectFuture = null;
      });
    } else if (index >= _lastResultIndex) {
      _lastResult = _merger(_lastResult, data);
    } else {
      _lastResultIndex = index;
      _lastResult = _merger(data, _lastResult);
    }
  }
}

class SnapshotBroadcastStream<E, V, T>
    extends MultiBindableBroadcastStream<dynamic, T> {
  final Combiner2<E, V, T> _combiner;

  SnapshotBroadcastStream(
    BroadcastStream<E> triggerStream,
    BroadcastStream<V> stateStream,
    this._combiner,
  ) : super([triggerStream, stateStream], keepLastData: false);

  BroadcastStream<V> get _stateStream => _streams[1];

  @override
  void _onData(int index, data) {
    if (index == 0) {
      _add(_combiner(data, _stateStream.lastData));
    }
  }
}

abstract class SingleForwardingBroadcastStream<T>
    extends SingleBindableBroadcastStream<T, T> {
  SingleForwardingBroadcastStream(
    Stream<T> stream, {
    @required bool keepLastData,
    T initData,
  }) : super(stream, initData: initData, keepLastData: keepLastData);

  SingleForwardingBroadcastStream.defer({
    @required bool keepLastData,
    T initData,
  }) : super.defer(initData: initData, keepLastData: keepLastData);

  @override
  void _onData(T data) => _add(data);
}

abstract class UnbindableBroadcastStream<T> extends SourceBroadcastStream<T> {
  UnbindableBroadcastStream({
    @required bool keepLastData,
    T initData,
  }) : super(
            initData: initData,
            isSyncStream: false,
            keepLastData: keepLastData);

  @override
  bool get _isBindable => false;

  @override
  void _bind() {}

  @override
  Future<void> _unbind() async {}
}

abstract class MultiBindableBroadcastStream<S, T>
    extends SourceBroadcastStream<T> {
  final List<Stream<S>> _streams;

  List<StreamSubscription<S>> _streamSubscriptions;

  int _onDoneCount = 0;

  MultiBindableBroadcastStream(
    Iterable<Stream<S>> streams, {
    @required bool keepLastData,
    T initData,
  })  : _streams = toUnmodifiableList(streams),
        super(
            initData: initData, isSyncStream: true, keepLastData: keepLastData);

  @override
  bool get _isBindable => true;

  @override
  void _bind() {
    _streamSubscriptions = List<StreamSubscription<S>>.generate(
        _streams.length,
        (index) => _streams[index].listen((data) => _onData(index, data),
            onError: (error, stackTrace) => _onError(index, error, stackTrace),
            onDone: () => _onDone(index)));
  }

  @override
  Future<void> _unbind() async {
    await Future.wait(_streamSubscriptions
        .map((subscription) => subscription.cancel())
        .where((future) => future != null));

    _streamSubscriptions.fillRange(0, _streamSubscriptions.length, null);
  }

  void _onData(int index, S data);

  void _onError(int index, dynamic error, StackTrace stackTrace) =>
      _addError(error, stackTrace);

  void _onDone(int index) {
    _onDoneCount++;

    if (_onDoneCount == _streams.length) {
      _close();
    }
  }
}

abstract class SingleBindableBroadcastStream<S, T>
    extends SourceBroadcastStream<T> {
  Stream<S> _stream;

  StreamSubscription<S> _streamSubscription;

  SingleBindableBroadcastStream(
    Stream<S> stream, {
    @required bool keepLastData,
    T initData,
  }) : super(
            initData: initData,
            isSyncStream: true,
            keepLastData: keepLastData) {
    _broadcast(stream);
  }

  SingleBindableBroadcastStream.defer({
    @required bool keepLastData,
    T initData,
  }) : super(
            initData: initData, isSyncStream: true, keepLastData: keepLastData);

  void _broadcast(Stream<S> stream) {
    if (_stream != null) {
      throw ArgumentError('Stream to broadcast already specified');
    } else if (!stream.isBroadcast) {
      throw ArgumentError('Stream is not broadcast');
    }

    _stream = stream;

    _listen();
  }

  void _onData(S data);

  void _onError(dynamic error, StackTrace stackTrace) =>
      _addError(error, stackTrace);

  void _onDone() => _close();

  @override
  bool get _isBindable => _stream != null;

  @override
  void _bind() {
    _streamSubscription =
        _stream.listen(_onData, onError: _onError, onDone: _onDone);
  }

  @override
  Future<void> _unbind() async {
    await _streamSubscription.cancel();
    _streamSubscription = null;
  }
}

abstract class SourceBroadcastStream<T> extends BroadcastStream<T> {
  StreamController<T> _streamController;

  bool _hasListeners = false;
  bool _hasPendingData = false;
  bool _isBound = false;
  int _subscriptionCount = 0;
  int _cyclicCount = 0;

  SourceBroadcastStream({
    @required bool isSyncStream,
    @required bool keepLastData,
    T initData,
  }) : super(keepLastData: keepLastData, initData: initData) {
    _streamController = StreamController<T>.broadcast(
      sync: isSyncStream,
      onListen: _onListen,
      onCancel: _onCancel,
    );
  }

  @override
  StreamSubscription<T> listen(void Function(T data) onData,
      {Function onError, void Function() onDone, bool cancelOnError}) {
    _onSubscribe();

    final subscription = _streamController.stream.listen(onData,
        onError: onError, onDone: onDone, cancelOnError: cancelOnError);

    return BroadcastStreamSubscription<T>(subscription, _onUnsubscribe);
  }

  bool get _isBindable;

  void _add(T data) {
    if (keepLastData) {
      _lastData = data;
    }

    if (_hasListeners) {
      _streamController.add(data);
    } else if (keepLastData) {
      _hasPendingData = true;
    }
  }

  void _addError(error, [StackTrace stackTrace]) {
    _streamController.addError(error, stackTrace);
  }

  bool get _isClosed => _streamController.isClosed;

  Future<void> _close() => _streamController.close();

  void _bind();

  Future<void> _unbind();

  void _onListen() {
    _hasListeners = true;

    _listen();
  }

  Future<void> _onCancel() async {
    _hasListeners = false;

    await _cancel();
  }

  void _onSubscribe() {
    _subscriptionCount++;
  }

  Future<void> _onUnsubscribe() async {
    _subscriptionCount--;

    if (_subscriptionCount == _cyclicCount) {
      await _cancel();
    }
  }

  bool get _canBind => !_isBound && _isBindable;

  bool get _canUnbind => _isBound;

  void _listen() {
    if (_hasListeners) {
      if (_canBind) {
        var startCount = _subscriptionCount;

        _bind();

        _isBound = true;
        _cyclicCount = _subscriptionCount - startCount;
      }

      if (_hasPendingData) {
        _hasPendingData = false;
        _streamController.add(_lastData);
      }
    }
  }

  Future<void> _cancel() async {
    if (_canUnbind) {
      await _unbind();

      _isBound = false;
      _cyclicCount = 0;
    }
  }
}

class BroadcastFactoryStream<T> extends BroadcastStream<T> {
  final BroadcastStream<T> Function() _broadcastStreamFactory;

  BroadcastFactoryStream(BroadcastStream<T> Function() broadcastStreamFactory)
      : _broadcastStreamFactory = broadcastStreamFactory,
        super(keepLastData: false);

  @override
  StreamSubscription<T> listen(void Function(T data) onData,
          {Function onError, void Function() onDone, bool cancelOnError}) =>
      _broadcastStreamFactory().listen(onData,
          onError: onError, onDone: onDone, cancelOnError: cancelOnError);
}

abstract class BroadcastStream<T> extends Stream<T> {
  final bool keepLastData;
  T _lastData;

  BroadcastStream({
    @required this.keepLastData,
    T initData,
  }) : _lastData = initData {
    if (!keepLastData && _lastData != null) {
      throw UnsupportedError('Last data');
    }
  }

  @override
  bool get isBroadcast => true;

  T get lastData =>
      keepLastData ? _lastData : throw UnsupportedError('Last data');
}

class BroadcastStreamSubscription<T> extends StreamSubscription<T> {
  static int _globalTrackingId = 0;
  static int _trackingId = _globalTrackingId++;

  final StreamSubscription<T> _subscription;
  final Future<void> Function() _unsubscriber;

  BroadcastStreamSubscription(this._subscription, [this._unsubscriber]) {
    _broadcastStreamSubscribers.add(_trackingId);
  }

  @override
  Future cancel() async {
    _broadcastStreamSubscribers.remove(_trackingId);

    if (_unsubscriber != null) {
      await _unsubscriber();
    }

    await _subscription.cancel();
  }

  @override
  Future<E> asFuture<E>([E futureValue]) =>
      _subscription.asFuture<E>(futureValue);

  @override
  bool get isPaused => _subscription.isPaused;

  @override
  void onData(void Function(T data) handleData) =>
      _subscription.onData(handleData);

  @override
  void onError(Function handleError) => _subscription.onError(handleError);

  @override
  void onDone(void Function() handleDone) => _subscription.onDone(handleDone);

  @override
  void pause([Future resumeSignal]) => _subscription.pause(resumeSignal);

  @override
  void resume() => _subscription.resume();
}

final Set<int> _broadcastStreamSubscribers = {};
