import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:excel/excel.dart' as ex;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

const schoolName = 'Faisalabad Mesali High School';
const ownerName = 'Dilshad Iqbal';
const schoolPhone = '+92 314 3136682';
const loginUser = 'Dilshad';
const loginPass = 'Dilshad@123';

String money(num value) => 'Rs ${NumberFormat('#,##0').format(value)}';
String ymd(DateTime value) => DateFormat('yyyy-MM-dd').format(value);
String monthKey(DateTime value) => DateFormat('yyyy-MM').format(value);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppDb.instance.database;
  await AppDb.instance.generateMonthlyInvoices();
  runApp(const MhsApp());
}

class MhsApp extends StatelessWidget {
  const MhsApp({super.key});

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF6D5DFB);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MHS School Management',
      theme: ThemeData(
        useMaterial3: true,
        
        colorScheme: ColorScheme.fromSeed(seedColor: primary, brightness: Brightness.light),
        scaffoldBackgroundColor: const Color(0xFFF5F7FB),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
          headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
          titleLarge: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
          titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
          bodyLarge: TextStyle(fontSize: 15, height: 1.45, color: Color(0xFF273244)),
          bodyMedium: TextStyle(fontSize: 14, height: 1.4, color: Color(0xFF475569)),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          labelStyle: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600),
          hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
          prefixIconColor: const Color(0xFF64748B),
          suffixIconColor: const Color(0xFF64748B),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: primary, width: 1.8)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        ),
      ),
      home: const AuthGate(),
    );
  }
}

class AppDb {
  AppDb._();
  static final AppDb instance = AppDb._();
  Database? _db;
  Future<Database> get database async => _db ??= await _open();

