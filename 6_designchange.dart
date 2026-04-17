import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:intl/intl.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const SmartHealthKioskApp());
}

class SmartHealthKioskApp extends StatelessWidget {
  const SmartHealthKioskApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'UniMAP Smart Health Kiosk',
      theme: ThemeData(
        primaryColor: const Color(0xFF133F85), // Updated to match theme
        scaffoldBackgroundColor: Colors.white,
        useMaterial3: true,
      ),
      home: const KioskLoginPage(),
    );
  }
}

// --- LOGIN PAGE ---
class KioskLoginPage extends StatefulWidget {
  const KioskLoginPage({super.key});
  @override
  State<KioskLoginPage> createState() => _KioskLoginPageState();
}

class _KioskLoginPageState extends State<KioskLoginPage> {
  final TextEditingController _idC = TextEditingController();
  final TextEditingController _passC = TextEditingController();
  bool _isLoading = false;

  Future<void> _handleLogin() async {
    setState(() => _isLoading = true);
    try {
      var doc = await FirebaseFirestore.instance.collection('students').doc(_idC.text.trim()).get();
      if (doc.exists && doc.data()?['password'] == _passC.text.trim()) {
        if (!mounted) return;
        Navigator.pushReplacement(context, MaterialPageRoute(
          builder: (context) => KioskDashboard(
            userName: doc.data()?['name'] ?? "STUDENT",
            userId: _idC.text.trim(),
            isGuest: false,
          ),
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invalid Credentials")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Login Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF133F85),
      body: Center(
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(5)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("SMART HEALTH KIOSK", style: TextStyle(color: Color(0xFF133F85), fontWeight: FontWeight.bold, fontSize: 20)),
              const Divider(height: 40),
              TextField(controller: _idC, decoration: const InputDecoration(labelText: "Student ID", border: OutlineInputBorder())),
              const SizedBox(height: 15),
              TextField(controller: _passC, obscureText: true, decoration: const InputDecoration(labelText: "Password", border: OutlineInputBorder())),
              const SizedBox(height: 25),
              _isLoading
                  ? const CircularProgressIndicator()
                  : SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF133F85), foregroundColor: Colors.white, shape: const RoundedRectangleBorder()),
                        onPressed: _handleLogin,
                        child: const Text("LOGIN"),
                      ),
                    ),
              TextButton(
                onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const KioskDashboard(userName: "GUEST", userId: "GUEST", isGuest: true))),
                child: const Text("Continue as Guest", style: TextStyle(color: Colors.grey)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- MAIN DASHBOARD ---
class KioskDashboard extends StatefulWidget {
  final String userName;
  final String userId;
  final bool isGuest;
  const KioskDashboard({super.key, required this.userName, required this.userId, required this.isGuest});

  @override
  State<KioskDashboard> createState() => _KioskDashboardState();
}

class _KioskDashboardState extends State<KioskDashboard> {
  String _currentView = "HOME";

  Widget _getContent() {
    switch (_currentView) {
      case "APPT_DEPT": return _buildDepartmentSelection();
      case "EQUIP_RES": return _buildEquipmentForm();
      case "EQUIP_HIST": return _buildReservationHistory();
      case "APPT_HIST": return _buildAppointmentHistory();
      case "CHECKUP_HIST": return _buildCheckupHistory();
      default: return _buildHome();
    }
  }

  // --- REDESIGNED HOME GRID (Expanded rows for perfect fitting) ---
  Widget _buildHome() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 20.0),
          child: Column(
            children: const [
              Text(
                'WELCOME! SELECT A SERVICE',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF133F85),
                ),
              ),
              SizedBox(height: 8),
              Text(
                'PLEASE CHOOSE AN OPTION BELOW TO BEGIN.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
        ),
        // Using Flexible structures ensures it dynamically fits the space without overflowing
        Expanded(
          child: Column(
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _buildMenuCard(Icons.medical_services_outlined, 'SELF-CHECKUP', () {})),
                    const SizedBox(width: 16),
                    Expanded(child: _buildMenuCard(Icons.event_note_outlined, 'APPOINTMENT', () => setState(() => _currentView = "APPT_DEPT"))),
                    const SizedBox(width: 16),
                    Expanded(child: _buildMenuCard(Icons.wheelchair_pickup_outlined, 'MEDICAL EQUIPMENT\nRESERVATION', () => setState(() => _currentView = "EQUIP_RES"))),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _buildMenuCard(Icons.history_outlined, 'CHECK UP HISTORY', () => setState(() => _currentView = "CHECKUP_HIST"))),
                    const SizedBox(width: 16),
                    Expanded(child: _buildMenuCard(Icons.event_available_outlined, 'APPOINTMENT HISTORY', () => setState(() => _currentView = "APPT_HIST"))),
                    const SizedBox(width: 16),
                    Expanded(child: _buildMenuCard(Icons.handyman_outlined, 'EQUIPMENT RESERVATION\nREQUEST', () => setState(() => _currentView = "EQUIP_HIST"))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Helper for the new flexible home grid items
  Widget _buildMenuCard(IconData icon, String title, VoidCallback onTap) {
    return Card(
      color: const Color(0xFF133F85), // Theme Primary
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, size: 50, color: const Color(0xFF00C7C7)), // Theme Cyan
              const SizedBox(height: 12),
              Text(
                title.toUpperCase(),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDepartmentSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton.icon(onPressed: () => setState(() => _currentView = "HOME"), icon: const Icon(Icons.arrow_back, size: 28,), label: const Text("Back", style: TextStyle(fontSize: 18))),
        const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Text("Select Department", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF133F85)))),
        Wrap(
          spacing: 20,
          runSpacing: 20,
          children: [
            _osiCard("DENTAL CARE", Icons.medical_services, onTap: () => _preCheckAppointment("Dental Care")),
            _osiCard("PHYSIOTHERAPY", Icons.accessibility_new, onTap: () => _preCheckAppointment("Physiotherapy")),
          ],
        ),
      ],
    );
  }

  Future<void> _preCheckAppointment(String dept) async {
    var q = await FirebaseFirestore.instance
        .collection('appointments')
        .where('patient_id', isEqualTo: widget.userId)
        .where('status', isEqualTo: 'Booked')
        .get();

    if (q.docs.isNotEmpty) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text("Active Appointment Found"),
          content: const Text("You already have an active appointment. Do you still want to proceed? (You are not allowed to make multiple bookings until your current appointment is finished)."),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text("Go Back")),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(c);
                _handleDeptClick(dept);
              },
              child: const Text("Proceed anyway"),
            ),
          ],
        ),
      );
    } else {
      _handleDeptClick(dept);
    }
  }

  void _handleDeptClick(String dept) {
    if (widget.isGuest) {
      _showGuestForm(dept);
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (c) => AppointmentPage(department: dept, userName: widget.userName.toUpperCase(), userId: widget.userId, isGuest: false)));
    }
  }

  void _showGuestForm(String dept) {
    final nameC = TextEditingController();
    final idC = TextEditingController();
    final phC = TextEditingController();
    final emC = TextEditingController();
    final fKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Guest Details"),
        content: SingleChildScrollView(
          child: Form(
            key: fKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameC,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(labelText: "Full Name"),
                  onChanged: (val) {
                    nameC.value = nameC.value.copyWith(text: val.toUpperCase(), selection: TextSelection.collapsed(offset: val.length));
                  },
                  validator: (v) => v!.isEmpty ? "Required" : null,
                ),
                TextFormField(controller: idC, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: const InputDecoration(labelText: "ID/IC Number"), validator: (v) => v!.isEmpty ? "Required" : null),
                TextFormField(
                  controller: phC, 
                  inputFormatters: [PhoneInputFormatter()], 
                  decoration: const InputDecoration(
                    labelText: "Phone (eg. 01X-XXXXXXX)", 
                    helperText: "Please enter valid phone number" 
                  ),
                  validator: (v) {
                    String clean = v!.replaceAll('-', '');
                    if (clean.length < 10 || clean.length > 11) {
                      return "Please enter valid phone number"; 
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: emC, 
                  decoration: const InputDecoration(labelText: "Email"),
                  validator: (v) {
                    if (v == null || v.isEmpty) return "Required";
                    final emailRegex = RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+");
                    if (!emailRegex.hasMatch(v)) return "Invalid email format";
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              if (fKey.currentState!.validate()) {
                Navigator.pop(c);
                Navigator.push(context, MaterialPageRoute(builder: (p) => AppointmentPage(department: dept, userName: nameC.text.toUpperCase(), userId: idC.text, isGuest: true, guestPhone: phC.text, guestEmail: emC.text)));
              }
            },
            child: const Text("Continue"),
          ),
        ],
      ),
    );
  }

  Widget _buildEquipmentForm() {
    final equipC = TextEditingController();
    final durC = TextEditingController();
    final reaC = TextEditingController();
    final fKey = GlobalKey<FormState>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton.icon(onPressed: () => setState(() => _currentView = "HOME"), icon: const Icon(Icons.arrow_back, size: 28), label: const Text("Back", style: TextStyle(fontSize: 18))),
        const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Text("Equipment Reservation Form", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF133F85)))),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(border: Border.all(color: Colors.black12), borderRadius: BorderRadius.circular(10)),
          child: Form(
            key: fKey,
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: "Equipment Type", border: OutlineInputBorder()),
                    items: ["Wheelchair", "Crutches", "Nebulizer"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (v) => equipC.text = v!),
                const SizedBox(height: 15),
                TextFormField(
                  controller: durC, 
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: "Loan Duration (In Days)", border: OutlineInputBorder()), 
                  validator: (v) => v!.isEmpty ? "Required" : null
                ),
                const SizedBox(height: 15),
                TextFormField(controller: reaC, maxLines: 2, decoration: const InputDecoration(labelText: "Reason", border: OutlineInputBorder()), validator: (v) => v!.isEmpty ? "Required" : null),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF133F85), foregroundColor: Colors.white),
                    onPressed: () {
                      if (fKey.currentState!.validate()) {
                        int days = int.tryParse(durC.text) ?? 0;
                        String label = days == 1 ? "day" : "days";
                        showDialog(
                          context: context,
                          builder: (c) => AlertDialog(
                            title: const Text("Confirm Reservation"),
                            content: Text("Reserve ${equipC.text} for $days $label?"),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(c), child: const Text("Back")),
                              ElevatedButton(
                                onPressed: () async {
                                  Navigator.pop(c);
                                  await FirebaseFirestore.instance.collection('reservations').add({
                                    'item': equipC.text,
                                    'duration': days,
                                    'reason': reaC.text,
                                    'patient_name': widget.userName.toUpperCase(),
                                    'patient_id': widget.userId,
                                    'status': 'Pending',
                                    'timestamp': FieldValue.serverTimestamp()
                                  });
                                  setState(() => _currentView = "EQUIP_HIST");
                                },
                                child: const Text("Confirm"),
                              ),
                            ],
                          ),
                        );
                      }
                    },
                    child: const Text("SUBMIT REQUEST", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReservationHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            TextButton.icon(onPressed: () => setState(() => _currentView = "HOME"), icon: const Icon(Icons.arrow_back), label: const Text("Back")),
            const SizedBox(width: 10),
            const Text("RESERVATION HISTORY", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF133F85))),
          ],
        ),
        const SizedBox(height: 20),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('reservations').where('patient_id', isEqualTo: widget.userId).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("No reservations found."));
              var docs = snapshot.data!.docs;
              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  var data = docs[index].data() as Map<String, dynamic>;
                  String status = data['status'] ?? "Pending";
                  Color sc = status == "Approved" ? Colors.green : (status == "Returned" ? Colors.blue : (status == "Overdue" ? Colors.red : Colors.orange));
                  
                  dynamic rawDuration = data['duration'];
                  int days = 0;
                  if (rawDuration is int) {
                    days = rawDuration;
                  } else if (rawDuration is String) {
                    days = int.tryParse(rawDuration) ?? 0;
                  }
                  String dayLabel = days == 1 ? "day" : "days";

                  return Card(
                    elevation: 2,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      leading: Icon(Icons.medical_information, color: sc, size: 30),
                      title: Text(data['item'] ?? "Equipment", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      subtitle: Text("Duration: $days $dayLabel"),
                      trailing: Text(status, style: TextStyle(color: sc, fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAppointmentHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            TextButton.icon(onPressed: () => setState(() => _currentView = "HOME"), icon: const Icon(Icons.arrow_back), label: const Text("Back")),
            const SizedBox(width: 10),
            const Text("APPOINTMENTS", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF133F85))),
          ],
        ),
        const SizedBox(height: 20),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('appointments').where('patient_id', isEqualTo: widget.userId).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("No records found."));
              var docs = snapshot.data!.docs;
              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  var data = docs[index].data() as Map<String, dynamic>;
                  String status = data['status'] ?? "Booked";
                  return Card(
                    elevation: 2,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      leading: const Icon(Icons.calendar_today, size: 30),
                      title: Text(data['department'] ?? "Clinic", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      subtitle: Text("${data['date']} | ${data['time']}"),
                      trailing: status == "Booked"
                          ? IconButton(
                              icon: const Icon(Icons.cancel, color: Colors.red, size: 30), 
                              onPressed: () => _showCancelConfirmation(docs[index].id)
                            )
                          : Text(status, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _showCancelConfirmation(String id) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Cancel Appointment"),
        content: const Text("Are you sure you want to cancel this appointment? This action cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("No, Keep it")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(c);
              _cancelAppt(id);
            }, 
            child: const Text("Yes, Cancel")
          ),
        ],
      ),
    );
  }

  Future<void> _cancelAppt(String id) async {
    await FirebaseFirestore.instance.collection('appointments').doc(id).update({'status': 'Cancelled'});
  }

  Widget _buildCheckupHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            TextButton.icon(onPressed: () => setState(() => _currentView = "HOME"), icon: const Icon(Icons.arrow_back), label: const Text("Back")),
            const SizedBox(width: 10),
            const Text("CHECKUP HISTORY", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF133F85))),
          ],
        ),
        const SizedBox(height: 20),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('checkups').where('patient_id', isEqualTo: widget.userId).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("No records found."));
              return ListView.builder(
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  var data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                  return Card(
                    elevation: 2,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      leading: const Icon(Icons.monitor_heart, color: Colors.red, size: 30), 
                      title: Text("Temp: ${data['temp']}°C | BPM: ${data['heart_rate']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))
                    )
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // --- TOP BAR WITH RELOCATED LOGOUT BUTTON ---
  Widget _buildTopBar() {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 25),
      decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)]),
      child: Row(
        children: [
          const Icon(Icons.health_and_safety, color: Color(0xFF133F85), size: 35),
          const SizedBox(width: 15),
          const Text(
            "SMART HEALTH KIOSK", 
            style: TextStyle(color: Color(0xFF133F85), fontWeight: FontWeight.bold, fontSize: 20, letterSpacing: 1.2)
          ),
          const Spacer(),
          Text(widget.userName.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(width: 15),
          const CircleAvatar(radius: 20, backgroundColor: Colors.orange, child: Icon(Icons.person, color: Colors.white, size: 24)),
          const SizedBox(width: 25),
          Container(
            height: 40,
            width: 1.5,
            color: Colors.grey.shade300,
          ),
          const SizedBox(width: 25),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade50, 
              foregroundColor: Colors.red.shade800,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)
            ),
            icon: const Icon(Icons.power_settings_new),
            label: const Text("LOG OUT", style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => const KioskLoginPage())),
          )
        ],
      ),
    );
  }

  // --- SUBDUED EMERGENCY BUTTON SECTION ---
  Widget _buildEmergencyButton() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: SizedBox(
        width: 280, // Restricts width so it's not a massive banner
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade600, // Slightly softer red
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14), // Smaller padding
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)), // Pill shape
            elevation: 3,
          ),
          icon: const Icon(Icons.emergency, size: 22), // Smaller icon
          label: const Text(
            "EMERGENCY HELP", 
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2) // Smaller text
          ),
          onPressed: () {
            showDialog(
              context: context,
              builder: (c) => AlertDialog(
                backgroundColor: Colors.red.shade50,
                title: Row(
                  children: const [
                    Icon(Icons.warning_amber_rounded, color: Colors.red, size: 40),
                    SizedBox(width: 10),
                    Text("EMERGENCY", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  ],
                ),
                content: const Text("Staff have been notified. Please remain at the kiosk. Help is on the way.", style: TextStyle(fontSize: 18)),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(c), child: const Text("DISMISS", style: TextStyle(color: Colors.black54))),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // 1. Top Information/Navigation Bar
          _buildTopBar(),
          // 2. Main Content Area (Expands to fit space perfectly, preventing scrolling)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(25), 
              child: _getContent()
            )
          ),
          // 3. Smaller, centered Emergency Button anchored to the bottom
          _buildEmergencyButton(),
        ],
      ),
    );
  }

  Widget _osiCard(String t, IconData i, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 250,
        height: 200,
        decoration: BoxDecoration(
          color: Colors.white, 
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200, width: 2),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))]
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(i, color: const Color(0xFF133F85), size: 50), 
            const SizedBox(height: 20),
            Text(t, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF133F85))),
          ],
        ),
      ),
    );
  }
}

