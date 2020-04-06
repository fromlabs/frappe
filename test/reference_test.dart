import 'package:frappe/src/reference.dart';
import 'package:test/test.dart';

class NodeReferenceable extends Referenceable {
  final String id;

  NodeReferenceable(this.id);

  @override
  String toString() => '$id';
}

void main() {
  test('Reference test 01', () {
    final n1 = NodeReferenceable('node1');
    final n2 = NodeReferenceable('node2');
    final n3 = NodeReferenceable('node3');

    final nRef1 = Reference(n1);
    final nRef2 = Reference(n2);
    final nRef3 = Reference(n3);

    n3.reference(n2);
    n2.reference(n1);

    nRef1.dispose();

    expect(n1.isReferenced, true);
    expect(n2.isReferenced, true);
    expect(n3.isReferenced, true);

    nRef2.dispose();

    expect(n1.isReferenced, true);
    expect(n2.isReferenced, true);
    expect(n3.isReferenced, true);

    nRef3.dispose();

    expect(n1.isReferenced, false);
    expect(n2.isReferenced, false);
    expect(n3.isReferenced, false);
  });

  test('Reference test 02', () {
    final n1 = NodeReferenceable('node1');
    final n2 = NodeReferenceable('node2');
    final n3 = NodeReferenceable('node3');

    final nRef1 = Reference(n1);
    final nRef2 = Reference(n2);
    final nRef3 = Reference(n3);

    n3.reference(n2);
    n2.reference(n1);
    n1.reference(n3);

    nRef1.dispose();

    expect(n1.isReferenced, true);
    expect(n2.isReferenced, true);
    expect(n3.isReferenced, true);

    nRef2.dispose();

    expect(n1.isReferenced, true);
    expect(n2.isReferenced, true);
    expect(n3.isReferenced, true);

    nRef3.dispose();

    expect(n1.isReferenced, false);
    expect(n2.isReferenced, false);
    expect(n3.isReferenced, false);
  });

  test('Reference test 03', () {
    final n1 = NodeReferenceable('node1');

    final nRef1 = Reference(n1);

    n1.reference(n1);

    expect(n1.isReferenced, true);

    nRef1.dispose();

    expect(n1.isReferenced, false);
  });

  test('Reference test 04', () {
    final n1 = NodeReferenceable('node1');
    final n2 = NodeReferenceable('node2');

    expect(() => n1.reference(n2), throwsArgumentError);

    final n1Ref = Reference(n1);

    n1.reference(n2);

    n1Ref.dispose();

    expect(n1.isReferenced, false);
    expect(n2.isReferenced, false);
  });

  test('Reference test 05', () {
    final n1 = NodeReferenceable('node1');

    final nRef1 = Reference(n1);

    expect(n1.isReferenced, true);

    nRef1.dispose();

    expect(n1.isReferenced, false);
  });

  test('Reference test 06', () {
    final n1 = NodeReferenceable('node1');
    final n2 = NodeReferenceable('node2');

    final nRef1 = Reference(n1);
    final nRef2 = Reference(n2);

    n1.reference(n2);

    expect(n1.isReferenced, true);
    expect(n2.isReferenced, true);

    nRef2.dispose();

    expect(n1.isReferenced, true);
    expect(n2.isReferenced, true);

    nRef1.dispose();

    expect(n1.isReferenced, false);
    expect(n2.isReferenced, false);
  });

  test('Reference test 07', () {
    final n1 = NodeReferenceable('node1');
    final n2 = NodeReferenceable('node2');

    final nRef1 = Reference(n1);
    final nRef2 = Reference(n2);

    n1.reference(n2);

    expect(n1.isReferenced, true);
    expect(n2.isReferenced, true);

    nRef1.dispose();

    expect(n1.isReferenced, false);
    expect(n2.isReferenced, true);

    nRef2.dispose();

    expect(n1.isReferenced, false);
    expect(n2.isReferenced, false);
  });

  test('Reference test 08', () {
    final n1 = NodeReferenceable('node1');
    final n2 = NodeReferenceable('node2');

    Reference(n1);
    final nRef2 = Reference(n2);

    n1.reference(n2);

    nRef2.dispose();

    expect(n2.isReferenced, true);
  });
}