  Future<Database> _open() async {
    final base = await getDatabasesPath();
    return openDatabase(
      p.join(base, 'mhs_school_v2.db'),
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''CREATE TABLE students(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          admission_no TEXT UNIQUE NOT NULL,
          name TEXT NOT NULL,
          father_name TEXT NOT NULL,
          father_cnic TEXT NOT NULL,
          mother_name TEXT,
          guardian_phone TEXT NOT NULL,
          alternate_phone TEXT,
          student_bform TEXT,
          gender TEXT,
          dob TEXT,
          address TEXT,
          class_name TEXT NOT NULL,
          section TEXT,
          roll_no TEXT,
          admission_date TEXT NOT NULL,
          status TEXT NOT NULL DEFAULT 'Active',
          monthly_fee REAL NOT NULL DEFAULT 0,
          discount_type TEXT NOT NULL DEFAULT 'None',
          discount_value REAL NOT NULL DEFAULT 0,
          notes TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )''');
        await db.execute('''CREATE TABLE invoices(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          invoice_no TEXT UNIQUE NOT NULL,
          student_id INTEGER NOT NULL,
          title TEXT NOT NULL,
          billing_month TEXT,
          issue_date TEXT NOT NULL,
          due_date TEXT NOT NULL,
          subtotal REAL NOT NULL,
          discount REAL NOT NULL DEFAULT 0,
          fine REAL NOT NULL DEFAULT 0,
          total REAL NOT NULL,
          paid REAL NOT NULL DEFAULT 0,
          status TEXT NOT NULL DEFAULT 'Pending',
          notes TEXT,
          is_manual INTEGER NOT NULL DEFAULT 0,
          created_at TEXT NOT NULL
        )''');
        await db.execute('''CREATE TABLE payments(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          invoice_id INTEGER NOT NULL,
          amount REAL NOT NULL,
          payment_date TEXT NOT NULL,
          method TEXT NOT NULL,
          reference TEXT,
          notes TEXT,
          created_at TEXT NOT NULL
        )''');
        await db.execute('''CREATE TABLE student_history(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          student_id INTEGER NOT NULL,
          event_type TEXT NOT NULL,
          detail TEXT NOT NULL,
          event_date TEXT NOT NULL
        )''');
        await db.execute('''CREATE TABLE settings(
          key TEXT PRIMARY KEY,
          value TEXT
        )''');
        await db.insert('settings', {'key': 'developer_info', 'value': 'Developed for Faisalabad Mesali High School'});
        await db.insert('settings', {'key': 'copyright', 'value': '© ${DateTime.now().year} Faisalabad Mesali High School. All rights reserved.'});
      },
    );
  }

  Future<List<Map<String, dynamic>>> raw(String sql, [List<Object?> args = const []]) async => (await database).rawQuery(sql, args);
  Future<int> insert(String table, Map<String, dynamic> values) async => (await database).insert(table, values);
  Future<int> update(String table, Map<String, dynamic> values, String where, List<Object?> args) async => (await database).update(table, values, where: where, whereArgs: args);
  Future<int> delete(String table, String where, List<Object?> args) async => (await database).delete(table, where: where, whereArgs: args);

  Future<void> logHistory(int studentId, String type, String detail) async {
    await insert('student_history', {'student_id': studentId, 'event_type': type, 'detail': detail, 'event_date': DateTime.now().toIso8601String()});
  }

  Future<void> generateMonthlyInvoices() async {
    final db = await database;
    final now = DateTime.now();
    final month = monthKey(now);
    final students = await db.query('students', where: "status='Active'");
    for (final s in students) {
      final existing = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM invoices WHERE student_id=? AND billing_month=? AND is_manual=0', [s['id'], month])) ?? 0;
      if (existing > 0) continue;
      final fee = (s['monthly_fee'] as num).toDouble();
      final type = s['discount_type']?.toString() ?? 'None';
      final value = (s['discount_value'] as num?)?.toDouble() ?? 0;
      final discount = type == 'Percent' ? fee * value / 100 : type == 'Fixed' ? value : 0.0;
      final total = (fee - discount).clamp(0, double.infinity);
      final due = DateTime(now.year, now.month, 10);
      final invoiceNo = 'MHS-${DateFormat('yyyyMM').format(now)}-${s['id'].toString().padLeft(4, '0')}';
      await db.insert('invoices', {
        'invoice_no': invoiceNo,
        'student_id': s['id'],
        'title': '${DateFormat('MMMM yyyy').format(now)} Monthly Fee',
        'billing_month': month,
        'issue_date': ymd(DateTime(now.year, now.month, 1)),
        'due_date': ymd(due),
        'subtotal': fee,
        'discount': discount,
        'fine': 0,
        'total': total,
        'paid': 0,
        'status': ymd(due).compareTo(ymd(now)) < 0 ? 'Overdue' : 'Pending',
        'notes': 'Automatically generated monthly voucher',
        'is_manual': 0,
        'created_at': now.toIso8601String(),
      });
    }
    await refreshStatuses();
  }

  Future<void> refreshStatuses() async {
    final db = await database;
    final rows = await db.query('invoices');
    for (final r in rows) {
      final total = (r['total'] as num).toDouble();
      final paid = (r['paid'] as num).toDouble();
      String status;
      if (paid >= total && total > 0) {
        status = 'Paid';
      } else if (paid > 0) {
        status = 'Partial';
      } else if ((r['due_date'] as String).compareTo(ymd(DateTime.now())) < 0) {
        status = 'Overdue';
      } else {
        status = 'Pending';
      }
      await db.update('invoices', {'status': status}, where: 'id=?', whereArgs: [r['id']]);
    }
  }

  Future<String> backup() async {
    final db = await database;
    final docs = await getApplicationDocumentsDirectory();
    final file = p.join(docs.path, 'MHS_Backup_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.db');
    await File(db.path).copy(file);
    return file;
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool? logged;
  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) => setState(() => logged = p.getBool('logged') ?? false));
  }
  @override
  Widget build(BuildContext context) {
    if (logged == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return logged! ? HomeShell(onLogout: () => setState(() => logged = false)) : LoginPage(onLogin: () => setState(() => logged = true));
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.onLogin});
  final VoidCallback onLogin;
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      if (!mounted) return;
      setState(() {
        rememberMe = prefs.getBool('remember_me') ?? true;
        user.text = prefs.getString('saved_user') ?? loginUser;
      });
    });
  }

  final user = TextEditingController();
  final pass = TextEditingController();
  bool obscure = true;
  bool busy = false;
  bool rememberMe = true;

  Future<void> submit() async {
    if (user.text.trim() != loginUser || pass.text != loginPass) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Incorrect username or password.')));
      return;
    }
    setState(() => busy = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('logged', rememberMe);
    await prefs.setBool('remember_me', rememberMe);
    if (rememberMe) { await prefs.setString('saved_user', user.text.trim()); } else { await prefs.remove('saved_user'); }
    widget.onLogin();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF10172B), Color(0xFF352B75), Color(0xFF6D5DFB)]))),
          Positioned(top: -80, right: -50, child: _orb(220, Colors.pinkAccent.withValues(alpha: .28))),
          Positioned(bottom: -80, left: -50, child: _orb(260, Colors.cyanAccent.withValues(alpha: .20))),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: GlassCard(
                    padding: const EdgeInsets.all(28),
                    child: Column(children: [
                      Container(
                        width: 110,
                        height: 110,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), boxShadow: const [BoxShadow(blurRadius: 30, color: Colors.black26)]),
                        child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
                      ),
                      const SizedBox(height: 22),
                      const Text(schoolName, textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 6),
                      const Text('Offline School Fees Management', style: TextStyle(color: Colors.white70)),
                      const SizedBox(height: 30),
                      TextField(controller: user, style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w600), decoration: const InputDecoration(labelText: 'Username', prefixIcon: Icon(Icons.person_outline))),
                      const SizedBox(height: 14),
                      TextField(controller: pass, obscureText: obscure, style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w600), decoration: InputDecoration(labelText: 'Password', prefixIcon: const Icon(Icons.lock_outline), suffixIcon: IconButton(onPressed: () => setState(() => obscure = !obscure), icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined)))),
                      const SizedBox(height: 10),
                      Row(children: [Checkbox(value: rememberMe, activeColor: const Color(0xFF6D5DFB), onChanged: (v) => setState(() => rememberMe = v ?? true)), const Expanded(child: Text('Remember me', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)))]),
                      const SizedBox(height: 10),
                      SizedBox(width: double.infinity, height: 56, child: FilledButton(onPressed: busy ? null : submit, child: Text(busy ? 'Signing in...' : 'Sign In', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)))),
                      const SizedBox(height: 18),
                      const Text('Owner: $ownerName  •  $schoolPhone', textAlign: TextAlign.center, style: TextStyle(color: Colors.white60, fontSize: 12)),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _orb(double size, Color color) => Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, color: color));
}

class GlassCard extends StatelessWidget {
  const GlassCard({super.key, required this.child, this.padding = const EdgeInsets.all(18), this.onTap, this.color});
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(22);
    return Container(
      decoration: BoxDecoration(borderRadius: radius, boxShadow: const [BoxShadow(color: Color(0x140F172A), blurRadius: 26, offset: Offset(0, 10))]),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Material(
            color: color ?? Colors.white.withValues(alpha: .94),
            child: InkWell(
              onTap: onTap,
              borderRadius: radius,
              child: Container(
                padding: padding,
                decoration: BoxDecoration(borderRadius: radius, border: Border.all(color: Colors.white, width: 1.2), gradient: color == null ? const LinearGradient(colors: [Colors.white, Color(0xFFF8FAFC)], begin: Alignment.topLeft, end: Alignment.bottomRight) : null),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.onLogout});
  final VoidCallback onLogout;
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int index = 0;
  int tick = 0;
  void go(int value) => setState(() => index = value);
  void refresh() => setState(() => tick++);
  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardPage(key: ValueKey('d$tick'), navigate: go),
      StudentsPage(key: ValueKey('s$tick'), changed: refresh),
      SiblingsPage(key: ValueKey('g$tick')),
      FeesPage(key: ValueKey('f$tick'), changed: refresh),
      ReportsPage(key: ValueKey('r$tick')),
      SettingsPage(onLogout: widget.onLogout),
    ];
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        title: Row(children: [ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.asset('assets/images/logo.png', width: 40, height: 40)), const SizedBox(width: 10), const Expanded(child: Text('MHS Management', style: TextStyle(fontWeight: FontWeight.w900)))]),
        actions: [IconButton(onPressed: refresh, icon: const Icon(Icons.refresh_rounded))],
      ),
      body: SafeArea(child: pages[index]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: go,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard_rounded), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.groups_outlined), selectedIcon: Icon(Icons.groups_rounded), label: 'Students'),
          NavigationDestination(icon: Icon(Icons.family_restroom_outlined), selectedIcon: Icon(Icons.family_restroom_rounded), label: 'Siblings'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long_rounded), label: 'Fees'),
          NavigationDestination(icon: Icon(Icons.analytics_outlined), selectedIcon: Icon(Icons.analytics_rounded), label: 'Reports'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings_rounded), label: 'Settings'),
        ],
      ),
    );
  }
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key, required this.navigate});
  final ValueChanged<int> navigate;
  Future<Map<String, dynamic>> load() async {
    await AppDb.instance.refreshStatuses();
    final db = AppDb.instance;
    final students = Sqflite.firstIntValue(await db.raw("SELECT COUNT(*) FROM students WHERE status='Active'")) ?? 0;
    final siblings = Sqflite.firstIntValue(await db.raw("SELECT COUNT(*) FROM (SELECT father_name,father_cnic FROM students GROUP BY lower(father_name),replace(father_cnic,'-','') HAVING COUNT(*)>1)")) ?? 0;
    final inv = (await db.raw("SELECT COALESCE(SUM(total),0) total,COALESCE(SUM(paid),0) paid FROM invoices")).first;
    final today = (await db.raw("SELECT COALESCE(SUM(amount),0) value FROM payments WHERE payment_date=?", [ymd(DateTime.now())])).first['value'] as num;
    final month = (await db.raw("SELECT COALESCE(SUM(amount),0) value FROM payments WHERE substr(payment_date,1,7)=?", [monthKey(DateTime.now())])).first['value'] as num;
    final pending = Sqflite.firstIntValue(await db.raw("SELECT COUNT(*) FROM invoices WHERE status IN ('Pending','Partial')")) ?? 0;
    final overdue = Sqflite.firstIntValue(await db.raw("SELECT COUNT(*) FROM invoices WHERE status='Overdue'")) ?? 0;
    final chart = await db.raw("SELECT payment_date,SUM(amount) amount FROM payments WHERE payment_date>=? GROUP BY payment_date ORDER BY payment_date", [ymd(DateTime.now().subtract(const Duration(days: 6)))]);
    return {'students': students, 'siblings': siblings, 'total': inv['total'], 'paid': inv['paid'], 'today': today, 'month': month, 'pending': pending, 'overdue': overdue, 'chart': chart};
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: load(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final d = snap.data!;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF171F38), Color(0xFF6D5DFB)]), borderRadius: BorderRadius.circular(28)),
              child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Welcome, Dilshad', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)), SizedBox(height: 6), Text('School collection and student overview', style: TextStyle(color: Colors.white70))]),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(builder: (context, c) {
              final width = c.maxWidth;
              final count = width > 850 ? 4 : 2;
              final ratio = width > 850 ? 1.65 : 1.22;
              return GridView.count(
                crossAxisCount: count,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: ratio,
                children: [
                  StatCard('Students', '${d['students']}', Icons.groups_rounded, const Color(0xFF6D5DFB), () => navigate(1)),
                  StatCard('Sibling Families', '${d['siblings']}', Icons.family_restroom_rounded, const Color(0xFFEF5DA8), () => navigate(2)),
                  StatCard('Today', money(d['today']), Icons.today_rounded, const Color(0xFF00BFA6), () => navigate(4)),
                  StatCard('This Month', money(d['month']), Icons.calendar_month_rounded, const Color(0xFFFF9F43), () => navigate(4)),
                  StatCard('Pending', '${d['pending']}', Icons.pending_actions_rounded, const Color(0xFF4A90E2), () => navigate(3)),
                  StatCard('Overdue', '${d['overdue']}', Icons.warning_amber_rounded, const Color(0xFFE74C3C), () => navigate(3)),
                  StatCard('Total Billed', money(d['total'] as num), Icons.receipt_rounded, const Color(0xFF8E44AD), () => navigate(3)),
                  StatCard('Total Collected', money(d['paid'] as num), Icons.account_balance_wallet_rounded, const Color(0xFF27AE60), () => navigate(4)),
                ],
              );
            }),
            const SizedBox(height: 16),
            GlassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Last 7 Days Collection', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 18),
              SizedBox(height: 220, child: _chart((d['chart'] as List).cast<Map<String, dynamic>>())),
            ])),
          ],
        );
      },
    );
  }

  Widget _chart(List<Map<String, dynamic>> rows) {
    final map = {for (final r in rows) r['payment_date'].toString(): (r['amount'] as num).toDouble()};
    final days = List.generate(7, (i) => DateTime.now().subtract(Duration(days: 6 - i)));
    final values = [for (final day in days) map[ymd(day)] ?? 0];
    final max = values.fold<double>(0, (a, b) => b > a ? b : a);
    return BarChart(BarChartData(
      maxY: max <= 0 ? 100 : max * 1.25,
      gridData: const FlGridData(show: false),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, meta) => Text(DateFormat('E').format(days[v.toInt().clamp(0, 6)]), style: const TextStyle(fontSize: 11))))),
      barGroups: [for (var i = 0; i < values.length; i++) BarChartGroupData(x: i, barRods: [BarChartRodData(toY: values[i], width: 18, borderRadius: BorderRadius.circular(6), gradient: const LinearGradient(colors: [Color(0xFF6D5DFB), Color(0xFF9A8CFF)], begin: Alignment.bottomCenter, end: Alignment.topCenter))])],
    ));
  }
}

class StatCard extends StatelessWidget {
  const StatCard(this.title, this.value, this.icon, this.accent, this.tap, {super.key});
  final String title, value;
  final IconData icon;
  final Color accent;
  final VoidCallback tap;
  @override
  Widget build(BuildContext context) => GlassCard(onTap: tap, child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Container(padding: const EdgeInsets.all(9), decoration: BoxDecoration(color: accent.withValues(alpha: .13), borderRadius: BorderRadius.circular(13)), child: Icon(icon, color: accent)), const Icon(Icons.arrow_forward_rounded, size: 18, color: Colors.black38)]),
    FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900))),
    Text(title, style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w700)),
  ]));
}

class StudentsPage extends StatefulWidget {
  const StudentsPage({super.key, required this.changed});
  final VoidCallback changed;
  @override
  State<StudentsPage> createState() => _StudentsPageState();
}

class _StudentsPageState extends State<StudentsPage> {
  String search = '';
  String classFilter = 'All';
  Future<List<Map<String, dynamic>>> load() async {
    final args = <Object?>[];
    final where = <String>[];
    if (search.isNotEmpty) { where.add('(s.name LIKE ? OR s.admission_no LIKE ? OR s.father_name LIKE ? OR s.father_cnic LIKE ?)'); args.addAll(List.filled(4, '%$search%')); }
    if (classFilter != 'All') { where.add('s.class_name=?'); args.add(classFilter); }
    return AppDb.instance.raw('''SELECT s.*,(SELECT COUNT(*) FROM students x WHERE lower(x.father_name)=lower(s.father_name) AND replace(x.father_cnic,'-','')=replace(s.father_cnic,'-','')) sibling_count FROM students s ${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'} ORDER BY s.class_name,s.name''', args);
  }
  Future<List<String>> classes() async => ['All', ...(await AppDb.instance.raw('SELECT DISTINCT class_name FROM students ORDER BY class_name')).map((e) => e['class_name'].toString())];

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 12), child: Column(children: [
        TextField(onChanged: (v) => setState(() => search = v.trim()), decoration: const InputDecoration(hintText: 'Search student, admission no, father or CNIC', prefixIcon: Icon(Icons.search_rounded))),
        const SizedBox(height: 10),
        FutureBuilder<List<String>>(future: classes(), builder: (context, snap) => DropdownButtonFormField<String>(initialValue: classFilter, items: (snap.data ?? ['All']).map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setState(() => classFilter = v ?? 'All'), decoration: const InputDecoration(labelText: 'Class filter'))),
      ])),
      Expanded(child: FutureBuilder<List<Map<String, dynamic>>>(future: load(), builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        if (snap.data!.isEmpty) return const Center(child: Text('No students found'));
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
          itemCount: snap.data!.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final s = snap.data![i];
            return GlassCard(onTap: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => StudentHistoryPage(student: s))); setState(() {}); }, child: Row(children: [
              CircleAvatar(radius: 25, backgroundColor: const Color(0xFF6D5DFB).withValues(alpha: .12), child: Text(s['name'].toString().substring(0, 1).toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF6D5DFB)))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(s['name'], style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)), const SizedBox(height: 4), Text('${s['admission_no']} • ${s['class_name']}-${s['section'] ?? ''}', style: const TextStyle(color: Colors.black54)), Text('Father: ${s['father_name']} • Siblings: ${(s['sibling_count'] as num).toInt() - 1}', style: const TextStyle(color: Colors.black45, fontSize: 12))])),
              PopupMenuButton<String>(onSelected: (v) async {
                if (v == 'edit') await showStudentForm(context, student: s);
                if (v == 'delete') await confirmDeleteStudent(context, s);
                setState(() {}); widget.changed();
              }, itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('Edit student')), PopupMenuItem(value: 'delete', child: Text('Delete student'))]),
            ]));
          },
        );
      })),
      Padding(padding: const EdgeInsets.all(16), child: SizedBox(width: double.infinity, height: 52, child: FilledButton.icon(onPressed: () async { await showStudentForm(context); setState(() {}); widget.changed(); }, icon: const Icon(Icons.person_add_alt_1_rounded), label: const Text('Add Student')))),
    ]);
  }
}

