import 'package:frappe/src/node.dart';
import 'package:frappe/src/typedef.dart';

T runTransaction<T>(Runner<T> runner) =>
    Transaction.run((transaction) => runner());
