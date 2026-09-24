/// Reads a date field written by a `toJson()`. `cloud_firestore` accepts a
/// raw [DateTime] on write but hands back its own `Timestamp` type on
/// read — calling `.toDate()` dynamically (instead of importing
/// `cloud_firestore` just for that one type check) keeps model files
/// backend-agnostic, matching every repository interface in `lib/data/`.
DateTime? dateFromFirestoreValue(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return (value as dynamic).toDate() as DateTime;
}