Future<void> showStudentForm(BuildContext context, {Map<String, dynamic>? student}) async {
  final form = GlobalKey<FormState>();
  final c = <String, TextEditingController>{};
  TextEditingController ctl(String key) => c.putIfAbsent(key, () => TextEditingController(text: student?[key]?.toString() ?? ''));
  String gender = student?['gender']?.toString() ?? 'Male';
  String status = student?['status']?.toString() ?? 'Active';
  String discountType = student?['discount_type']?.toString() ?? 'None';
  await showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (sheetContext) => StatefulBuilder(builder: (context, setLocal) => DraggableScrollableSheet(initialChildSize: .92, maxChildSize: .96, minChildSize: .7, builder: (_, scroll) => Container(
    decoration: const BoxDecoration(color: Color(0xFFF5F6FB), borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
    child: Form(key: form, child: ListView(controller: scroll, padding: const EdgeInsets.all(20), children: [
      Row(children: [Expanded(child: Text(student == null ? 'New Student Admission' : 'Update Student', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900))), IconButton(onPressed: () => Navigator.pop(sheetContext), icon: const Icon(Icons.close))]),
      const SizedBox(height: 16),
      field(ctl('admission_no'), 'Admission Number', required: true),
      field(ctl('name'), 'Student Full Name', required: true),
      field(ctl('father_name'), 'Father Name', required: true),
      field(ctl('father_cnic'), 'Father CNIC Number', required: true, hint: '35202-1234567-1'),
      field(ctl('mother_name'), 'Mother Name'),
      field(ctl('guardian_phone'), 'Guardian Phone', required: true, keyboard: TextInputType.phone),
      field(ctl('alternate_phone'), 'Alternate Phone', keyboard: TextInputType.phone),
      field(ctl('student_bform'), 'Student B-Form/CNIC'),
      Row(children: [Expanded(child: DropdownButtonFormField<String>(initialValue: gender, decoration: const InputDecoration(labelText: 'Gender'), items: ['Male','Female','Other'].map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(), onChanged: (v) => setLocal(() => gender = v!))), const SizedBox(width: 10), Expanded(child: field(ctl('dob'), 'Date of Birth', hint: 'YYYY-MM-DD'))]),
      Row(children: [Expanded(child: field(ctl('class_name'), 'Class', required: true)), const SizedBox(width: 10), Expanded(child: field(ctl('section'), 'Section'))]),
      field(ctl('roll_no'), 'Roll Number'),
      field(ctl('admission_date'), 'Admission Date', required: true, hint: 'YYYY-MM-DD', defaultValue: ymd(DateTime.now())),
      field(ctl('address'), 'Complete Address', lines: 2),
      field(ctl('monthly_fee'), 'Monthly Fee (Rs)', required: true, keyboard: TextInputType.number),
      Row(children: [Expanded(child: DropdownButtonFormField<String>(initialValue: discountType, decoration: const InputDecoration(labelText: 'Discount Type'), items: ['None','Fixed','Percent'].map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(), onChanged: (v) => setLocal(() => discountType = v!))), const SizedBox(width: 10), Expanded(child: field(ctl('discount_value'), 'Discount Value', keyboard: TextInputType.number, defaultValue: '0'))]),
      DropdownButtonFormField<String>(initialValue: status, decoration: const InputDecoration(labelText: 'Student Status'), items: ['Active','Inactive','Left','Graduated'].map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(), onChanged: (v) => setLocal(() => status = v!)),
      const SizedBox(height: 12),
      field(ctl('notes'), 'Notes', lines: 3),
      const SizedBox(height: 16),
      SizedBox(height: 54, child: FilledButton(onPressed: () async {
        if (!form.currentState!.validate()) return;
        final now = DateTime.now().toIso8601String();
        final values = {
          'admission_no': ctl('admission_no').text.trim(), 'name': ctl('name').text.trim(), 'father_name': ctl('father_name').text.trim(), 'father_cnic': ctl('father_cnic').text.trim(),
          'mother_name': ctl('mother_name').text.trim(), 'guardian_phone': ctl('guardian_phone').text.trim(), 'alternate_phone': ctl('alternate_phone').text.trim(), 'student_bform': ctl('student_bform').text.trim(),
          'gender': gender, 'dob': ctl('dob').text.trim(), 'address': ctl('address').text.trim(), 'class_name': ctl('class_name').text.trim(), 'section': ctl('section').text.trim(), 'roll_no': ctl('roll_no').text.trim(),
          'admission_date': ctl('admission_date').text.trim(), 'status': status, 'monthly_fee': double.tryParse(ctl('monthly_fee').text) ?? 0, 'discount_type': discountType, 'discount_value': double.tryParse(ctl('discount_value').text) ?? 0,
          'notes': ctl('notes').text.trim(), 'updated_at': now,
        };
        try {
          int id;
          if (student == null) { values['created_at'] = now; id = await AppDb.instance.insert('students', values); await AppDb.instance.logHistory(id, 'Admission', 'Admitted in ${values['class_name']} on ${values['admission_date']}'); }
          else { id = student['id'] as int; await AppDb.instance.update('students', values, 'id=?', [id]); await AppDb.instance.logHistory(id, 'Update', 'Student record updated. Current class: ${values['class_name']}, status: $status'); }
          await AppDb.instance.generateMonthlyInvoices();
          if (sheetContext.mounted) Navigator.pop(sheetContext);
        } catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save: $e'))); }
      }, child: Text(student == null ? 'Save Admission' : 'Update Student'))),
      const SizedBox(height: 30),
    ])),
  ))));
}

