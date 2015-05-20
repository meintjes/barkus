library draft.internal;

import 'package:uuid/uuid.dart';

Uuid uuid = new Uuid();

// Creates a draft with a unique ID. Returns that ID.
String create() {
  // TODO verify uniqueness
  return uuid.v4();
}