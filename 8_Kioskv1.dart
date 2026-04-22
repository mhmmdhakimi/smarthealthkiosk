import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:qr_flutter/qr_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // KIOSK MODE: Force Landscape & Immersive Fullscreen
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeRight,
    DeviceOrientation.landscapeLeft,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const SmartHealthKioskApp());
}

// --- EMAILJS HELPER FUNCTION ---
Future<void> sendEmailJSEmail({
  required String templateId,
  required Map<String, dynamic> templateParams,
}) async {
  const serviceId = 'service_f3mmtjj'; 
  const publicKey = '73WBQxNlkGUqMf2r9'; 

  final url = Uri.parse('https://api.emailjs.com/api/v1.0/email/send');
  
  try {
    final response = await http.post(
      url,
      headers: {
        'origin': 'http://localhost',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'service_id': serviceId,
        'template_id': templateId,
        'user_id': publicKey,
        'template_params': templateParams,
      }),
    );
    
    if (response.statusCode == 200) {
      debugPrint("Email successfully sent via EmailJS (Template: $templateId)");
    } else {
      debugPrint("EmailJS Error: ${response.body}");
    }
  } catch (e) {
    debugPrint("Failed to send email: $e");
  }
}

class SmartHealthKioskApp extends StatelessWidget {
  const SmartHealthKioskApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'UniMAP Smart Health Kiosk',
      theme: ThemeData(
        primaryColor: const Color(0xFF133F85),
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

  // Guest data state
  String? _guestEquipName;
  String? _guestEquipId;
  String? _guestEquipPhone;
  String? _guestEquipEmail;

  // Equipment Form Controllers
  final TextEditingController _equipC = TextEditingController();
  final TextEditingController _reaC = TextEditingController();
  final GlobalKey<FormState> _equipFKey = GlobalKey<FormState>();

  // Dropdown States for Equipment Date Selection
  String? _sDay; String? _sMonth; String? _sYear; 
  String? _eDay; String? _eMonth; String? _eYear; 

  final List<String> _daysList = List.generate(31, (i) => (i + 1).toString());
  final List<String> _monthsList = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
  final List<String> _yearsList = [DateTime.now().year.toString(), (DateTime.now().year + 1).toString()];

  Widget _getContent() {
    switch (_currentView) {
      case "SEE_DOCTOR_OPT": return _buildSeeDoctorOptions();
      case "WALK_IN_TRIAGE": return _buildWalkInTriage();
      case "APPT_DEPT": return _buildDepartmentSelection();
      case "EQUIP_RES": return _buildEquipmentForm();
      case "EQUIP_HIST": return _buildReservationHistory();
      case "APPT_HIST": return _buildAppointmentHistory();
      case "CHECKUP_HIST": return _buildCheckupHistory();
      default: return _buildHome();
    }
  }

  // --- REUSABLE POST-ACTION DIALOG ---
  void _showPostActionDialog(BuildContext context, VoidCallback onContinue) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text("Success!", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
        content: const Text("Your request has been successfully processed.\n\nDo you want to continue using the kiosk or log out?", style: TextStyle(fontSize: 16)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(c);
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const KioskLoginPage()),
                (route) => false,
              );
            },
            child: const Text("LOG OUT", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF133F85), foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(c);
              onContinue();
            },
            child: const Text("CONTINUE", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildHome() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 20.0),
          child: Column(
            children: const [
              Text('WELCOME! SELECT A SERVICE', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF133F85))),
              SizedBox(height: 8),
              Text('PLEASE CHOOSE AN OPTION BELOW TO BEGIN.', style: TextStyle(fontSize: 16, color: Colors.black54)),
            ],
          ),
        ),
        Expanded(
          child: Column(
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _buildMenuCard(Icons.medical_services_outlined, 'SELF-CHECKUP', () {})),
                    const SizedBox(width: 16),
                    Expanded(child: _buildMenuCard(Icons.person_search_outlined, 'SEE A DOCTOR', () => setState(() => _currentView = "SEE_DOCTOR_OPT"))),
                    const SizedBox(width: 16),
                    Expanded(child: _buildMenuCard(Icons.wheelchair_pickup_outlined, 'BORROW\nEQUIPMENT', _handleEquipClick)),
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
                    Expanded(child: _buildMenuCard(Icons.handyman_outlined, 'EQUIPMENT LOAN\nHISTORY', () => setState(() => _currentView = "EQUIP_HIST"))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMenuCard(IconData icon, String title, VoidCallback onTap) {
    return Card(
      color: const Color(0xFF133F85),
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
              Icon(icon, size: 50, color: const Color(0xFF00C7C7)),
              const SizedBox(height: 12),
              Text(title.toUpperCase(), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white, height: 1.2)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSeeDoctorOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(onPressed: () => setState(() => _currentView = "HOME"), icon: const Icon(Icons.arrow_back, size: 28,), label: const Text("Back", style: TextStyle(fontSize: 18))),
        ),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("How would you like to see a doctor?", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF133F85))),
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _osiCard("WALK-IN", Icons.directions_walk, onTap: () => setState(() => _currentView = "WALK_IN_TRIAGE")),
                  const SizedBox(width: 40),
                  _osiCard("SCHEDULE APPOINTMENT", Icons.calendar_month, onTap: () => setState(() => _currentView = "APPT_DEPT")),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWalkInTriage() {
    DateTime now = DateTime.now();
    DateTime startOfToday = DateTime(now.year, now.month, now.day);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(onPressed: () => setState(() => _currentView = "SEE_DOCTOR_OPT"), icon: const Icon(Icons.arrow_back, size: 28,), label: const Text("Back", style: TextStyle(fontSize: 18))),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(15),
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blue.shade200)),
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('walk_ins')
                .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfToday))
                .where('status', isEqualTo: 'Waiting')
                .snapshots(),
            builder: (context, snapshot) {
              int peopleWaiting = 0;
              if (snapshot.hasData) {
                peopleWaiting = snapshot.data!.docs.length;
              }
              return Column(
                children: [
                  const Text("LIVE CLINIC STATUS", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF133F85))),
                  const SizedBox(height: 5),
                  Text("$peopleWaiting", style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.red)),
                  const Text("people currently waiting in queue", style: TextStyle(fontSize: 14, color: Colors.black87)),
                ],
              );
            },
          ),
        ),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Please select your primary reason for visiting:", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF133F85))),
              const SizedBox(height: 30),
              Wrap(
                spacing: 20,
                runSpacing: 20,
                alignment: WrapAlignment.center,
                children: [
                  _triageCard("Fever / Flu / Cough", Icons.thermostat, onTap: () => _handleWalkInSubmission("Fever / Flu / Cough")),
                  _triageCard("Physical Injury / Pain", Icons.personal_injury, onTap: () => _handleWalkInSubmission("Physical Injury / Pain")),
                  _triageCard("Follow-up / Review", Icons.loop, onTap: () => _handleWalkInSubmission("Follow-up / Review")),
                  _triageCard("Other / General", Icons.help_outline, onTap: () => _handleWalkInSubmission("Other / General")),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _triageCard(String title, IconData icon, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 250, height: 120,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300, width: 2), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)]),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFF133F85), size: 35), 
            const SizedBox(height: 10), 
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF133F85)))
          ],
        ),
      ),
    );
  }

  void _handleWalkInSubmission(String reason) {
    if (widget.isGuest) {
      _showGuestForm(
        title: "Guest Details for Walk-In",
        onContinue: (name, id, phone, email) {
          _generateWalkInTicket(name: name, id: id, reason: reason, phone: phone, email: email);
        }
      );
    } else {
      _generateWalkInTicket(name: widget.userName, id: widget.userId, reason: reason);
    }
  }

  // --- THE FIX: BULLETPROOF TICKET GENERATION & QR ---
  Future<void> _generateWalkInTicket({required String name, required String id, required String reason, String? phone, String? email}) async {
    // Safely trigger the loading dialog
    showDialog(
      context: context, 
      barrierDismissible: false, 
      builder: (c) => const Center(child: CircularProgressIndicator())
    );

    try {
      DateTime now = DateTime.now();
      DateTime startOfToday = DateTime(now.year, now.month, now.day);

      var snapshot = await FirebaseFirestore.instance.collection('walk_ins')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfToday))
          .get();

      int queueNumber = 1000 + snapshot.docs.length + 1; 

      Map<String, dynamic> walkInData = {
        'queue_number': queueNumber,
        'patient_name': name.toUpperCase(),
        'patient_id': id,
        'reason': reason,
        'status': 'Waiting',
        'timestamp': FieldValue.serverTimestamp(),
      };

      if (phone != null) walkInData['phone'] = phone;
      if (email != null) walkInData['email'] = email;

      await FirebaseFirestore.instance.collection('walk_ins').add(walkInData);

      // Close the loading dialog perfectly using rootNavigator
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      
      // Trigger the QR visualizer
      _showQRTicket(queueNumber, name, reason);

    } catch (e) {
      // Safely close the loading dialog even if an error happens
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error generating ticket: $e")));
        debugPrint("QR Gen Error: $e");
      }
    }
  }

  void _showQRTicket(int queueNo, String name, String reason) {
    String qrData = "Smart Health Kiosk\nQueue No: $queueNo\nName: $name\nReason: $reason\nDate: ${DateFormat('dd MMM yyyy').format(DateTime.now())}";

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(30),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("YOUR QUEUE NUMBER", style: TextStyle(fontSize: 18, color: Colors.black54)),
            Text("$queueNo", style: const TextStyle(fontSize: 60, fontWeight: FontWeight.bold, color: Color(0xFF133F85))),
            const SizedBox(height: 20),
            QrImageView(data: qrData, version: QrVersions.auto, size: 200.0, backgroundColor: Colors.white),
            const SizedBox(height: 20),
            const Text("Scan this code with your phone camera\nto keep a digital copy of your ticket.", textAlign: TextAlign.center, style: TextStyle(color: Colors.black87)),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity, height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00C7C7), foregroundColor: Colors.white),
                onPressed: () {
                  Navigator.pop(c); // close QR dialog
                  _showPostActionDialog(context, () {
                    setState(() => _currentView = "HOME");
                  });
                },
                child: const Text("DONE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ),
            )
          ],
        ),
      ),
    );
  }

  void _showGuestForm({required String title, required Function(String name, String id, String phone, String email) onContinue}) {
    final nameC = TextEditingController();
    final idC = TextEditingController();
    final phC = TextEditingController();
    final emC = TextEditingController();
    final fKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
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
                  decoration: const InputDecoration(labelText: "Phone (eg. 01X-XXXXXXX)", helperText: "Please enter valid phone number"),
                  validator: (v) {
                    String clean = v!.replaceAll('-', '');
                    if (clean.length < 10 || clean.length > 11) return "Please enter valid phone number";
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
                onContinue(nameC.text.toUpperCase(), idC.text, phC.text, emC.text);
              }
            },
            child: const Text("Continue"),
          ),
        ],
      ),
    );
  }

  void _handleEquipClick() {
    if (widget.isGuest) {
      _showGuestForm(
        title: "Guest Details for Equipment",
        onContinue: (name, id, phone, email) {
          setState(() {
            _guestEquipName = name;
            _guestEquipId = id;
            _guestEquipPhone = phone;
            _guestEquipEmail = email;
            _currentView = "EQUIP_RES";
          });
        }
      );
    } else {
      setState(() => _currentView = "EQUIP_RES");
    }
  }

  Widget _buildDepartmentSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(onPressed: () => setState(() => _currentView = "SEE_DOCTOR_OPT"), icon: const Icon(Icons.arrow_back, size: 28,), label: const Text("Back", style: TextStyle(fontSize: 18))),
        ),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Select Department for Appointment", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF133F85))),
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _osiCard("DENTAL CARE", Icons.medical_services, onTap: () => _preCheckAppointment("Dental Care")),
                  const SizedBox(width: 40),
                  _osiCard("PHYSIOTHERAPY", Icons.accessibility_new, onTap: () => _preCheckAppointment("Physiotherapy")),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _preCheckAppointment(String dept) async {
    var q = await FirebaseFirestore.instance.collection('appointments').where('patient_id', isEqualTo: widget.userId).where('status', isEqualTo: 'Booked').get();
    if (q.docs.isNotEmpty) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text("Active Appointment Found"),
          content: const Text("You already have an active appointment. Do you still want to proceed?"),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text("Go Back")),
            ElevatedButton(onPressed: () { Navigator.pop(c); _handleDeptClick(dept); }, child: const Text("Proceed anyway")),
          ],
        ),
      );
    } else {
      _handleDeptClick(dept);
    }
  }

  void _handleDeptClick(String dept) {
    if (widget.isGuest) {
      _showGuestForm(
        title: "Guest Details for $dept",
        onContinue: (name, id, phone, email) {
          Navigator.push(context, MaterialPageRoute(builder: (p) => AppointmentPage(
            department: dept, userName: name, userId: id, isGuest: true, guestPhone: phone, guestEmail: email,
            onReturnHome: () => setState(() => _currentView = "HOME"),
            onLogOut: () => Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (c) => const KioskLoginPage()), (r) => false),
          )));
        }
      );
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (c) => AppointmentPage(
        department: dept, userName: widget.userName.toUpperCase(), userId: widget.userId, isGuest: false,
        onReturnHome: () => setState(() => _currentView = "HOME"),
        onLogOut: () => Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (c) => const KioskLoginPage()), (r) => false),
      )));
    }
  }

  InputDecoration _dropdownDecor() {
    return InputDecoration(
      filled: true,
      fillColor: Colors.grey.shade100,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(5), borderSide: BorderSide(color: Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(5), borderSide: BorderSide(color: Colors.grey.shade300)),
    );
  }

  Widget _buildDateDropdownRow(
    String title, 
    String? day, String? month, String? year,
    ValueChanged<String?> onDayChanged,
    ValueChanged<String?> onMonthChanged,
    ValueChanged<String?> onYearChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(flex: 2, child: DropdownButtonFormField<String>(decoration: _dropdownDecor(), hint: const Text("Day"), value: day, items: _daysList.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: onDayChanged, validator: (v) => v == null ? "Required" : null)),
            const SizedBox(width: 10),
            Expanded(flex: 4, child: DropdownButtonFormField<String>(decoration: _dropdownDecor(), hint: const Text("Month"), value: month, items: _monthsList.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: onMonthChanged, validator: (v) => v == null ? "Required" : null)),
            const SizedBox(width: 10),
            Expanded(flex: 3, child: DropdownButtonFormField<String>(decoration: _dropdownDecor(), hint: const Text("Year"), value: year, items: _yearsList.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: onYearChanged, validator: (v) => v == null ? "Required" : null)),
          ],
        ),
      ],
    );
  }

  Widget _buildEquipmentForm() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                _equipC.clear(); _reaC.clear(); 
                _sDay = null; _sMonth = null; _sYear = null;
                _eDay = null; _eMonth = null; _eYear = null;
                setState(() => _currentView = "HOME");
              }, 
              icon: const Icon(Icons.arrow_back, size: 28), 
              label: const Text("Back", style: TextStyle(fontSize: 18))
            ),
          ),
          const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Text("Equipment Loan Request", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF133F85)))),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(border: Border.all(color: Colors.black12), borderRadius: BorderRadius.circular(10)),
            child: Form(
              key: _equipFKey,
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: "Equipment Type", border: OutlineInputBorder()),
                      items: ["Wheelchair", "Crutches", "Nebulizer"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: (v) => _equipC.text = v!),
                  const SizedBox(height: 25),
                  
                  _buildDateDropdownRow("START DATE", _sDay, _sMonth, _sYear, (v) => setState(() => _sDay = v), (v) => setState(() => _sMonth = v), (v) => setState(() => _sYear = v)),
                  const SizedBox(height: 15),
                  _buildDateDropdownRow("END DATE", _eDay, _eMonth, _eYear, (v) => setState(() => _eDay = v), (v) => setState(() => _eMonth = v), (v) => setState(() => _eYear = v)),
                  const SizedBox(height: 25),
                  
                  TextFormField(controller: _reaC, maxLines: 2, decoration: const InputDecoration(labelText: "Reason for Loan", border: OutlineInputBorder()), validator: (v) => v!.isEmpty ? "Required" : null),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF133F85), foregroundColor: Colors.white),
                      onPressed: () {
                        if (_equipFKey.currentState!.validate()) {
                          
                          int startMonthIndex = _monthsList.indexOf(_sMonth!) + 1;
                          int endMonthIndex = _monthsList.indexOf(_eMonth!) + 1;
                          DateTime startDate; DateTime endDate;

                          try {
                            startDate = DateTime(int.parse(_sYear!), startMonthIndex, int.parse(_sDay!));
                            endDate = DateTime(int.parse(_eYear!), endMonthIndex, int.parse(_eDay!));
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invalid date selected.")));
                            return;
                          }

                          if (endDate.isBefore(startDate)) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error: End Date cannot be before Start Date.")));
                            return;
                          }

                          String displayDateRange = "${DateFormat('dd MMM yyyy').format(startDate)}  -  ${DateFormat('dd MMM yyyy').format(endDate)}";

                          showDialog(
                            context: context,
                            builder: (c) => AlertDialog(
                              title: const Text("Confirm Reservation"),
                              content: Text("Reserve ${_equipC.text} from\n$displayDateRange?"),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(c), child: const Text("Back")),
                                ElevatedButton(
                                  onPressed: () async {
                                    Navigator.pop(c); // close confirm dialog
                                    
                                    String submitName = widget.isGuest ? (_guestEquipName ?? "GUEST") : widget.userName.toUpperCase();
                                    String submitId = widget.isGuest ? (_guestEquipId ?? "GUEST") : widget.userId;
      
                                    Map<String, dynamic> reservationData = {
                                      'item': _equipC.text,
                                      'start_date': DateFormat('yyyy-MM-dd').format(startDate),
                                      'end_date': DateFormat('yyyy-MM-dd').format(endDate),
                                      'reason': _reaC.text,
                                      'patient_name': submitName,
                                      'patient_id': submitId,
                                      'status': 'Pending',
                                      'timestamp': FieldValue.serverTimestamp()
                                    };
      
                                    if (widget.isGuest) {
                                      reservationData['phone'] = _guestEquipPhone;
                                      reservationData['email'] = _guestEquipEmail;
                                    }
      
                                    await FirebaseFirestore.instance.collection('reservations').add(reservationData);
      
                                    // --- TRIGGER EMAILJS ---
                                    String? recipientEmail = widget.isGuest ? _guestEquipEmail : "s${widget.userId}@studentmail.unimap.edu.my";
      
                                    if (recipientEmail != null && recipientEmail.isNotEmpty) {
                                      await sendEmailJSEmail(
                                        templateId: 'template_aaoznaf',
                                        templateParams: {
                                          'to_email': recipientEmail,
                                          'patient_name': submitName,
                                          'item': _equipC.text,
                                          'duration': displayDateRange,
                                        },
                                      );
                                    }
      
                                    _equipC.clear(); _reaC.clear(); 
                                    _sDay = null; _sMonth = null; _sYear = null;
                                    _eDay = null; _eMonth = null; _eYear = null;
                                    
                                    _showPostActionDialog(context, () {
                                      setState(() => _currentView = "HOME");
                                    });
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
      ),
    );
  }

  Widget _buildReservationHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(onPressed: () => setState(() => _currentView = "HOME"), icon: const Icon(Icons.arrow_back), label: const Text("Back")),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: Text("EQUIPMENT LOAN HISTORY", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF133F85))),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('reservations')
                .where('patient_id', isEqualTo: widget.userId)
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("No loan history found."));
              var docs = snapshot.data!.docs;
              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  var data = docs[index].data() as Map<String, dynamic>;
                  String status = data['status'] ?? "Pending";
                  Color sc = status == "Approved" ? Colors.green : (status == "Returned" ? Colors.blue : (status == "Overdue" ? Colors.red : Colors.orange));
                  
                  String subtitleText = "Awaiting dates";
                  if (data.containsKey('start_date') && data.containsKey('end_date')) {
                     subtitleText = "From: ${data['start_date']}  To: ${data['end_date']}";
                  } else if (data.containsKey('duration')) {
                     subtitleText = "Duration: ${data['duration']} days";
                  }

                  return Card(
                    elevation: 2,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      leading: Icon(Icons.medical_information, color: sc, size: 30),
                      title: Text(data['item'] ?? "Equipment", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      subtitle: Text(subtitleText),
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
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(onPressed: () => setState(() => _currentView = "HOME"), icon: const Icon(Icons.arrow_back), label: const Text("Back")),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: Text("APPOINTMENTS", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF133F85))),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('appointments')
                .where('patient_id', isEqualTo: widget.userId)
                .orderBy('timestamp', descending: true)
                .snapshots(),
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
                          ? IconButton(icon: const Icon(Icons.cancel, color: Colors.red, size: 30), onPressed: () => _showCancelConfirmation(docs[index].id))
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
        content: const Text("Are you sure you want to cancel this appointment?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("No")),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), onPressed: () { Navigator.pop(c); _cancelAppt(id); }, child: const Text("Yes, Cancel")),
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
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(onPressed: () => setState(() => _currentView = "HOME"), icon: const Icon(Icons.arrow_back), label: const Text("Back")),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: Text("CHECKUP HISTORY", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF133F85))),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('checkups')
                .where('patient_id', isEqualTo: widget.userId)
                .orderBy('timestamp', descending: true)
                .snapshots(),
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

  Widget _buildTopBar() {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 25),
      decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)]),
      child: Row(
        children: [
          // Make logo clickable to return home
          InkWell(
            onTap: () => setState(() => _currentView = "HOME"),
            child: Row(
              children: const [
                Icon(Icons.health_and_safety, color: Color(0xFF133F85), size: 35),
                SizedBox(width: 15),
                Text("SMART HEALTH KIOSK", style: TextStyle(color: Color(0xFF133F85), fontWeight: FontWeight.bold, fontSize: 20, letterSpacing: 1.2)),
              ],
            ),
          ),
          const Spacer(),
          Text(widget.userName.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(width: 15),
          const CircleAvatar(radius: 20, backgroundColor: Colors.orange, child: Icon(Icons.person, color: Colors.white, size: 24)),
          const SizedBox(width: 25),
          Container(height: 40, width: 1.5, color: Colors.grey.shade300),
          const SizedBox(width: 25),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade50, foregroundColor: Colors.red.shade800, elevation: 0),
            icon: const Icon(Icons.power_settings_new),
            label: const Text("LOG OUT", style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => const KioskLoginPage())),
          )
        ],
      ),
    );
  }

  Widget _buildEmergencyButton() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: SizedBox(
        width: 280, 
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)), elevation: 3),
          icon: const Icon(Icons.emergency, size: 22), 
          label: const Text("EMERGENCY HELP", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          onPressed: () async {
            try {
              await FirebaseFirestore.instance.collection('emergencies').add({
                'patient_name': widget.userName.toUpperCase(),
                'patient_id': widget.userId,
                'status': 'Unresolved',
                'timestamp': FieldValue.serverTimestamp(),
                'location': 'Kiosk Main',
              });
              debugPrint("Emergency Alert sent to Firebase.");
            } catch (e) {
              debugPrint("Failed to send Emergency Alert to Firebase: $e");
            }

            if (mounted) {
              showDialog(
                context: context,
                builder: (c) => AlertDialog(
                  backgroundColor: Colors.red.shade50,
                  title: Row(children: const [Icon(Icons.warning, color: Colors.red, size: 40), SizedBox(width: 10), Text("EMERGENCY", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))]),
                  content: const Text("Staff have been notified. Please remain at the kiosk. Help is on the way.", style: TextStyle(fontSize: 18)),
                  actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text("DISMISS"))],
                ),
              );
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      body: Column(
        children: [
          _buildTopBar(),
          Expanded(child: Padding(padding: const EdgeInsets.all(25), child: _getContent())),
          if (!isKeyboardOpen) _buildEmergencyButton(),
        ],
      ),
    );
  }

  Widget _osiCard(String t, IconData i, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 250, height: 200,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200, width: 2), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)]),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [Icon(i, color: const Color(0xFF133F85), size: 50), const SizedBox(height: 20), Text(t, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF133F85)))],
        ),
      ),
    );
  }
}

