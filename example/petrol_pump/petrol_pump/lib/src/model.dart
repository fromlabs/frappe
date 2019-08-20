import 'package:built_value/built_value.dart';
import 'package:frappe/frappe.dart';

part 'model.g.dart';

enum Delivery { off, slow1, fast1, slow2, fast2, slow3, fast3 }

enum Fuel { one, two, three }

enum NumericKey {
  zero,
  one,
  two,
  three,
  four,
  five,
  six,
  seven,
  eight,
  nine,
  clear
}

abstract class Inputs implements Built<Inputs, InputsBuilder> {
  factory Inputs([updates(InputsBuilder b)]) = _$Inputs;

  factory Inputs.fromDefault([updates(InputsBuilder b)]) => (InputsBuilder()
        ..nozzle1Stream = EventStream.never()
        ..nozzle2Stream = EventStream.never()
        ..nozzle3Stream = EventStream.never()
        ..keypadStream = EventStream.never()
        ..fuelPulsesStream = EventStream.never()
        ..calibrationState = ValueState.constant(0)
        ..price1State = ValueState.constant(0)
        ..price2State = ValueState.constant(0)
        ..price3State = ValueState.constant(0)
        ..clearSaleStream = EventStream.never()
        ..update(updates))
      .build();

  Inputs._();

  ValueState<double> get calibrationState;
  EventStream<Unit> get clearSaleStream;
  EventStream<int> get fuelPulsesStream;
  EventStream<NumericKey> get keypadStream;
  EventStream<UpDown> get nozzle1Stream;
  EventStream<UpDown> get nozzle2Stream;
  EventStream<UpDown> get nozzle3Stream;
  ValueState<double> get price1State;
  ValueState<double> get price2State;
  ValueState<double> get price3State;
}

abstract class Outputs implements Built<Outputs, OutputsBuilder> {
  factory Outputs([updates(OutputsBuilder b)]) = _$Outputs;

  factory Outputs.fromDefault([updates(OutputsBuilder b)]) => (OutputsBuilder()
        ..deliveryState = ValueState.constant(Delivery.off)
        ..presetLcdState = ValueState.constant('')
        ..saleCostLcdState = ValueState.constant('')
        ..saleQuantityLcdState = ValueState.constant('')
        ..priceLcd1State = ValueState.constant('')
        ..priceLcd2State = ValueState.constant('')
        ..priceLcd3State = ValueState.constant('')
        ..beepStream = EventStream.never()
        ..saleCompleteStream = EventStream.never()
        ..update(updates))
      .build();

  Outputs._();

  EventStream<Unit> get beepStream;
  ValueState<Delivery> get deliveryState;
  ValueState<String> get presetLcdState;
  ValueState<String> get priceLcd1State;
  ValueState<String> get priceLcd2State;
  ValueState<String> get priceLcd3State;
  EventStream<Sale> get saleCompleteStream;
  ValueState<String> get saleCostLcdState;
  ValueState<String> get saleQuantityLcdState;
}

abstract class Sale implements Built<Sale, SaleBuilder> {
  factory Sale([updates(SaleBuilder b)]) = _$Sale;

  Sale._();

  double get cost;
  Fuel get fuel;
  double get price;
  double get quantity;
}

enum UpDown { up, down }