Widget field(TextEditingController c, String label, {bool required = false, String? hint, int lines = 1, TextInputType? keyboard, String? defaultValue}) {
  if (c.text.isEmpty && defaultValue != null) c.text = defaultValue;
  return Padding(padding: const EdgeInsets.only(bottom: 12), child: TextFormField(controller: c, maxLines: lines, keyboardType: keyboard, decoration: InputDecoration(labelText: label, hintText: hint), validator: required ? (v) => v == null || v.trim().isEmpty ? '$label is required' : null : null));
}

Future<void> confirmDeleteStudent(BuildContext context, Map<String, dynamic> s) async {
  final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: const Text('Delete student?'), content: Text('This will delete ${s['name']} and all related invoices, payments and history.'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete'))])) ?? false;
  if (!ok) return;
  final db = await AppDb.instance.database;
  final invoices = await db.query('invoices', columns: ['id'], where: 'student_id=?', whereArgs: [s['id']]);
  for (final i in invoices) { await db.delete('payments', where: 'invoice_id=?', whereArgs: [i['id']]); }
  await db.delete('invoices', where: 'student_id=?', whereArgs: [s['id']]);
  await db.delete('student_history', where: 'student_id=?', whereArgs: [s['id']]);
  await db.delete('students', where: 'id=?', whereArgs: [s['id']]);
}

class StudentHistoryPage extends StatelessWidget {
  const StudentHistoryPage({super.key, required this.student});
  final Map<String, dynamic> student;
  Future<Map<String, dynamic>> load() async {
    final db = AppDb.instance;
    final siblings = await db.raw("SELECT * FROM students WHERE id<>? AND lower(father_name)=lower(?) AND replace(father_cnic,'-','')=replace(?,'-','') ORDER BY name", [student['id'], student['father_name'], student['father_cnic']]);
    final invoices = await db.raw('SELECT * FROM invoices WHERE student_id=? ORDER BY issue_date DESC,id DESC', [student['id']]);
    final history = await db.raw('SELECT * FROM student_history WHERE student_id=? ORDER BY event_date DESC', [student['id']]);
    final totals = (await db.raw('SELECT COALESCE(SUM(total),0) total,COALESCE(SUM(paid),0) paid FROM invoices WHERE student_id=?', [student['id']])).first;
    return {'siblings': siblings, 'invoices': invoices, 'history': history, 'total': totals['total'], 'paid': totals['paid']};
  }
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text(student['name'], style: const TextStyle(fontWeight: FontWeight.w900))), body: FutureBuilder<Map<String, dynamic>>(future: load(), builder: (context, snap) {
    if (!snap.hasData) return const Center(child: CircularProgressIndicator());
    final d = snap.data!; final due = (d['total'] as num) - (d['paid'] as num);
    return ListView(padding: const EdgeInsets.all(16), children: [
      GlassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${student['name']} • ${student['admission_no']}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)), const SizedBox(height: 8), Text('Class: ${student['class_name']}-${student['section']}   Status: ${student['status']}'), Text('Admission: ${student['admission_date']}'), Text('Father: ${student['father_name']} (${student['father_cnic']})')])),
      const SizedBox(height: 12),
      Row(children: [Expanded(child: StatCard('Total Fee', money(d['total'] as num), Icons.receipt_long, const Color(0xFF6D5DFB), () {})), const SizedBox(width: 10), Expanded(child: StatCard('Remaining', money(due), Icons.pending_actions, const Color(0xFFE74C3C), () {}))]),
      const SizedBox(height: 18),
      const Text('Siblings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
      const SizedBox(height: 8),
      if ((d['siblings'] as List).isEmpty) const Text('No sibling found with same father name and CNIC.') else ...(d['siblings'] as List<Map<String, dynamic>>).map((s) => Card(child: ListTile(leading: const Icon(Icons.family_restroom), title: Text(s['name']), subtitle: Text('${s['class_name']} • ${s['admission_no']}')))),
      const SizedBox(height: 18),
      const Text('Fee History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
      const SizedBox(height: 8),
      ...(d['invoices'] as List<Map<String, dynamic>>).map((i) => Card(child: ListTile(title: Text(i['title'], style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text('${i['invoice_no']} • Due ${i['due_date']}\nPaid ${money(i['paid'])} of ${money(i['total'])}'), trailing: StatusChip(i['status'])))),
      const SizedBox(height: 18),
      const Text('Student Timeline', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
      const SizedBox(height: 8),
      ...(d['history'] as List<Map<String, dynamic>>).map((h) => ListTile(leading: const Icon(Icons.history_rounded), title: Text(h['event_type'], style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text('${h['detail']}\n${h['event_date'].toString().substring(0, 16)}'))),
    ]);
  }));
}

class SiblingsPage extends StatefulWidget {
  const SiblingsPage({super.key});
  @override
  State<SiblingsPage> createState() => _SiblingsPageState();
}

