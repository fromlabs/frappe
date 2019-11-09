import 'node.dart';
import 'typedef.dart';

T runTransaction<T>(Runner<T> runner) =>
    Transaction.run((transaction) => runner());
