import 'package:frappe/src/node.dart';
import 'package:frappe/src/typedef.dart';

bool get isInTransaction => Transaction.isInTransaction;

T runTransaction<T>(Runner<T> runner) =>
    Transaction.run((transaction) => runner());