// ... APPOINTMENT PAGE CODE REMAINS EXACTLY THE SAME BELOW ...

class AppointmentPage extends StatefulWidget {
  final String department;
  final String userName;
  final String userId;
  final bool isGuest;
  final String? guestPhone;
  final String? guestEmail;

  const AppointmentPage({
    super.key,
    required this.department,
    required this.userName,
    required this.userId,
    required this.isGuest,
    this.guestPhone,
    this.guestEmail,
  });

  @override
  State<AppointmentPage> createState() => _AppointmentPageState();
}

class _AppointmentPageState extends State<AppointmentPage> {
  late DateTime today;
  late DateTime fDate;
  DateTime? selDate;
  String? selTime;
  List<String> booked = [];
  bool hasActive = false;

  @override
  void initState() {
    super.initState();
    today = DateTime.now();
    fDate = DateTime(today.year, today.month, 1);
    _checkExistingBookings();
  }

  Future<void> _checkExistingBookings() async {
    var q = await FirebaseFirestore.instance
        .collection('appointments')
        .where('patient_id', isEqualTo: widget.userId)
        .where('status', isEqualTo: 'Booked')
        .get();
    if (mounted) setState(() => hasActive = q.docs.isNotEmpty);
  }

  Future<void> _fetchBookedSlots(DateTime d) async {
    String s = DateFormat('yyyy-MM-dd').format(d);
    var q = await FirebaseFirestore.instance
        .collection('appointments')
        .where('department', isEqualTo: widget.department)
        .where('date', isEqualTo: s)
        .where('status', isEqualTo: 'Booked')
        .get();
    setState(() {
      booked = q.docs.map((doc) => doc.data()['time'] as String).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: Text("Schedule: ${widget.department}"),
        backgroundColor: const Color(0xFF133F85), // Updated to match image theme
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(25),
        child: Column(
          children: [
            if (hasActive)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.red.shade200)),
                width: double.infinity,
                child: const Text("Active booking detected. Viewing mode only.", textAlign: TextAlign.center, style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              ),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildCalendarHeader(),
                          const Divider(height: 1),
                          Flexible(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(15),
                              child: _buildCalendarGrid(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 25),
                  Expanded(
                    flex: 2,
                    child: _buildTimeSlotSection(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _buildConfirmButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarHeader() {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => setState(() => fDate = DateTime(fDate.year, fDate.month - 1))),
          Text(DateFormat('MMMM yyyy').format(fDate), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF133F85))),
          IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => setState(() => fDate = DateTime(fDate.year, fDate.month + 1))),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid() {
    int days = DateTime(fDate.year, fDate.month + 1, 0).day;
    DateTime first = DateTime(fDate.year, fDate.month, 1);
    List<String> weekdays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];

    return Column(
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: weekdays.map((d) => Text(d, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blueGrey))).toList()),
        const SizedBox(height: 15),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: days + (first.weekday - 1),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, mainAxisSpacing: 8, crossAxisSpacing: 8),
          itemBuilder: (context, index) {
            int day = index - (first.weekday - 1) + 1;
            if (day <= 0) return const SizedBox.shrink();
            DateTime dt = DateTime(fDate.year, fDate.month, day);
            bool isDisabled = dt.isBefore(DateTime(today.year, today.month, today.day)) || dt.weekday >= 6;
            bool isSelected = selDate != null && selDate!.day == day && selDate!.month == fDate.month && selDate!.year == fDate.year;

            return GestureDetector(
              onTap: isDisabled ? null : () {
                setState(() { selDate = dt; selTime = null; });
                _fetchBookedSlots(dt);
              },
              child: Container(
                decoration: BoxDecoration(color: isSelected ? const Color(0xFF133F85) : (isDisabled ? Colors.grey[100] : Colors.white), borderRadius: BorderRadius.circular(8), border: Border.all(color: isSelected ? Colors.transparent : Colors.black12)),
                child: Center(child: Text("$day", style: TextStyle(color: isDisabled ? Colors.grey[400] : (isSelected ? Colors.white : Colors.black)))),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildTimeSlotSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.black12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Time Slots", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
          const SizedBox(height: 20),
          Expanded(
            child: selDate == null
                ? const Center(child: Text("Select a date"))
                : GridView.count(
                    crossAxisCount: 2,
                    childAspectRatio: 2.5,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    children: _generateTimeSlots(selDate).map((time) {
                      bool isB = booked.contains(time);
                      return ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: isB ? Colors.red.shade50 : (selTime == time ? Colors.green : Colors.white), foregroundColor: isB ? Colors.red : (selTime == time ? Colors.white : Colors.black87), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                        onPressed: isB ? null : () => setState(() => selTime = time),
                        child: Text(isB ? "BOOKED" : time, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmButton() {
    bool canConfirm = selDate != null && selTime != null && !hasActive;
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: canConfirm ? const Color(0xFF133F85) : Colors.grey, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        onPressed: canConfirm ? _showConfirmation : null,
        child: Text(hasActive ? "LIMIT REACHED" : "CONFIRM APPOINTMENT", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      ),
    );
  }

  void _showConfirmation() {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Confirm"),
        content: Text("Book for ${DateFormat('dd MMMM yyyy').format(selDate!)} at $selTime?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("Back")),
          ElevatedButton(onPressed: () { Navigator.pop(c); _submit(); }, child: const Text("Confirm")),
        ],
      ),
    );
  }

  void _submit() async {
    String d = DateFormat('yyyy-MM-dd').format(selDate!);
    Map<String, dynamic> data = {'department': widget.department, 'date': d, 'time': selTime, 'status': 'Booked', 'patient_name': widget.userName, 'patient_id': widget.userId, 'timestamp': FieldValue.serverTimestamp()};
    if (widget.isGuest) { data['phone'] = widget.guestPhone; data['email'] = widget.guestEmail; }
    await FirebaseFirestore.instance.collection('appointments').add(data);
    if (mounted) Navigator.pop(context);
  }

  List<String> _generateTimeSlots(DateTime? d) {
    if (d == null) return [];
    List<String> s = [];
    DateTime t = DateTime(d.year, d.month, d.day, 8, 30);
    while (t.hour < 17) {
      bool isF = d.weekday == 5;
      if (!(isF ? (t.hour >= 12 && t.hour < 15) : (t.hour == 13))) s.add(DateFormat('hh:mm a').format(t));
      t = t.add(const Duration(minutes: 30));
    }
    return s;
  }
}

class PhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue old, TextEditingValue newVal) {
    String t = newVal.text.replaceAll('-', '');
    if (t.length > 11) return old;
    String f = "";
    for (int i = 0; i < t.length; i++) {
      f += t[i];
      if (i == 2 && t.length > 3) f += "-";
    }
    return TextEditingValue(text: f, selection: TextSelection.collapsed(offset: f.length));
  }
}

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android: return android;
      default: throw UnsupportedError('Platform not supported');
    }
  }
  static const FirebaseOptions web = FirebaseOptions(apiKey: "AIzaSyB0t88bvV3eTZoGLqt3_DOp4AXjwEYTlW4", authDomain: "smart-health-kiosk-193a5.firebaseapp.com", projectId: "smart-health-kiosk-193a5", storageBucket: "smart-health-kiosk-193a5.firebasestorage.app", messagingSenderId: "74365494988", appId: "1:74365494988:web:977ee83752dbb8b7ca4469");
  static const FirebaseOptions android = FirebaseOptions(apiKey: "AIzaSyB0t88bvV3eTZoGLqt3_DOp4AXjwEYTlW4", appId: "1:74365494988:android:977ee83752dbb8b7ca4469", messagingSenderId: "74365494988", projectId: "smart-health-kiosk-193a5", storageBucket: "smart-health-kiosk-193a5.firebasestorage.app");
}