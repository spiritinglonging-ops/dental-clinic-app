import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // استبدل القيم أدناه برابط ومفتاح مشروعك الفعلي على Supabase لاحقاً
  await Supabase.initialize(
    url: 'https://YOUR_SUPABASE_PROJECT_URL.supabase.co',
    anonKey: 'YOUR_SUPABASE_ANON_KEY',
  );

  runApp(const DentalClinicApp());
}

final supabase = Supabase.instance.client;

class DentalClinicApp extends StatelessWidget {
  const DentalClinicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'نظام عيادة الأسنان السحابي',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const RoleSelectionScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// شاشة اختيار نوع العيادة عند الدخول
class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تسجيل الدخول - العيادة المشتركة')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'اختر قسم العيادة للدخول:',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(60),
                backgroundColor: Colors.blue[800],
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.medical_services, size: 28),
              label: const Text('عيادة د. باسم (الأسنان العامة)', style: TextStyle(fontSize: 18)),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const DrBasemDashboard()),
                );
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(60),
                backgroundColor: Colors.teal[700],
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.settings_accessibility, size: 28),
              label: const Text('عيادة التقويم (الطبيب المختص)', style: TextStyle(fontSize: 18)),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const OrthoDashboard()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// لوحة تحكم التقويم وسرد المرضى
class OrthoDashboard extends StatefulWidget {
  const OrthoDashboard({super.key});

  @override
  State<OrthoDashboard> createState() => _OrthoDashboardState();
}

class _OrthoDashboardState extends State<OrthoDashboard> {
  Future<List<Map<String, dynamic>>> _fetchOrthoPatients() async {
    try {
      final response = await supabase
          .from('ortho_records')
          .select('*, patients(full_name, phone)');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة تحكم طبيب التقويم'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchOrthoPatients(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final patients = snapshot.data ?? [];

          if (patients.isEmpty) {
            return const Center(
              child: Text(
                'لا توجد بيانات مرضى تقويم حالياً، أو جاري ربط السحابة.',
                style: TextStyle(fontSize: 16),
              ),
            );
          }

          return ListView.builder(
            itemCount: patients.length,
            itemBuilder: (context, index) {
              final item = patients[index];
              final patientName = item['patients']?['full_name'] ?? 'مريض غير معروف';
              final totalCost = item['total_cost'] ?? 0;
              final downPayment = item['down_payment'] ?? 0;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                elevation: 3,
                child: ListTile(
                  title: Text(patientName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  subtitle: Text('التكلفة: $totalCost | المقدم: $downPayment'),
                  trailing: const Icon(Icons.arrow_forward_ios, color: Colors.teal),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => OrthoPatientDetailsScreen(
                          orthoRecordId: item['id'],
                          patientName: patientName,
                          totalCost: (item['total_cost'] as num).toDouble(),
                          downPayment: (item['down_payment'] as num).toDouble(),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// شاشة تفاصيل المريض وجلسات التقويم
class OrthoPatientDetailsScreen extends StatefulWidget {
  final int orthoRecordId;
  final String patientName;
  final double totalCost;
  final double downPayment;

  const OrthoPatientDetailsScreen({
    super.key,
    required this.orthoRecordId,
    required this.patientName,
    required this.totalCost,
    required this.downPayment,
  });

  @override
  State<OrthoPatientDetailsScreen> createState() => _OrthoPatientDetailsScreenState();
}

class _OrthoPatientDetailsScreenState extends State<OrthoPatientDetailsScreen> {
  Future<List<Map<String, dynamic>>> _fetchSessions() async {
    try {
      final response = await supabase
          .from('ortho_sessions')
          .select()
          .eq('ortho_record_id', widget.orthoRecordId)
          .order('session_date', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  void _addNewSessionDialog(BuildContext context) {
    final wireController = TextEditingController();
    final notesController = TextEditingController();
    final paymentController = TextEditingController(text: '0');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('تسجيل جلسة تقويم وقسط جديد'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: wireController,
                  decoration: const InputDecoration(labelText: 'نوع السلك (مثلاً: NiTi 0.14)'),
                ),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(labelText: 'ملاحظات الجلسة والتقدم'),
                ),
                TextField(
                  controller: paymentController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'قيمة القسط المدفوع'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
              onPressed: () async {
                await supabase.from('ortho_sessions').insert({
                  'ortho_record_id': widget.orthoRecordId,
                  'session_date': DateTime.now().toIso8601String(),
                  'wire_type': wireController.text,
                  'notes': notesController.text,
                  'installment_paid': double.tryParse(paymentController.text) ?? 0.0,
                });
                Navigator.pop(context);
                setState(() {});
              },
              child: const Text('حفظ'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('ملف: ${widget.patientName}'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              color: Colors.teal[50],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        const Text('الإجمالي', style: TextStyle(color: Colors.grey)),
                        Text('${widget.totalCost}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Column(
                      children: [
                        const Text('المقدم', style: TextStyle(color: Colors.grey)),
                        Text('${widget.downPayment}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text('سجل الجلسات السابقة:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _fetchSessions(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final sessions = snapshot.data ?? [];
                  if (sessions.isEmpty) {
                    return const Center(child: Text('لا توجد جلسات مسجلة حتى الآن.'));
                  }
                  return ListView.builder(
                    itemCount: sessions.length,
                    itemBuilder: (context, index) {
                      final session = sessions[index];
                      return Card(
                        child: ListTile(
                          title: Text('السلك: ${session['wire_type'] ?? 'غير محدد'}'),
                          subtitle: Text('ملاحظات: ${session['notes']} \nالمدفوع: ${session['installment_paid']}'),
                          trailing: Text(session['session_date'].toString().substring(0, 10)),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        onPressed: () => _addNewSessionDialog(context),
        label: const Text('إضافة جلسة / قسط'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}

// واجهة عيادة د. باسم (كما هي)
class DrBasemDashboard extends StatelessWidget {
  const DrBasemDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('عيادة د. باسم (الأسنان العامة)'), backgroundColor: Colors.blue, foregroundColor: Colors.white),
      body: const Center(child: Text('هنا واجهة عيادة د. باسم الأساسية بدون أي تعديل')),
    );
  }
}
