import 'package:frappe/frappe.dart';

import 'node.dart';
import 'typedef.dart';

void initTransaction() => Transaction.init();

T runTransaction<T>(Runner<T> runner) =>
    Transaction.run((transaction) => runner());