class _SiblingsPageState extends State<SiblingsPage> {
  String search = '';
  Future<List<Map<String, dynamic>>> load() => AppDb.instance.raw(
    "SELECT father_name,father_cnic,guardian_phone,COUNT(*) child_count,SUM(monthly_fee) family_fee FROM students WHERE father_name LIKE ? OR father_cnic LIKE ? GROUP BY lower(father_name),replace(father_cnic,'-','') HAVING COUNT(*) > 1 ORDER BY father_name",
    ['%$search%', '%$search%'],
  );
  Future<List<Map<String, dynamic>>> members(Map<String,dynamic> family) => AppDb.instance.raw(
    "SELECT * FROM students WHERE lower(father_name)=lower(?) AND replace(father_cnic,'-','')=replace(?,'-','') ORDER BY class_name,name",
    [family['father_name'], family['father_cnic']],
  );
  @override
  Widget build(BuildContext context) => Column(children: [
    Padding(padding: const EdgeInsets.fromLTRB(16,8,16,12), child: TextField(onChanged: (v)=>setState(()=>search=v.trim()), decoration: const InputDecoration(hintText: 'Search father name or CNIC', prefixIcon: Icon(Icons.search_rounded)))),
    Expanded(child: FutureBuilder<List<Map<String,dynamic>>>(future: load(), builder: (context,snap){
      if(!snap.hasData) return const Center(child:CircularProgressIndicator());
      if(snap.data!.isEmpty) return const Center(child: Text('No sibling families found'));
      return ListView.separated(padding: const EdgeInsets.fromLTRB(16,0,16,28), itemCount:snap.data!.length, separatorBuilder:(_,__)=>const SizedBox(height:12), itemBuilder:(context,i){
        final f=snap.data![i];
        return GlassCard(child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(top:10),
          leading: Container(width:48,height:48,decoration:BoxDecoration(gradient:const LinearGradient(colors:[Color(0xFF7C3AED),Color(0xFFEC4899)]),borderRadius:BorderRadius.circular(15)),child:const Icon(Icons.family_restroom_rounded,color:Colors.white)),
          title: Text(f['father_name']?.toString() ?? '', style: const TextStyle(fontWeight:FontWeight.w900,color:Color(0xFF0F172A))),
          subtitle: Text('CNIC: ${f['father_cnic']} • ${f['child_count']} students\nFamily fee: ${money(f['family_fee'] as num)}'),
          children:[FutureBuilder<List<Map<String,dynamic>>>(future:members(f),builder:(_,m){
            if(!m.hasData) return const Padding(padding:EdgeInsets.all(16),child:CircularProgressIndicator());
            return Column(children:m.data!.map((st)=>Container(margin:const EdgeInsets.only(bottom:8),padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:const Color(0xFFF8FAFC),borderRadius:BorderRadius.circular(16),border:Border.all(color:const Color(0xFFE2E8F0))),child:Row(children:[CircleAvatar(backgroundColor:const Color(0xFFEDE9FE),child:Text(st['name'].toString().substring(0,1).toUpperCase(),style:const TextStyle(color:Color(0xFF6D28D9),fontWeight:FontWeight.w900))),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(st['name'],style:const TextStyle(fontWeight:FontWeight.w800)),Text('${st['class_name']} • ${st['admission_no']}')])),Text(money(st['monthly_fee'] as num),style:const TextStyle(fontWeight:FontWeight.w900))]))).toList());
          })],
        ));
      });
    }))
  ]);
}

class FeesPage extends StatefulWidget {
  const FeesPage({super.key, required this.changed});
  final VoidCallback changed;
  @override
  State<FeesPage> createState() => _FeesPageState();
}

class _FeesPageState extends State<FeesPage> {
  String status = 'All';
  String search = '';
  Future<List<Map<String, dynamic>>> load() async {
    await AppDb.instance.refreshStatuses();
    final where = <String>[]; final args = <Object?>[];
    if (status != 'All') { where.add('i.status=?'); args.add(status); }
    if (search.isNotEmpty) { where.add('(s.name LIKE ? OR i.invoice_no LIKE ? OR s.admission_no LIKE ?)'); args.addAll(List.filled(3, '%$search%')); }
    return AppDb.instance.raw('''SELECT i.*,s.name student_name,s.admission_no,s.class_name,s.section,s.guardian_phone,s.father_name FROM invoices i JOIN students s ON s.id=i.student_id ${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'} ORDER BY i.issue_date DESC,i.id DESC''', args);
  }
  @override
  Widget build(BuildContext context) => Column(children: [
    Padding(padding: const EdgeInsets.all(16), child: Column(children: [TextField(onChanged: (v) => setState(() => search = v.trim()), decoration: const InputDecoration(hintText: 'Search invoice or student', prefixIcon: Icon(Icons.search))), const SizedBox(height: 10), DropdownButtonFormField<String>(initialValue: status, decoration: const InputDecoration(labelText: 'Invoice status'), items: ['All','Paid','Pending','Partial','Overdue'].map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(), onChanged: (v) => setState(() => status = v!))])),
    Expanded(child: FutureBuilder<List<Map<String, dynamic>>>(future: load(), builder: (context, snap) {
      if (!snap.hasData) return const Center(child: CircularProgressIndicator());
      if (snap.data!.isEmpty) return const Center(child: Text('No invoices found'));
      return ListView.separated(padding: const EdgeInsets.fromLTRB(16, 0, 16, 100), itemCount: snap.data!.length, separatorBuilder: (_, __) => const SizedBox(height: 10), itemBuilder: (context, i) {
        final inv = snap.data![i];
        return GlassCard(onTap: () async { await showInvoiceActions(context, inv); setState(() {}); widget.changed(); }, child: Row(children: [
          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFF6D5DFB).withValues(alpha: .11), borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF6D5DFB))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(inv['student_name'], style: const TextStyle(fontWeight: FontWeight.w900)), Text('${inv['invoice_no']} • ${inv['class_name']}', style: const TextStyle(fontSize: 12, color: Colors.black54)), Text('${money(inv['paid'])} / ${money(inv['total'])}', style: const TextStyle(fontWeight: FontWeight.w800))])),
          StatusChip(inv['status']),
        ]));
      });
    })),
    Padding(padding: const EdgeInsets.all(16), child: LayoutBuilder(builder: (context,c) { final narrow=c.maxWidth<430; final generate=FilledButton.icon(onPressed: () async { await showBulkInvoiceGenerator(context); setState(() {}); widget.changed(); }, icon: const Icon(Icons.auto_awesome_rounded), label: const Text('Generate Vouchers')); final custom=FilledButton.tonalIcon(onPressed: () async { await showManualInvoice(context); setState(() {}); widget.changed(); }, icon: const Icon(Icons.add_rounded), label: const Text('Custom Invoice')); return narrow ? Column(children:[SizedBox(width:double.infinity,child:generate),const SizedBox(height:10),SizedBox(width:double.infinity,child:custom)]) : Row(children:[Expanded(child:generate),const SizedBox(width:10),Expanded(child:custom)]); })),
  ]);
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});
  final String status;
  @override
  Widget build(BuildContext context) {
    final color = switch (status) {'Paid' => const Color(0xFF1B9C85), 'Overdue' => const Color(0xFFE74C3C), 'Partial' => const Color(0xFFFF9F43), _ => const Color(0xFF4A90E2)};
    return Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(30)), child: Text(status, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900)));
  }
}

Future<void> showInvoiceActions(BuildContext context, Map<String, dynamic> inv) async {
  await showModalBottomSheet(context: context, showDragHandle: true, builder: (ctx) => SafeArea(child: Wrap(children: [
    ListTile(leading: const Icon(Icons.payments_rounded), title: const Text('Collect payment'), onTap: () async { Navigator.pop(ctx); await collectPayment(context, inv); }),
    ListTile(leading: const Icon(Icons.picture_as_pdf_rounded), title: const Text('View / print PDF voucher'), onTap: () async { Navigator.pop(ctx); await Printing.layoutPdf(onLayout: (_) => buildInvoicePdf(inv)); }),
    ListTile(leading: const Icon(Icons.share_rounded), title: const Text('Share PDF on WhatsApp'), onTap: () async { Navigator.pop(ctx); await shareInvoicePdf(inv); }),
    ListTile(leading: const Icon(Icons.image_rounded), title: const Text('Share voucher as image'), onTap: () async { Navigator.pop(ctx); await shareInvoiceImage(context, inv); }),
    ListTile(leading: const Icon(Icons.edit_rounded), title: const Text('Edit invoice'), onTap: () async { Navigator.pop(ctx); await showManualInvoice(context, invoice: inv); }),
    ListTile(leading: const Icon(Icons.delete_outline_rounded, color: Colors.red), title: const Text('Delete invoice', style: TextStyle(color: Colors.red)), onTap: () async { Navigator.pop(ctx); await deleteInvoice(context, inv); }),
  ])));
}

