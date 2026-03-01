import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';

void main() {
  runApp(const ESSApp());
}

class ESSApp extends StatelessWidget {
  const ESSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ESS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}

// ============== CONFIG ==============
class AppConfig {
  static const String baseUrl = 'https://rr8787m.k.frappe.cloud/api';
  static const String apiKey = '252fdac49f44954';
  static const String apiSecret = '17952959c4ba8d1';
  
  static Map<String, String> get headers => {
    'Content-Type': 'application/json',
    'Authorization': 'token $apiKey:$apiSecret',
  };
}

// ============== LOGIN SCREEN ==============
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/method/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'usr': _emailController.text,
          'pwd': _passwordController.text,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['message'] == 'Logged In') {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_email', _emailController.text);
          
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const HomeScreen()),
            );
          }
        }
      } else {
        setState(() => _error = 'Invalid credentials');
      }
    } catch (e) {
      setState(() => _error = 'Connection error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.business, size: 80, color: Colors.blue),
              const SizedBox(height: 16),
              const Text(
                'ESS',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),
              const Text(
                'Employee Self Service',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 48),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
                obscureText: true,
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Login', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============== HOME SCREEN ==============
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? _employee;
  List<dynamic> _attendance = [];
  bool _isLoading = true;
  bool _isClockingIn = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      final empRes = await http.get(
        Uri.parse('${AppConfig.baseUrl}/resource/Employee?limit=1'),
        headers: AppConfig.headers,
      );
      
      if (empRes.statusCode == 200) {
        final empData = jsonDecode(empRes.body);
        if (empData['data'].isNotEmpty) {
          _employee = empData['data'][0];
          
          final today = DateTime.now().toIso8601String().split('T')[0];
          final attRes = await http.get(
            Uri.parse('${AppConfig.baseUrl}/resource/Attendance?filters=[["attendance_date","=","$today"]]'),
            headers: AppConfig.headers,
          );
          
          if (attRes.statusCode == 200) {
            _attendance = jsonDecode(attRes.body)['data'] ?? [];
          }
        }
      }
    } catch (e) {
      debugPrint('Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _clockIn() async {
    if (_employee == null) return;
    
    setState(() => _isClockingIn = true);
    
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      
      Position? position;
      if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        position = await Geolocator.getCurrentPosition();
      }
      
      final now = DateTime.now();
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/resource/Attendance'),
        headers: AppConfig.headers,
        body: jsonEncode({
          'employee': _employee!['name'],
          'attendance_date': now.toIso8601String().split('T')[0],
          'status': 'Present',
          'in_time': now.toIso8601String(),
          'company': _employee!['company'] ?? 'Test',
        }),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Clocked in successfully!')),
          );
          _loadData();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      setState(() => _isClockingIn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ESS Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Employee Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 30,
                                backgroundColor: Colors.blue[100],
                                child: Text(
                                  (_employee?['employee_name'] ?? 'E')[0].toString().toUpperCase(),
                                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _employee?['employee_name'] ?? 'Employee',
                                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      _employee?['designation'] ?? '',
                                      style: TextStyle(color: Colors.grey[600]),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Clock In Button
                  if (_attendance.isEmpty)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isClockingIn ? null : _clockIn,
                        icon: _isClockingIn
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.login),
                        label: Text(_isClockingIn ? 'Clocking In...' : 'Clock In', style: const TextStyle(fontSize: 18)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 20),
                        ),
                      ),
                    )
                  else
                    Card(
                      color: Colors.green[50],
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle, color: Colors.green, size: 40),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Already Clocked In', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                  Text('Date: ${_attendance.isNotEmpty ? _attendance[0]['attendance_date'] : ''}'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  
                  const SizedBox(height: 24),
                  
                  // Quick Actions
                  const Text('Quick Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _ActionCard(icon: Icons.beach_access, label: 'Leave', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LeaveScreen())))),
                      const SizedBox(width: 12),
                      Expanded(child: _ActionCard(icon: Icons.receipt_long, label: 'Payroll', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PayrollScreen())))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _ActionCard(icon: Icons.history, label: 'Attendance', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceHistoryScreen())))),
                      const SizedBox(width: 12),
                      Expanded(child: _ActionCard(icon: Icons.person, label: 'Profile', onTap: () {})),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionCard({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(icon, size: 40, color: Colors.blue),
              const SizedBox(height: 8),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}

// ============== LEAVE SCREEN ==============
class LeaveScreen extends StatefulWidget {
  const LeaveScreen({super.key});

  @override
  State<LeaveScreen> createState() => _LeaveScreenState();
}

class _LeaveScreenState extends State<LeaveScreen> {
  List<dynamic> _leaveTypes = [];
  List<dynamic> _leaveRequests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final typeRes = await http.get(Uri.parse('${AppConfig.baseUrl}/resource/Leave%20Type'), headers: AppConfig.headers);
      if (typeRes.statusCode == 200) {
        _leaveTypes = jsonDecode(typeRes.body)['data'] ?? [];
      }
      
      final reqRes = await http.get(Uri.parse('${AppConfig.baseUrl}/resource/Leave%20Application?limit=10'), headers: AppConfig.headers);
      if (reqRes.statusCode == 200) {
        _leaveRequests = jsonDecode(reqRes.body)['data'] ?? [];
      }
    } catch (e) {
      debugPrint('Error: $e');
    }
    setState(() => _isLoading = false);
  }

  void _showNewRequestDialog() {
    String? selectedType;
    DateTime? startDate;
    DateTime? endDate;
    final reasonController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('New Leave Request', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Leave Type', border: OutlineInputBorder()),
                items: _leaveTypes.map((t) => DropdownMenuItem(value: t['name'], child: Text(t['name']))).toList(),
                onChanged: (v) => setModalState(() => selectedType = v),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: TextButton(onPressed: () async {
                    final d = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                    if (d != null) setModalState(() => startDate = d);
                  }, child: Text(startDate != null ? '${startDate!.day}/${startDate!.month}/${startDate!.year}' : 'Start Date'))),
                  Expanded(child: TextButton(onPressed: () async {
                    final d = await showDatePicker(context: context, initialDate: startDate ?? DateTime.now(), firstDate: startDate ?? DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                    if (d != null) setModalState(() => endDate = d);
                  }, child: Text(endDate != null ? '${endDate!.day}/${endDate!.month}/${endDate!.year}' : 'End Date'))),
                ],
              ),
              const SizedBox(height: 12),
              TextField(controller: reasonController, decoration: const InputDecoration(labelText: 'Reason', border: OutlineInputBorder()), maxLines: 3),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: selectedType != null && startDate != null ? () async {
                    try {
                      await http.post(Uri.parse('${AppConfig.baseUrl}/resource/Leave%20Application'), headers: AppConfig.headers, body: jsonEncode({
                        'employee': 'HR-EMP-00001',
                        'leave_type': selectedType,
                        'from_date': startDate!.toIso8601String().split('T')[0],
                        'to_date': (endDate ?? startDate!).toIso8601String().split('T')[0],
                        'reason': reasonController.text,
                        'status': 'Open',
                      }));
                      if (mounted) Navigator.pop(context);
                      _loadData();
                    } catch (e) {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                  } : null,
                  child: const Text('Submit Request'),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Leave Requests')),
      floatingActionButton: FloatingActionButton(onPressed: _showNewRequestDialog, child: const Icon(Icons.add)),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _leaveRequests.length,
        itemBuilder: (context, index) {
          final leave = _leaveRequests[index];
          Color statusColor;
          switch (leave['status']) {
            case 'Approved': statusColor = Colors.green; break;
            case 'Rejected': statusColor = Colors.red; break;
            default: statusColor = Colors.orange;
          }
          return Card(
            child: ListTile(
              leading: CircleAvatar(backgroundColor: statusColor.withOpacity(0.2), child: Icon(Icons.beach_access, color: statusColor)),
              title: Text(leave['leave_type'] ?? ''),
              subtitle: Text('${leave['from_date']} - ${leave['to_date']}'),
              trailing: Chip(label: Text(leave['status'] ?? 'Pending', style: TextStyle(color: statusColor)), backgroundColor: statusColor.withOpacity(0.1)),
            ),
          );
        },
      ),
    );
  }
}

