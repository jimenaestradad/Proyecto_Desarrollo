/// Reads DateTime or Firestore Timestamp date values.
/// Dynamic `.toDate()` avoids a cloud_firestore dependency in model files.
DateTime? dateFromFirestoreValue(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return (value as dynamic).toDate() as DateTime;
}
