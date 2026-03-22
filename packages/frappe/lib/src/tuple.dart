/// An immutable pair of values.
final class Tuple2<A, B> {
  /// The first element.
  final A item1;

  /// The second element.
  final B item2;

  const Tuple2(this.item1, this.item2);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Tuple2 && item1 == other.item1 && item2 == other.item2;

  @override
  int get hashCode => Object.hash(item1, item2);

  @override
  String toString() => 'Tuple2($item1, $item2)';
}