// ============== PAYROLL SCREEN ==============
class PayrollScreen extends StatefulWidget {
  const PayrollScreen({super.key});

  @override
  State<PayrollScreen> createState() => _PayrollScreenState();
}

class _PayrollScreenState extends State<PayrollScreen> {
  List<dynamic> _salarySlips = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // Try to fetch salary slip - may not exist in demo
      final res = await http.get(Uri.parse('${AppConfig.baseUrl}/resource/Salary%20Slip?limit=5'), headers: AppConfig.headers);
      if (res.statusCode == 200) {
        _salarySlips = jsonDecode(res.body)['data'] ?? [];
      }
    } catch (e) {
      debugPrint('Error: $e');
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payroll')),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _salarySlips.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text('No salary slips yet', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                  const SizedBox(height: 8),
                  const Text('Payroll data will appear here'),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _salarySlips.length,
              itemBuilder: (context, index) {
                final slip = _salarySlips[index];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(slip['month'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                            Text('${slip['net_pay'] ?? 0}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)),
                          ],
                        ),
                        const Divider(),
                        _buildRow('Gross Pay', '${slip['gross_pay'] ?? 0}'),
                        _buildRow('Deductions', '${slip['total_deduction'] ?? 0}'),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label), Text(value)]),
    );
  }
}

// ============== ATTENDANCE HISTORY SCREEN ==============
class AttendanceHistoryScreen extends StatefulWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  State<AttendanceHistoryScreen> createState() => _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  List<dynamic> _attendance = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final res = await http.get(Uri.parse('${AppConfig.baseUrl}/resource/Attendance?limit=30'), headers: AppConfig.headers);
      if (res.statusCode == 200) {
        _attendance = jsonDecode(res.body)['data'] ?? [];
      }
    } catch (e) {
      debugPrint('Error: $e');
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Attendance History')),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _attendance.isEmpty
          ? const Center(child: Text('No attendance records'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _attendance.length,
              itemBuilder: (context, index) {
                final att = _attendance[index];
                final isPresent = att['status'] == 'Present';
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isPresent ? Colors.green[100] : Colors.red[100],
                      child: Icon(isPresent ? Icons.check : Icons.close, color: isPresent ? Colors.green : Colors.red),
                    ),
                    title: Text(att['attendance_date'] ?? ''),
                    subtitle: Text('${att['in_time'] ?? ''} - ${att['out_time'] ?? ''}'),
                    trailing: Chip(label: Text(att['status'] ?? ''), backgroundColor: isPresent ? Colors.green[50] : Colors.red[50]),
                  ),
                );
              },
            ),
    );
  }
}