Future<void> collectPayment(BuildContext context, Map<String, dynamic> inv) async {
  final amount = TextEditingController(text: (((inv['total'] as num) - (inv['paid'] as num)).clamp(0, double.infinity)).toStringAsFixed(0));
  final reference = TextEditingController();
  String method = 'Cash';
  await showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (_, setLocal) => AlertDialog(title: Text('Collect fee • ${inv['student_name']}'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount')), const SizedBox(height: 10), DropdownButtonFormField<String>(initialValue: method, decoration: const InputDecoration(labelText: 'Method'), items: ['Cash','Bank','JazzCash','EasyPaisa','Other'].map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(), onChanged: (v) => setLocal(() => method = v!)), const SizedBox(height: 10), TextField(controller: reference, decoration: const InputDecoration(labelText: 'Reference / notes'))]), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')), FilledButton(onPressed: () async {
    final value = double.tryParse(amount.text) ?? 0; if (value <= 0) return;
    await AppDb.instance.insert('payments', {'invoice_id': inv['id'], 'amount': value, 'payment_date': ymd(DateTime.now()), 'method': method, 'reference': reference.text.trim(), 'notes': '', 'created_at': DateTime.now().toIso8601String()});
    final newPaid = (inv['paid'] as num).toDouble() + value;
    await AppDb.instance.update('invoices', {'paid': newPaid}, 'id=?', [inv['id']]);
    await AppDb.instance.refreshStatuses();
    await AppDb.instance.logHistory(inv['student_id'] as int, 'Fee payment', '${money(value)} received against ${inv['invoice_no']} by $method');
    if (ctx.mounted) Navigator.pop(ctx);
  }, child: const Text('Save Payment'))])));
}

Future<void> showBulkInvoiceGenerator(BuildContext context) async {
  final classes = (await AppDb.instance.raw("SELECT DISTINCT class_name FROM students WHERE status='Active' ORDER BY class_name")).map((e)=>e['class_name'].toString()).toList();
  final students = await AppDb.instance.raw("SELECT id,name,admission_no,class_name,monthly_fee,discount_type,discount_value FROM students WHERE status='Active' ORDER BY class_name,name");
  if (students.isEmpty) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add active students first.'))); return; }
  String scope='All Students'; String? selectedClass; int? selectedStudent; int months=1; DateTime start=DateTime(DateTime.now().year,DateTime.now().month); int dueDay=10;
  await showDialog(context:context,builder:(ctx)=>StatefulBuilder(builder:(_,setLocal)=>AlertDialog(scrollable:true,title:const Text('Generate Fee Vouchers'),content:SizedBox(width:460,child:Column(children:[
    DropdownButtonFormField<String>(initialValue:scope,decoration:const InputDecoration(labelText:'Generate for'),items:['All Students','Class Wise','Single Student'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(v)=>setLocal(()=>scope=v!)),
    if(scope=='Class Wise') ...[const SizedBox(height:12),DropdownButtonFormField<String>(initialValue:selectedClass,decoration:const InputDecoration(labelText:'Select class'),items:classes.map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(v)=>setLocal(()=>selectedClass=v))],
    if(scope=='Single Student') ...[const SizedBox(height:12),DropdownButtonFormField<int>(initialValue:selectedStudent,decoration:const InputDecoration(labelText:'Select student'),items:students.map((x)=>DropdownMenuItem(value:x['id'] as int,child:Text('${x['name']} • ${x['class_name']}'))).toList(),onChanged:(v)=>setLocal(()=>selectedStudent=v))],
    const SizedBox(height:12),DropdownButtonFormField<int>(initialValue:months,decoration:const InputDecoration(labelText:'Number of months'),items:[1,2,3,4,5,6,12].map((x)=>DropdownMenuItem(value:x,child:Text(x==12?'Complete year (12 months)':'$x month${x>1?'s':''}'))).toList(),onChanged:(v)=>setLocal(()=>months=v!)),
    const SizedBox(height:12),ListTile(contentPadding:EdgeInsets.zero,title:const Text('Starting month',style:TextStyle(fontWeight:FontWeight.w700)),subtitle:Text(DateFormat('MMMM yyyy').format(start)),trailing:const Icon(Icons.calendar_month_rounded),onTap:() async { final d=await showDatePicker(context:ctx,firstDate:DateTime(2020),lastDate:DateTime(2035),initialDate:start); if(d!=null)setLocal(()=>start=DateTime(d.year,d.month)); }),
    const SizedBox(height:4),DropdownButtonFormField<int>(initialValue:dueDay,decoration:const InputDecoration(labelText:'Due day'),items:[5,10,15,20,25,28].map((x)=>DropdownMenuItem(value:x,child:Text('$x of every month'))).toList(),onChanged:(v)=>setLocal(()=>dueDay=v!)),
  ])),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cancel')),FilledButton.icon(icon:const Icon(Icons.check_rounded),label:const Text('Generate'),onPressed:() async {
    if(scope=='Class Wise' && selectedClass==null) return; if(scope=='Single Student' && selectedStudent==null) return;
    final targets=students.where((st)=>scope=='All Students'||(scope=='Class Wise'&&st['class_name']==selectedClass)||(scope=='Single Student'&&st['id']==selectedStudent)).toList(); int created=0;
    for(final st in targets){ for(int m=0;m<months;m++){ final date=DateTime(start.year,start.month+m); final key=monthKey(date); final exists=Sqflite.firstIntValue(await AppDb.instance.raw('SELECT COUNT(*) FROM invoices WHERE student_id=? AND billing_month=?',[st['id'],key]))??0; if(exists>0)continue; final fee=(st['monthly_fee'] as num).toDouble(); final type=st['discount_type']?.toString()??'None'; final val=(st['discount_value'] as num?)?.toDouble()??0; final dis=type=='Percent'?fee*val/100:type=='Fixed'?val:0.0; final total=(fee-dis).clamp(0,double.infinity); final due=DateTime(date.year,date.month,dueDay.clamp(1,28)); await AppDb.instance.insert('invoices',{'invoice_no':'MHS-${DateFormat('yyyyMM').format(date)}-${st['id'].toString().padLeft(4,'0')}','student_id':st['id'],'title':'${DateFormat('MMMM yyyy').format(date)} Monthly Fee','billing_month':key,'issue_date':ymd(DateTime(date.year,date.month,1)),'due_date':ymd(due),'subtotal':fee,'discount':dis,'fine':0.0,'total':total,'paid':0.0,'status':due.isBefore(DateTime.now())?'Overdue':'Pending','notes':'Generated from voucher generator','is_manual':0,'created_at':DateTime.now().toIso8601String()}); created++; } }
    if(ctx.mounted)Navigator.pop(ctx); if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$created voucher(s) generated successfully.')));
  })])));
}

Future<void> showManualInvoice(BuildContext context, {Map<String, dynamic>? invoice}) async {
  final students = await AppDb.instance.raw("SELECT id,name,admission_no,monthly_fee FROM students WHERE status='Active' ORDER BY name");
  if (students.isEmpty) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add a student first.'))); return; }
  int studentId = invoice?['student_id'] as int? ?? students.first['id'] as int;
  final title = TextEditingController(text: invoice?['title']?.toString() ?? 'Custom Fee Voucher');
  final subtotal = TextEditingController(text: invoice?['subtotal']?.toString() ?? '0');
  final discount = TextEditingController(text: invoice?['discount']?.toString() ?? '0');
  final fine = TextEditingController(text: invoice?['fine']?.toString() ?? '0');
  final due = TextEditingController(text: invoice?['due_date']?.toString() ?? ymd(DateTime.now().add(const Duration(days: 10))));
  final notes = TextEditingController(text: invoice?['notes']?.toString() ?? '');
  await showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (_, setLocal) => AlertDialog(scrollable: true, title: Text(invoice == null ? 'Create Custom Invoice' : 'Edit Invoice'), content: Column(children: [
    DropdownButtonFormField<int>(initialValue: studentId, decoration: const InputDecoration(labelText: 'Student'), items: students.map((s) => DropdownMenuItem(value: s['id'] as int, child: Text('${s['name']} • ${s['admission_no']}'))).toList(), onChanged: (v) => setLocal(() => studentId = v!)),
    const SizedBox(height: 10), TextField(controller: title, decoration: const InputDecoration(labelText: 'Invoice title')), const SizedBox(height: 10), TextField(controller: subtotal, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount')), const SizedBox(height: 10), TextField(controller: discount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Discount')), const SizedBox(height: 10), TextField(controller: fine, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Fine')), const SizedBox(height: 10), TextField(controller: due, decoration: const InputDecoration(labelText: 'Due date YYYY-MM-DD')), const SizedBox(height: 10), TextField(controller: notes, maxLines: 2, decoration: const InputDecoration(labelText: 'Notes')),
  ]), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')), FilledButton(onPressed: () async {
    final sub = double.tryParse(subtotal.text) ?? 0; final dis = double.tryParse(discount.text) ?? 0; final f = double.tryParse(fine.text) ?? 0; final total = (sub - dis + f).clamp(0, double.infinity);
    final values = {'student_id': studentId, 'title': title.text.trim(), 'billing_month': invoice?['billing_month'], 'issue_date': invoice?['issue_date'] ?? ymd(DateTime.now()), 'due_date': due.text.trim(), 'subtotal': sub, 'discount': dis, 'fine': f, 'total': total, 'notes': notes.text.trim(), 'is_manual': 1};
    if (invoice == null) { values.addAll({'invoice_no': 'MHS-C-${DateTime.now().millisecondsSinceEpoch}', 'paid': 0.0, 'status': due.text.compareTo(ymd(DateTime.now())) < 0 ? 'Overdue' : 'Pending', 'created_at': DateTime.now().toIso8601String()}); await AppDb.instance.insert('invoices', values); await AppDb.instance.logHistory(studentId, 'Custom invoice', '${title.text} created for ${money(total)}'); }
    else { await AppDb.instance.update('invoices', values, 'id=?', [invoice['id']]); await AppDb.instance.logHistory(studentId, 'Invoice update', '${invoice['invoice_no']} updated'); }
    if (ctx.mounted) Navigator.pop(ctx);
  }, child: const Text('Save'))])));
}

