// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'model.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$Inputs extends Inputs {
  @override
  final ValueState<double> calibrationState;
  @override
  final EventStream<Unit> clearSaleStream;
  @override
  final EventStream<int> fuelPulsesStream;
  @override
  final EventStream<NumericKey> keypadStream;
  @override
  final EventStream<UpDown> nozzle1Stream;
  @override
  final EventStream<UpDown> nozzle2Stream;
  @override
  final EventStream<UpDown> nozzle3Stream;
  @override
  final ValueState<double> price1State;
  @override
  final ValueState<double> price2State;
  @override
  final ValueState<double> price3State;

  factory _$Inputs([void Function(InputsBuilder) updates]) =>
      (new InputsBuilder()..update(updates)).build();

  _$Inputs._(
      {this.calibrationState,
      this.clearSaleStream,
      this.fuelPulsesStream,
      this.keypadStream,
      this.nozzle1Stream,
      this.nozzle2Stream,
      this.nozzle3Stream,
      this.price1State,
      this.price2State,
      this.price3State})
      : super._() {
    if (calibrationState == null) {
      throw new BuiltValueNullFieldError('Inputs', 'calibrationState');
    }
    if (clearSaleStream == null) {
      throw new BuiltValueNullFieldError('Inputs', 'clearSaleStream');
    }
    if (fuelPulsesStream == null) {
      throw new BuiltValueNullFieldError('Inputs', 'fuelPulsesStream');
    }
    if (keypadStream == null) {
      throw new BuiltValueNullFieldError('Inputs', 'keypadStream');
    }
    if (nozzle1Stream == null) {
      throw new BuiltValueNullFieldError('Inputs', 'nozzle1Stream');
    }
    if (nozzle2Stream == null) {
      throw new BuiltValueNullFieldError('Inputs', 'nozzle2Stream');
    }
    if (nozzle3Stream == null) {
      throw new BuiltValueNullFieldError('Inputs', 'nozzle3Stream');
    }
    if (price1State == null) {
      throw new BuiltValueNullFieldError('Inputs', 'price1State');
    }
    if (price2State == null) {
      throw new BuiltValueNullFieldError('Inputs', 'price2State');
    }
    if (price3State == null) {
      throw new BuiltValueNullFieldError('Inputs', 'price3State');
    }
  }

  @override
  Inputs rebuild(void Function(InputsBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  InputsBuilder toBuilder() => new InputsBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is Inputs &&
        calibrationState == other.calibrationState &&
        clearSaleStream == other.clearSaleStream &&
        fuelPulsesStream == other.fuelPulsesStream &&
        keypadStream == other.keypadStream &&
        nozzle1Stream == other.nozzle1Stream &&
        nozzle2Stream == other.nozzle2Stream &&
        nozzle3Stream == other.nozzle3Stream &&
        price1State == other.price1State &&
        price2State == other.price2State &&
        price3State == other.price3State;
  }

  @override
  int get hashCode {
    return $jf($jc(
        $jc(
            $jc(
                $jc(
                    $jc(
                        $jc(
                            $jc(
                                $jc(
                                    $jc($jc(0, calibrationState.hashCode),
                                        clearSaleStream.hashCode),
                                    fuelPulsesStream.hashCode),
                                keypadStream.hashCode),
                            nozzle1Stream.hashCode),
                        nozzle2Stream.hashCode),
                    nozzle3Stream.hashCode),
                price1State.hashCode),
            price2State.hashCode),
        price3State.hashCode));
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper('Inputs')
          ..add('calibrationState', calibrationState)
          ..add('clearSaleStream', clearSaleStream)
          ..add('fuelPulsesStream', fuelPulsesStream)
          ..add('keypadStream', keypadStream)
          ..add('nozzle1Stream', nozzle1Stream)
          ..add('nozzle2Stream', nozzle2Stream)
          ..add('nozzle3Stream', nozzle3Stream)
          ..add('price1State', price1State)
          ..add('price2State', price2State)
          ..add('price3State', price3State))
        .toString();
  }
}

class InputsBuilder implements Builder<Inputs, InputsBuilder> {
  _$Inputs _$v;

  ValueState<double> _calibrationState;
  ValueState<double> get calibrationState => _$this._calibrationState;
  set calibrationState(ValueState<double> calibrationState) =>
      _$this._calibrationState = calibrationState;

  EventStream<Unit> _clearSaleStream;
  EventStream<Unit> get clearSaleStream => _$this._clearSaleStream;
  set clearSaleStream(EventStream<Unit> clearSaleStream) =>
      _$this._clearSaleStream = clearSaleStream;

