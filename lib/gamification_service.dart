import 'package:cloud_firestore/cloud_firestore.dart';

class GamificationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Increments points for a specific user with Monthly Reset logic
  Future<void> addPoints(String email, int points, {String reason = ""}) async {
    final userRef = _db.collection('users').doc(email);
    
    await _db.runTransaction((transaction) async {
      DocumentSnapshot snapshot = await transaction.get(userRef);

      if (!snapshot.exists) return;

      Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
      
      // Monthly Reset Logic
      DateTime now = DateTime.now();
      String currentMonthKey = "${now.year}-${now.month}";
      String lastResetMonth = data['lastResetMonth'] ?? "";
      
      int currentTotalPoints = data['points'] ?? 0;
      int currentMonthlyPoints = data['monthlyPoints'] ?? 0;
      
      // If it's a new month, reset monthly points to 0 before adding new ones
      if (lastResetMonth != currentMonthKey) {
        currentMonthlyPoints = 0;
      }

      int newTotalPoints = currentTotalPoints + points;
      int newMonthlyPoints = currentMonthlyPoints + points;
      
      // Basic Leveling Logic: 1 level every 1000 total points
      int newLevel = (newTotalPoints / 1000).floor() + 1;

      transaction.update(userRef, {
        'points': newTotalPoints,
        'monthlyPoints': newMonthlyPoints,
        'level': newLevel,
        'lastResetMonth': currentMonthKey,
        'lastPointReason': reason,
        'lastPointAt': FieldValue.serverTimestamp(),
      });
      
      // Log point history
      DocumentReference logRef = _db.collection('users').doc(email).collection('point_history').doc();
      transaction.set(logRef, {
        'pointsAdded': points,
        'newTotal': newTotalPoints,
        'newMonthly': newMonthlyPoints,
        'reason': reason,
        'timestamp': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Award points for time worked (Attendance)
  /// We give 1 point for every 5 minutes worked (~12 points per hour)
  Future<void> awardAttendancePoints(String email, int secondsWorked) async {
    if (secondsWorked < 300) return; // Minimum 5 minutes to get points
    int points = (secondsWorked / 300).floor(); 
    if (points > 0) {
      await addPoints(email, points, reason: "Work Duration (${(secondsWorked/60).round()} mins)");
    }
  }

  /// Specialized call for room completion
  Future<void> awardRoomCompletion(String email, int roomNumber) async {
    await addPoints(email, 100, reason: "Cleaned Room $roomNumber");
  }

  /// Specialized call for stock distribution scan
  Future<void> awardStockScan(String email, String itemName) async {
    await addPoints(email, 10, reason: "Stock Distribution: $itemName");
  }
  
  /// Get top performers for the leaderboard (Sorted by Monthly Points)
  Stream<QuerySnapshot> getLeaderboard() {
    return _db.collection('users')
        .where('role', isEqualTo: 'Housekeeping')
        .orderBy('monthlyPoints', descending: true)
        .limit(10)
        .snapshots();
  }
}