Future<void> deleteInvoice(BuildContext context, Map<String, dynamic> inv) async {
  final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: const Text('Delete invoice?'), content: Text('Delete ${inv['invoice_no']} and its payments?'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete'))])) ?? false;
  if (!ok) return;
  await AppDb.instance.delete('payments', 'invoice_id=?', [inv['id']]);
  await AppDb.instance.delete('invoices', 'id=?', [inv['id']]);
  await AppDb.instance.logHistory(inv['student_id'] as int, 'Invoice deleted', '${inv['invoice_no']} deleted');
}

Future<Uint8List> buildInvoicePdf(Map<String, dynamic> inv) async {
  final logo = await imageFromAssetBundle('assets/images/logo.png');
  final doc = pw.Document();
  final total = (inv['total'] as num).toDouble(); final paid = (inv['paid'] as num).toDouble(); final balance = total - paid;
  doc.addPage(pw.Page(pageFormat: PdfPageFormat.a4, margin: const pw.EdgeInsets.all(34), theme: pw.ThemeData.withFont(base: pw.Font.helvetica(), bold: pw.Font.helveticaBold()), build: (_) => pw.Container(color: PdfColors.white, child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
    pw.Container(padding: const pw.EdgeInsets.all(18), decoration: pw.BoxDecoration(color: PdfColor.fromHex('#171F38'), borderRadius: pw.BorderRadius.circular(12)), child: pw.Row(children: [pw.Container(width: 70, height: 70, color: PdfColors.white, padding: const pw.EdgeInsets.all(5), child: pw.Image(logo)), pw.SizedBox(width: 16), pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [pw.Text(schoolName, style: pw.TextStyle(color: PdfColors.white, fontSize: 20, fontWeight: pw.FontWeight.bold)), pw.Text('Owner: $ownerName  |  $schoolPhone', style: const pw.TextStyle(color: PdfColors.white, fontSize: 10))]))])),
    pw.SizedBox(height: 24),
    pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('FEE VOUCHER / INVOICE', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)), pw.Container(padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: pw.BoxDecoration(color: inv['status'] == 'Paid' ? PdfColors.green100 : PdfColors.orange100, borderRadius: pw.BorderRadius.circular(20)), child: pw.Text(inv['status'], style: pw.TextStyle(fontWeight: pw.FontWeight.bold)))]),
    pw.SizedBox(height: 16),
    pw.Table(columnWidths: {0: const pw.FlexColumnWidth(1), 1: const pw.FlexColumnWidth(2)}, border: pw.TableBorder.all(color: PdfColors.grey300), children: [
      rowPdf('Invoice No', inv['invoice_no']), rowPdf('Student', inv['student_name'] ?? ''), rowPdf('Admission No', inv['admission_no'] ?? ''), rowPdf('Class', '${inv['class_name'] ?? ''}-${inv['section'] ?? ''}'), rowPdf('Father', inv['father_name'] ?? ''), rowPdf('Issue Date', inv['issue_date']), rowPdf('Due Date', inv['due_date']), rowPdf('Description', inv['title']),
    ]),
    pw.SizedBox(height: 20),
    pw.Table(columnWidths: {0: const pw.FlexColumnWidth(3), 1: const pw.FlexColumnWidth(1)}, border: pw.TableBorder.all(color: PdfColors.grey300), children: [
      rowPdf('Subtotal', money(inv['subtotal'])), rowPdf('Discount', money(inv['discount'])), rowPdf('Fine', money(inv['fine'])), rowPdf('Total', money(total), bold: true), rowPdf('Paid', money(paid)), rowPdf('Remaining', money(balance), bold: true),
    ]),
    pw.Spacer(), pw.Divider(), pw.Text('This is a computer-generated school fee voucher.', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)), pw.Text('For queries: $schoolPhone', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
  ]))));
  return doc.save();
}

pw.TableRow rowPdf(String a, String b, {bool bold = false}) => pw.TableRow(children: [pw.Padding(padding: const pw.EdgeInsets.all(9), child: pw.Text(a, style: pw.TextStyle(fontWeight: pw.FontWeight.bold))), pw.Padding(padding: const pw.EdgeInsets.all(9), child: pw.Text(b, style: pw.TextStyle(fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)))]);

Future<void> shareInvoicePdf(Map<String, dynamic> inv) async {
  final bytes = await buildInvoicePdf(inv); final dir = await getTemporaryDirectory(); final path = p.join(dir.path, '${inv['invoice_no']}.pdf'); await File(path).writeAsBytes(bytes);
  await SharePlus.instance.share(ShareParams(files: [XFile(path)], text: 'Fee voucher for ${inv['student_name']} - ${inv['invoice_no']}'));
}