  EventStream<int> _fuelPulsesStream;
  EventStream<int> get fuelPulsesStream => _$this._fuelPulsesStream;
  set fuelPulsesStream(EventStream<int> fuelPulsesStream) =>
      _$this._fuelPulsesStream = fuelPulsesStream;

  EventStream<NumericKey> _keypadStream;
  EventStream<NumericKey> get keypadStream => _$this._keypadStream;
  set keypadStream(EventStream<NumericKey> keypadStream) =>
      _$this._keypadStream = keypadStream;

  EventStream<UpDown> _nozzle1Stream;
  EventStream<UpDown> get nozzle1Stream => _$this._nozzle1Stream;
  set nozzle1Stream(EventStream<UpDown> nozzle1Stream) =>
      _$this._nozzle1Stream = nozzle1Stream;

  EventStream<UpDown> _nozzle2Stream;
  EventStream<UpDown> get nozzle2Stream => _$this._nozzle2Stream;
  set nozzle2Stream(EventStream<UpDown> nozzle2Stream) =>
      _$this._nozzle2Stream = nozzle2Stream;

  EventStream<UpDown> _nozzle3Stream;
  EventStream<UpDown> get nozzle3Stream => _$this._nozzle3Stream;
  set nozzle3Stream(EventStream<UpDown> nozzle3Stream) =>
      _$this._nozzle3Stream = nozzle3Stream;

  ValueState<double> _price1State;
  ValueState<double> get price1State => _$this._price1State;
  set price1State(ValueState<double> price1State) =>
      _$this._price1State = price1State;

  ValueState<double> _price2State;
  ValueState<double> get price2State => _$this._price2State;
  set price2State(ValueState<double> price2State) =>
      _$this._price2State = price2State;

  ValueState<double> _price3State;
  ValueState<double> get price3State => _$this._price3State;
  set price3State(ValueState<double> price3State) =>
      _$this._price3State = price3State;

  InputsBuilder();