// --- APPOINTMENT PAGE ---
class AppointmentPage extends StatefulWidget {
  final String department;
  final String userName;
  final String userId;
  final bool isGuest;
  final String? guestPhone;
  final String? guestEmail;
  final VoidCallback onReturnHome;
  final VoidCallback onLogOut;

  const AppointmentPage({super.key, required this.department, required this.userName, required this.userId, required this.isGuest, this.guestPhone, this.guestEmail, required this.onReturnHome, required this.onLogOut});
  @override
  State<AppointmentPage> createState() => _AppointmentPageState();
}

class _AppointmentPageState extends State<AppointmentPage> {
  late DateTime today, fDate;
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
    var q = await FirebaseFirestore.instance.collection('appointments').where('patient_id', isEqualTo: widget.userId).where('status', isEqualTo: 'Booked').get();
    if (mounted) setState(() => hasActive = q.docs.isNotEmpty);
  }

  Future<void> _fetchBookedSlots(DateTime d) async {
    String s = DateFormat('yyyy-MM-dd').format(d);
    var q = await FirebaseFirestore.instance.collection('appointments').where('department', isEqualTo: widget.department).where('date', isEqualTo: s).where('status', isEqualTo: 'Booked').get();
    setState(() => booked = q.docs.map((doc) => doc.data()['time'] as String).toList());
  }

  bool _isPastTime(String timeString) {
    if (selDate == null) return false;
    DateTime now = DateTime.now();
    if (selDate!.year == now.year && selDate!.month == now.month && selDate!.day == now.day) {
      try {
        DateTime parsedTime = DateFormat('hh:mm a').parse(timeString);
        DateTime slotDT = DateTime(selDate!.year, selDate!.month, selDate!.day, parsedTime.hour, parsedTime.minute);
        return slotDT.isBefore(now);
      } catch (e) { return false; }
    }
    return false;
  }

  Widget _buildTopBar() {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 25),
      decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)]),
      child: Row(
        children: [
          // Make logo clickable to return home (Pops this page)
          InkWell(
            onTap: () {
              Navigator.pop(context);
              widget.onReturnHome();
            },
            child: Row(
              children: const [
                Icon(Icons.health_and_safety, color: Color(0xFF133F85), size: 35),
                SizedBox(width: 15),
                Text("SMART HEALTH KIOSK", style: TextStyle(color: Color(0xFF133F85), fontWeight: FontWeight.bold, fontSize: 20, letterSpacing: 1.2)),
              ],
            ),
          ),
          const Spacer(),
          Text(widget.userName.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(width: 15),
          const CircleAvatar(radius: 20, backgroundColor: Colors.orange, child: Icon(Icons.person, color: Colors.white, size: 24)),
          const SizedBox(width: 25),
          Container(height: 40, width: 1.5, color: Colors.grey.shade300),
          const SizedBox(width: 25),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade50, foregroundColor: Colors.red.shade800, elevation: 0),
            icon: const Icon(Icons.power_settings_new),
            label: const Text("LOG OUT", style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: widget.onLogOut,
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      body: Column(
        children: [
          _buildTopBar(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(25),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back, size: 28), label: const Text("Back", style: TextStyle(fontSize: 18))),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Text("Schedule Appointment", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF133F85))),
                  ),
                  if (hasActive) Container(padding: const EdgeInsets.all(12), margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10)), child: const Text("Active booking detected. Viewing mode only.", textAlign: TextAlign.center, style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
                  Expanded(child: Row(children: [
                    Expanded(flex: 3, child: Card(child: Column(children: [_buildCalendarHeader(), const Divider(), Expanded(child: SingleChildScrollView(child: _buildCalendarGrid()))]))),
                    const SizedBox(width: 25),
                    Expanded(flex: 2, child: _buildTimeSlotSection()),
                  ])),
                  const SizedBox(height: 20),
                  _buildConfirmButton(),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildCalendarHeader() {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => setState(() => fDate = DateTime(fDate.year, fDate.month - 1))),
      Text(DateFormat('MMMM yyyy').format(fDate), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF133F85))),
      IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => setState(() => fDate = DateTime(fDate.year, fDate.month + 1))),
    ]);
  }

  Widget _buildCalendarGrid() {
    int days = DateTime(fDate.year, fDate.month + 1, 0).day;
    DateTime first = DateTime(fDate.year, fDate.month, 1);
    return GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: days + (first.weekday - 1), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7), itemBuilder: (c, index) {
      int day = index - (first.weekday - 1) + 1;
      if (day <= 0) return const SizedBox.shrink();
      DateTime dt = DateTime(fDate.year, fDate.month, day);
      bool isDisabled = dt.isBefore(DateTime(today.year, today.month, today.day)) || dt.weekday >= 6;
      bool isSelected = selDate != null && selDate!.day == day && selDate!.month == fDate.month;
      return GestureDetector(
        onTap: isDisabled ? null : () { setState(() { selDate = dt; selTime = null; }); _fetchBookedSlots(dt); },
        child: Container(margin: const EdgeInsets.all(4), decoration: BoxDecoration(color: isSelected ? const Color(0xFF133F85) : (isDisabled ? Colors.grey[100] : Colors.white), borderRadius: BorderRadius.circular(8)), child: Center(child: Text("$day", style: TextStyle(color: isDisabled ? Colors.grey[400] : (isSelected ? Colors.white : Colors.black))))),
      );
    });
  }

  Widget _buildTimeSlotSection() {
    return Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)), child: selDate == null ? const Center(child: Text("Select a date")) : GridView.count(crossAxisCount: 2, childAspectRatio: 2.5, children: _generateSlots(selDate).map((time) {
      bool isB = booked.contains(time), isP = _isPastTime(time);
      return Padding(padding: const EdgeInsets.all(4), child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: isB ? Colors.red.shade50 : (selTime == time ? Colors.green : Colors.white), foregroundColor: isB ? Colors.red : (selTime == time ? Colors.white : Colors.black87)), onPressed: (isB || isP) ? null : () => setState(() => selTime = time), child: Text(isB ? "BOOKED" : time, style: const TextStyle(fontSize: 10))));
    }).toList()));
  }

  Widget _buildConfirmButton() {
    bool can = selDate != null && selTime != null && !hasActive;
    return SizedBox(width: double.infinity, height: 60, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: can ? const Color(0xFF133F85) : Colors.grey, foregroundColor: Colors.white), onPressed: can ? _showConf : null, child: const Text("CONFIRM APPOINTMENT", style: TextStyle(fontWeight: FontWeight.bold))));
  }

  void _showConf() {
    showDialog(context: context, builder: (c) => AlertDialog(title: const Text("Confirm"), content: Text("Book for ${DateFormat('dd MMM yyyy').format(selDate!)} at $selTime?"), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text("Back")), ElevatedButton(onPressed: () { Navigator.pop(c); _sub(); }, child: const Text("Confirm"))]));
  }

  void _sub() async {
    String d = DateFormat('yyyy-MM-dd').format(selDate!);
    Map<String, dynamic> data = {'department': widget.department, 'date': d, 'time': selTime, 'status': 'Booked', 'patient_name': widget.userName, 'patient_id': widget.userId, 'timestamp': FieldValue.serverTimestamp()};
    if (widget.isGuest) { data['phone'] = widget.guestPhone; data['email'] = widget.guestEmail; }
    await FirebaseFirestore.instance.collection('appointments').add(data);
    
    String? email = widget.isGuest ? widget.guestEmail : "s${widget.userId}@studentmail.unimap.edu.my";
    if (email != null && email.isNotEmpty) {
      await sendEmailJSEmail(templateId: 'template_lt0jtlj', templateParams: {'to_email': email, 'patient_name': widget.userName, 'department': widget.department, 'date': d, 'time': selTime});
    }
    
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (c) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Text("Success!", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
          content: const Text("Your request has been successfully processed.\n\nDo you want to continue using the kiosk or log out?", style: TextStyle(fontSize: 16)),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(c); // close dialog
                widget.onLogOut(); // go to login
              },
              child: const Text("LOG OUT", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF133F85), foregroundColor: Colors.white),
              onPressed: () {
                Navigator.pop(c); // close dialog
                Navigator.pop(context); // pop AppointmentPage
                widget.onReturnHome(); // tell Dashboard to reset to HOME
              },
              child: const Text("CONTINUE", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }
  }

  List<String> _generateSlots(DateTime? d) {
    if (d == null) return [];
    List<String> s = []; DateTime t = DateTime(d.year, d.month, d.day, 8, 30);
    while (t.hour < 17) { if (!(d.weekday == 5 ? (t.hour >= 12 && t.hour < 15) : (t.hour == 13))) s.add(DateFormat('hh:mm a').format(t)); t = t.add(const Duration(minutes: 30)); }
    return s;
  }
}

class PhoneInputFormatter extends TextInputFormatter {
  @override TextEditingValue formatEditUpdate(TextEditingValue old, TextEditingValue newVal) {
    String t = newVal.text.replaceAll('-', ''); if (t.length > 11) return old;
    String f = ""; for (int i = 0; i < t.length; i++) { f += t[i]; if (i == 2 && t.length > 3) f += "-"; }
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