Future<void> shareInvoiceImage(BuildContext context, Map<String, dynamic> inv) async {
  final bytes = await buildInvoicePdf(inv); final raster = await Printing.raster(bytes, pages: [0], dpi: 240).first; final png = await raster.toPng(); final dir = await getTemporaryDirectory(); final path = p.join(dir.path, '${inv['invoice_no']}.png'); await File(path).writeAsBytes(png);
  await SharePlus.instance.share(ShareParams(files: [XFile(path)], text: 'Fee voucher for ${inv['student_name']}'));
}

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});
  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  String period = 'Monthly'; String className = 'All'; int? studentId; String sibling = 'All'; DateTime from = DateTime(DateTime.now().year, DateTime.now().month, 1); DateTime to = DateTime.now();
  Future<Map<String, dynamic>> load() async {
    DateTime f = from, t = to;
    if (period == 'Daily') f = DateTime.now();
    if (period == 'Weekly') f = DateTime.now().subtract(const Duration(days: 6));
    if (period == 'Monthly') f = DateTime(DateTime.now().year, DateTime.now().month, 1);
    if (period == 'Yearly') f = DateTime(DateTime.now().year, 1, 1);
    final conditions = ['p.payment_date BETWEEN ? AND ?']; final args = <Object?>[ymd(f), ymd(t)];
    if (className != 'All') { conditions.add('s.class_name=?'); args.add(className); }
    if (studentId != null) { conditions.add('s.id=?'); args.add(studentId); }
    if (sibling == 'Sibling only') conditions.add("(SELECT COUNT(*) FROM students x WHERE lower(x.father_name)=lower(s.father_name) AND replace(x.father_cnic,'-','')=replace(s.father_cnic,'-',''))>1");
    final rows = await AppDb.instance.raw('''SELECT p.payment_date,p.amount,p.method,i.invoice_no,i.title,s.name student_name,s.admission_no,s.class_name,s.father_name,s.father_cnic FROM payments p JOIN invoices i ON i.id=p.invoice_id JOIN students s ON s.id=i.student_id WHERE ${conditions.join(' AND ')} ORDER BY p.payment_date DESC''', args);
    final total = rows.fold<double>(0, (a, b) => a + (b['amount'] as num).toDouble());
    return {'rows': rows, 'total': total, 'from': f, 'to': t};
  }
  Future<List<Map<String,dynamic>>> students() => AppDb.instance.raw('SELECT id,name,admission_no FROM students ORDER BY name');
  Future<List<String>> classes() async => ['All', ...(await AppDb.instance.raw('SELECT DISTINCT class_name FROM students ORDER BY class_name')).map((e) => e['class_name'].toString())];
  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String,dynamic>>(future: load(), builder: (context, snap) {
    final data = snap.data;
    return ListView(padding: const EdgeInsets.all(16), children: [
      GlassCard(child: Column(children: [
        DropdownButtonFormField<String>(initialValue: period, decoration: const InputDecoration(labelText: 'Period'), items: ['Daily','Weekly','Monthly','Yearly','Custom'].map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(), onChanged: (v) => setState(() => period = v!)), const SizedBox(height: 10),
        FutureBuilder<List<String>>(future: classes(), builder: (_, s) => DropdownButtonFormField<String>(initialValue: className, decoration: const InputDecoration(labelText: 'Class'), items: (s.data ?? ['All']).map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(), onChanged: (v) => setState(() => className = v!))), const SizedBox(height: 10),
        FutureBuilder<List<Map<String,dynamic>>>(future: students(), builder: (_, s) => DropdownButtonFormField<int?>(initialValue: studentId, decoration: const InputDecoration(labelText: 'Student'), items: [const DropdownMenuItem<int?>(value: null, child: Text('All students')), ...(s.data ?? []).map((x) => DropdownMenuItem<int?>(value: x['id'] as int, child: Text('${x['name']} • ${x['admission_no']}')))], onChanged: (v) => setState(() => studentId = v))), const SizedBox(height: 10),
        DropdownButtonFormField<String>(initialValue: sibling, decoration: const InputDecoration(labelText: 'Sibling filter'), items: ['All','Sibling only'].map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(), onChanged: (v) => setState(() => sibling = v!)),
        if (period == 'Custom') ...[const SizedBox(height: 10), Row(children: [Expanded(child: OutlinedButton(onPressed: () async { final d = await showDatePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime.now(), initialDate: from); if (d != null) setState(() => from = d); }, child: Text('From ${ymd(from)}'))), const SizedBox(width: 8), Expanded(child: OutlinedButton(onPressed: () async { final d = await showDatePicker(context: context, firstDate: from, lastDate: DateTime.now(), initialDate: to); if (d != null) setState(() => to = d); }, child: Text('To ${ymd(to)}')))]),],
      ])),
      const SizedBox(height: 14),
      if (data == null) const Center(child: CircularProgressIndicator()) else ...[
        StatCard('Collected', money(data['total']), Icons.account_balance_wallet_rounded, const Color(0xFF1B9C85), () {}),
        const SizedBox(height: 14),
        Row(children: [Expanded(child: FilledButton.icon(onPressed: () => exportReportPdf(data), icon: const Icon(Icons.picture_as_pdf), label: const Text('PDF'))), const SizedBox(width: 10), Expanded(child: FilledButton.tonalIcon(onPressed: () => exportReportExcel(data), icon: const Icon(Icons.table_chart), label: const Text('Excel')))]),
        const SizedBox(height: 14),
        if ((data['rows'] as List).isEmpty) const Center(child: Padding(padding: EdgeInsets.all(30), child: Text('No payments in selected filters'))) else ...(data['rows'] as List<Map<String,dynamic>>).map((r) => Card(child: ListTile(title: Text(r['student_name'], style: const TextStyle(fontWeight: FontWeight.w900)), subtitle: Text('${r['payment_date']} • ${r['class_name']} • ${r['invoice_no']}'), trailing: Text(money(r['amount']), style: const TextStyle(fontWeight: FontWeight.w900))))),
      ],
    ]);
  });
}

Future<void> exportReportPdf(Map<String,dynamic> data) async {
  final doc = pw.Document(); final rows = (data['rows'] as List<Map<String,dynamic>>);
  doc.addPage(pw.MultiPage(build: (_) => [pw.Text('$schoolName - Collection Report', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)), pw.Text('${ymd(data['from'])} to ${ymd(data['to'])}'), pw.SizedBox(height: 15), pw.TableHelper.fromTextArray(headers: ['Date','Student','Class','Invoice','Method','Amount'], data: rows.map((r) => [r['payment_date'],r['student_name'],r['class_name'],r['invoice_no'],r['method'],money(r['amount'])]).toList()), pw.SizedBox(height: 15), pw.Text('Total: ${money(data['total'])}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))]));
  final bytes = await doc.save(); final dir = await getTemporaryDirectory(); final path = p.join(dir.path, 'MHS_Report_${DateTime.now().millisecondsSinceEpoch}.pdf'); await File(path).writeAsBytes(bytes); await SharePlus.instance.share(ShareParams(files: [XFile(path)]));
}

Future<void> exportReportExcel(Map<String,dynamic> data) async {
  final book = ex.Excel.createExcel(); final sheet = book['Collection Report']; sheet.appendRow(['Date','Student','Admission No','Class','Father','Invoice','Method','Amount'].map(ex.TextCellValue.new).toList());
  for (final r in (data['rows'] as List<Map<String,dynamic>>)) { sheet.appendRow([r['payment_date'],r['student_name'],r['admission_no'],r['class_name'],r['father_name'],r['invoice_no'],r['method'],r['amount'].toString()].map((x) => ex.TextCellValue(x.toString())).toList()); }
  final bytes = book.encode(); if (bytes == null) return; final dir = await getTemporaryDirectory(); final path = p.join(dir.path, 'MHS_Report_${DateTime.now().millisecondsSinceEpoch}.xlsx'); await File(path).writeAsBytes(bytes); await SharePlus.instance.share(ShareParams(files: [XFile(path)]));
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.onLogout});
  final VoidCallback onLogout;
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final developer = TextEditingController(); final copyright = TextEditingController();
  @override
  void initState() { super.initState(); AppDb.instance.raw('SELECT * FROM settings').then((rows) { for (final r in rows) { if (r['key']=='developer_info') developer.text=r['value']?.toString()??''; if (r['key']=='copyright') copyright.text=r['value']?.toString()??''; } if (mounted) setState(() {}); }); }
  Future<void> save() async { final db = await AppDb.instance.database; await db.insert('settings', {'key':'developer_info','value':developer.text}, conflictAlgorithm: ConflictAlgorithm.replace); await db.insert('settings', {'key':'copyright','value':copyright.text}, conflictAlgorithm: ConflictAlgorithm.replace); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings saved'))); }
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(16), children: [
    GlassCard(child: Column(children: [Image.asset('assets/images/logo.png', height: 100), const SizedBox(height: 12), const Text(schoolName, textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)), const Text('Owner: $ownerName'), const Text(schoolPhone)])),
    const SizedBox(height: 14),
    GlassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Developer & Copyright', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)), const SizedBox(height: 12), TextField(controller: developer, decoration: const InputDecoration(labelText: 'Developer information')), const SizedBox(height: 10), TextField(controller: copyright, maxLines: 2, decoration: const InputDecoration(labelText: 'Copyright text')), const SizedBox(height: 12), SizedBox(width: double.infinity, child: FilledButton(onPressed: save, child: const Text('Save information')))])),
    const SizedBox(height: 14),
    GlassCard(child: Column(children: [ListTile(leading: const Icon(Icons.backup_rounded), title: const Text('Backup SQLite database'), subtitle: const Text('Share an offline database backup'), onTap: () async { final path = await AppDb.instance.backup(); await SharePlus.instance.share(ShareParams(files: [XFile(path)])); }), ListTile(leading: const Icon(Icons.autorenew_rounded), title: const Text('Generate current month vouchers'), onTap: () async { await AppDb.instance.generateMonthlyInvoices(); if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Monthly vouchers checked/generated'))); }), ListTile(leading: const Icon(Icons.logout_rounded, color: Colors.red), title: const Text('Logout', style: TextStyle(color: Colors.red)), onTap: () async { final p = await SharedPreferences.getInstance(); await p.setBool('logged', false); widget.onLogout(); })])),
    const SizedBox(height: 16), Text(developer.text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black45)), Text(copyright.text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black45, fontSize: 12)), const SizedBox(height: 30),
  ]);
}