  InputsBuilder get _$this {
    if (_$v != null) {
      _calibrationState = _$v.calibrationState;
      _clearSaleStream = _$v.clearSaleStream;
      _fuelPulsesStream = _$v.fuelPulsesStream;
      _keypadStream = _$v.keypadStream;
      _nozzle1Stream = _$v.nozzle1Stream;
      _nozzle2Stream = _$v.nozzle2Stream;
      _nozzle3Stream = _$v.nozzle3Stream;
      _price1State = _$v.price1State;
      _price2State = _$v.price2State;
      _price3State = _$v.price3State;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(Inputs other) {
    if (other == null) {
      throw new ArgumentError.notNull('other');
    }
    _$v = other as _$Inputs;
  }

  @override
  void update(void Function(InputsBuilder) updates) {
    if (updates != null) updates(this);
  }

  @override
  _$Inputs build() {
    final _$result = _$v ??
        new _$Inputs._(
            calibrationState: calibrationState,
            clearSaleStream: clearSaleStream,
            fuelPulsesStream: fuelPulsesStream,
            keypadStream: keypadStream,
            nozzle1Stream: nozzle1Stream,
            nozzle2Stream: nozzle2Stream,
            nozzle3Stream: nozzle3Stream,
            price1State: price1State,
            price2State: price2State,
            price3State: price3State);
    replace(_$result);
    return _$result;
  }
}

class _$Outputs extends Outputs {
  @override
  final EventStream<Unit> beepStream;
  @override
  final ValueState<Delivery> deliveryState;
  @override
  final ValueState<String> presetLcdState;
  @override
  final ValueState<String> priceLcd1State;
  @override
  final ValueState<String> priceLcd2State;
  @override
  final ValueState<String> priceLcd3State;
  @override
  final EventStream<Sale> saleCompleteStream;
  @override
  final ValueState<String> saleCostLcdState;
  @override
  final ValueState<String> saleQuantityLcdState;

  factory _$Outputs([void Function(OutputsBuilder) updates]) =>
      (new OutputsBuilder()..update(updates)).build();

  _$Outputs._(
      {this.beepStream,
      this.deliveryState,
      this.presetLcdState,
      this.priceLcd1State,
      this.priceLcd2State,
      this.priceLcd3State,
      this.saleCompleteStream,
      this.saleCostLcdState,
      this.saleQuantityLcdState})
      : super._() {
    if (beepStream == null) {
      throw new BuiltValueNullFieldError('Outputs', 'beepStream');
    }
    if (deliveryState == null) {
      throw new BuiltValueNullFieldError('Outputs', 'deliveryState');
    }
    if (presetLcdState == null) {
      throw new BuiltValueNullFieldError('Outputs', 'presetLcdState');
    }
    if (priceLcd1State == null) {
      throw new BuiltValueNullFieldError('Outputs', 'priceLcd1State');
    }
    if (priceLcd2State == null) {
      throw new BuiltValueNullFieldError('Outputs', 'priceLcd2State');
    }
    if (priceLcd3State == null) {
      throw new BuiltValueNullFieldError('Outputs', 'priceLcd3State');
    }
    if (saleCompleteStream == null) {
      throw new BuiltValueNullFieldError('Outputs', 'saleCompleteStream');
    }
    if (saleCostLcdState == null) {
      throw new BuiltValueNullFieldError('Outputs', 'saleCostLcdState');
    }
    if (saleQuantityLcdState == null) {
      throw new BuiltValueNullFieldError('Outputs', 'saleQuantityLcdState');
    }
  }

  @override
  Outputs rebuild(void Function(OutputsBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  OutputsBuilder toBuilder() => new OutputsBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is Outputs &&
        beepStream == other.beepStream &&
        deliveryState == other.deliveryState &&
        presetLcdState == other.presetLcdState &&
        priceLcd1State == other.priceLcd1State &&
        priceLcd2State == other.priceLcd2State &&
        priceLcd3State == other.priceLcd3State &&
        saleCompleteStream == other.saleCompleteStream &&
        saleCostLcdState == other.saleCostLcdState &&
        saleQuantityLcdState == other.saleQuantityLcdState;
  }

  @override
  int get hashCode {
    return $jf($jc(
        $jc(
            $jc(
                $jc(
                    $jc(
                        $jc(
                            $jc(
                                $jc($jc(0, beepStream.hashCode),
                                    deliveryState.hashCode),
                                presetLcdState.hashCode),
                            priceLcd1State.hashCode),
                        priceLcd2State.hashCode),
                    priceLcd3State.hashCode),
                saleCompleteStream.hashCode),
            saleCostLcdState.hashCode),
        saleQuantityLcdState.hashCode));
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper('Outputs')
          ..add('beepStream', beepStream)
          ..add('deliveryState', deliveryState)
          ..add('presetLcdState', presetLcdState)
          ..add('priceLcd1State', priceLcd1State)
          ..add('priceLcd2State', priceLcd2State)
          ..add('priceLcd3State', priceLcd3State)
          ..add('saleCompleteStream', saleCompleteStream)
          ..add('saleCostLcdState', saleCostLcdState)
          ..add('saleQuantityLcdState', saleQuantityLcdState))
        .toString();
  }
}

class OutputsBuilder implements Builder<Outputs, OutputsBuilder> {
  _$Outputs _$v;

  EventStream<Unit> _beepStream;
  EventStream<Unit> get beepStream => _$this._beepStream;
  set beepStream(EventStream<Unit> beepStream) =>
      _$this._beepStream = beepStream;

  ValueState<Delivery> _deliveryState;
  ValueState<Delivery> get deliveryState => _$this._deliveryState;
  set deliveryState(ValueState<Delivery> deliveryState) =>
      _$this._deliveryState = deliveryState;

  ValueState<String> _presetLcdState;
  ValueState<String> get presetLcdState => _$this._presetLcdState;
  set presetLcdState(ValueState<String> presetLcdState) =>
      _$this._presetLcdState = presetLcdState;

  ValueState<String> _priceLcd1State;
  ValueState<String> get priceLcd1State => _$this._priceLcd1State;
  set priceLcd1State(ValueState<String> priceLcd1State) =>
      _$this._priceLcd1State = priceLcd1State;

  ValueState<String> _priceLcd2State;
  ValueState<String> get priceLcd2State => _$this._priceLcd2State;
  set priceLcd2State(ValueState<String> priceLcd2State) =>
      _$this._priceLcd2State = priceLcd2State;

  ValueState<String> _priceLcd3State;
  ValueState<String> get priceLcd3State => _$this._priceLcd3State;
  set priceLcd3State(ValueState<String> priceLcd3State) =>
      _$this._priceLcd3State = priceLcd3State;

  EventStream<Sale> _saleCompleteStream;
  EventStream<Sale> get saleCompleteStream => _$this._saleCompleteStream;
  set saleCompleteStream(EventStream<Sale> saleCompleteStream) =>
      _$this._saleCompleteStream = saleCompleteStream;

  ValueState<String> _saleCostLcdState;
  ValueState<String> get saleCostLcdState => _$this._saleCostLcdState;
  set saleCostLcdState(ValueState<String> saleCostLcdState) =>
      _$this._saleCostLcdState = saleCostLcdState;

  ValueState<String> _saleQuantityLcdState;
  ValueState<String> get saleQuantityLcdState => _$this._saleQuantityLcdState;
  set saleQuantityLcdState(ValueState<String> saleQuantityLcdState) =>
      _$this._saleQuantityLcdState = saleQuantityLcdState;

  OutputsBuilder();

  OutputsBuilder get _$this {
    if (_$v != null) {
      _beepStream = _$v.beepStream;
      _deliveryState = _$v.deliveryState;
      _presetLcdState = _$v.presetLcdState;
      _priceLcd1State = _$v.priceLcd1State;
      _priceLcd2State = _$v.priceLcd2State;
      _priceLcd3State = _$v.priceLcd3State;
      _saleCompleteStream = _$v.saleCompleteStream;
      _saleCostLcdState = _$v.saleCostLcdState;
      _saleQuantityLcdState = _$v.saleQuantityLcdState;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(Outputs other) {
    if (other == null) {
      throw new ArgumentError.notNull('other');
    }
    _$v = other as _$Outputs;
  }

  @override
  void update(void Function(OutputsBuilder) updates) {
    if (updates != null) updates(this);
  }

  @override
  _$Outputs build() {
    final _$result = _$v ??
        new _$Outputs._(
            beepStream: beepStream,
            deliveryState: deliveryState,
            presetLcdState: presetLcdState,
            priceLcd1State: priceLcd1State,
            priceLcd2State: priceLcd2State,
            priceLcd3State: priceLcd3State,
            saleCompleteStream: saleCompleteStream,
            saleCostLcdState: saleCostLcdState,
            saleQuantityLcdState: saleQuantityLcdState);
    replace(_$result);
    return _$result;
  }
}

class _$Sale extends Sale {
  @override
  final double cost;
  @override
  final Fuel fuel;
  @override
  final double price;
  @override
  final double quantity;

  factory _$Sale([void Function(SaleBuilder) updates]) =>
      (new SaleBuilder()..update(updates)).build();

  _$Sale._({this.cost, this.fuel, this.price, this.quantity}) : super._() {
    if (cost == null) {
      throw new BuiltValueNullFieldError('Sale', 'cost');
    }
    if (fuel == null) {
      throw new BuiltValueNullFieldError('Sale', 'fuel');
    }
    if (price == null) {
      throw new BuiltValueNullFieldError('Sale', 'price');
    }
    if (quantity == null) {
      throw new BuiltValueNullFieldError('Sale', 'quantity');
    }
  }

  @override
  Sale rebuild(void Function(SaleBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  SaleBuilder toBuilder() => new SaleBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is Sale &&
        cost == other.cost &&
        fuel == other.fuel &&
        price == other.price &&
        quantity == other.quantity;
  }

  @override
  int get hashCode {
    return $jf($jc(
        $jc($jc($jc(0, cost.hashCode), fuel.hashCode), price.hashCode),
        quantity.hashCode));
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper('Sale')
          ..add('cost', cost)
          ..add('fuel', fuel)
          ..add('price', price)
          ..add('quantity', quantity))
        .toString();
  }
}

class SaleBuilder implements Builder<Sale, SaleBuilder> {
  _$Sale _$v;

  double _cost;
  double get cost => _$this._cost;
  set cost(double cost) => _$this._cost = cost;

  Fuel _fuel;
  Fuel get fuel => _$this._fuel;
  set fuel(Fuel fuel) => _$this._fuel = fuel;

  double _price;
  double get price => _$this._price;
  set price(double price) => _$this._price = price;

  double _quantity;
  double get quantity => _$this._quantity;
  set quantity(double quantity) => _$this._quantity = quantity;

  SaleBuilder();

  SaleBuilder get _$this {
    if (_$v != null) {
      _cost = _$v.cost;
      _fuel = _$v.fuel;
      _price = _$v.price;
      _quantity = _$v.quantity;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(Sale other) {
    if (other == null) {
      throw new ArgumentError.notNull('other');
    }
    _$v = other as _$Sale;
  }

  @override
  void update(void Function(SaleBuilder) updates) {
    if (updates != null) updates(this);
  }

  @override
  _$Sale build() {
    final _$result = _$v ??
        new _$Sale._(cost: cost, fuel: fuel, price: price, quantity: quantity);
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: always_put_control_body_on_new_line,always_specify_types,annotate_overrides,avoid_annotating_with_dynamic,avoid_as,avoid_catches_without_on_clauses,avoid_returning_this,lines_longer_than_80_chars,omit_local_variable_types,prefer_expression_function_bodies,sort_constructors_first,test_types_in_equals,unnecessary_const,unnecessary_new
