import 'package:frappe/frappe.dart';

import 'node.dart';
import 'typedef.dart';

bool get isInTransaction => Transaction.isInTransaction;

T runTransaction<T>(Runner<T> runner) =>
    Transaction.run((transaction) => runner());
