/// The persisted current list.
class CowList {
  const CowList({required this.cowNumbers, required this.lastUpdated});

  final Set<int> cowNumbers;
  final DateTime lastUpdated;
}
