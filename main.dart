import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = HabitStore();
  await store.load();
  runApp(RafiqApp(store: store));
}

const Color bg = Color(0xFF0D0B14);
const Color panel = Color(0xFF191526);
const Color panel2 = Color(0xFF211B32);
const Color purple = Color(0xFF9B7BFF);
const Color purpleBright = Color(0xFFB7A0FF);
const Color muted = Color(0xFFAAA3BE);
const Color green = Color(0xFF57D6A0);
const Color red = Color(0xFFFF718B);

String dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime? parseDay(String? s) {
  if (s == null) return null;
  try {
    final p = s.split('-');
    return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
  } catch (_) {
    return null;
  }
}

class Habit {
  Habit({required this.id, required this.name, List<String>? completed, List<String>? relapses})
      : completed = completed ?? [], relapses = relapses ?? [];
  final String id;
  String name;
  List<String> completed;
  List<String> relapses;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'completed': completed, 'relapses': relapses};
  factory Habit.fromJson(Map<String, dynamic> j) => Habit(
    id: j['id'] as String? ?? UniqueKey().toString(),
    name: j['name'] as String? ?? 'عادة',
    completed: List<String>.from(j['completed'] ?? const []),
    relapses: List<String>.from(j['relapses'] ?? const []),
  );

  int get streak {
    final days = completed.toSet().map(parseDay).whereType<DateTime>().toList()..sort();
    final lastRelapse = relapses.map(parseDay).whereType<DateTime>().fold<DateTime?>(null, (a, b) => a == null || b.isAfter(a) ? b : a);
    final valid = days.where((d) => lastRelapse == null || !d.isBefore(lastRelapse)).toList();
    if (valid.isEmpty) return 0;
    final today = DateTime.now();
    final latest = valid.last;
    final todayOnly = DateTime(today.year, today.month, today.day);
    if (latest.isBefore(todayOnly.subtract(const Duration(days: 1)))) return 0;
    var count = 1;
    var cursor = latest;
    for (final d in valid.reversed.skip(1)) {
      if (dateKey(d) == dateKey(cursor.subtract(const Duration(days: 1)))) {
        count++;
        cursor = d;
      } else if (d.isBefore(cursor)) {
        break;
      }
    }
    return count;
  }

  int get bestStreak {
    final days = completed.toSet().map(parseDay).whereType<DateTime>().toList()..sort();
    var best = 0, current = 0;
    DateTime? prev;
    for (final d in days) {
      if (prev != null && dateKey(d) == dateKey(prev.add(const Duration(days: 1)))) {
        current++;
      } else {
        current = 1;
      }
      if (current > best) best = current;
      prev = d;
    }
    return best;
  }
}

class RoutineTask {
  RoutineTask({required this.id, required this.name, required this.created});
  final String id;
  String name;
  String created;
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'created': created};
  factory RoutineTask.fromJson(Map<String, dynamic> j) => RoutineTask(
    id: j['id'] as String? ?? UniqueKey().toString(),
    name: j['name'] as String? ?? 'مهمة',
    created: j['created'] as String? ?? dateKey(DateTime.now()),
  );
}

class HabitStore extends ChangeNotifier {
  List<Habit> habits = [];
  List<RoutineTask> tasks = [];
  Map<String, Map<String, bool>> taskHistory = {};

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    try {
      habits = (jsonDecode(p.getString('habits') ?? '[]') as List)
          .map((e) => Habit.fromJson(Map<String, dynamic>.from(e))).toList();
      tasks = (jsonDecode(p.getString('tasks') ?? '[]') as List)
          .map((e) => RoutineTask.fromJson(Map<String, dynamic>.from(e))).toList();
      final raw = Map<String, dynamic>.from(jsonDecode(p.getString('history') ?? '{}'));
      taskHistory = raw.map((k, v) => MapEntry(k, Map<String, bool>.from(v as Map)));
    } catch (_) {
      habits = [];
      tasks = [];
      taskHistory = {};
    }
  }

  Future<void> persist() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('habits', jsonEncode(habits.map((e) => e.toJson()).toList()));
    await p.setString('tasks', jsonEncode(tasks.map((e) => e.toJson()).toList()));
    await p.setString('history', jsonEncode(taskHistory));
    notifyListeners();
  }

  Future<void> addHabit(String name) async {
    habits.add(Habit(id: DateTime.now().microsecondsSinceEpoch.toString(), name: name));
    await persist();
  }
  Future<void> toggleHabitToday(Habit h) async {
    final today = dateKey(DateTime.now());
    if (h.completed.contains(today)) {
      h.completed.remove(today);
    } else {
      h.completed.add(today);
      h.completed.sort();
    }
    await persist();
  }
  Future<void> relapse(Habit h) async {
    final today = dateKey(DateTime.now());
    if (!h.relapses.contains(today)) h.relapses.add(today);
    h.completed.removeWhere((d) => d.compareTo(today) >= 0);
    await persist();
  }
  Future<void> deleteHabit(Habit h) async {
    habits.removeWhere((x) => x.id == h.id);
    await persist();
  }
  Future<void> addTask(String name) async {
    tasks.add(RoutineTask(id: DateTime.now().microsecondsSinceEpoch.toString(), name: name, created: dateKey(DateTime.now())));
    await persist();
  }
  bool taskDone(RoutineTask task, String day) => taskHistory[day]?[task.id] ?? false;
  Future<void> toggleTask(RoutineTask task, String day) async {
    final map = taskHistory.putIfAbsent(day, () => {});
    map[task.id] = !(map[task.id] ?? false);
    await persist();
  }
  Future<void> deleteTask(RoutineTask task) async {
    tasks.removeWhere((x) => x.id == task.id);
    for (final day in taskHistory.values) {
      day.remove(task.id);
    }
    await persist();
  }
}

class RafiqApp extends StatelessWidget {
  const RafiqApp({super.key, required this.store});
  final HabitStore store;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (_, __) => MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'رفيق - متتبع العادات',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bg,
        colorScheme: const ColorScheme.dark(primary: purple, surface: panel, error: red),
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(backgroundColor: bg, elevation: 0, centerTitle: false),
        inputDecorationTheme: InputDecorationTheme(
          filled: true, fillColor: panel2,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          hintStyle: const TextStyle(color: muted),
        ),
      ),
      home: Directionality(textDirection: TextDirection.rtl, child: HomeScreen(store: store)),
    ),
  );
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.store});
  final HabitStore store;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int tab = 0;
  DateTime selectedDay = DateTime.now();
  HabitStore get store => widget.store;
  String get selectedKey => dateKey(selectedDay);

  Future<void> addItem({required bool habit}) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: panel,
        title: Text(habit ? 'إضافة عادة جديدة' : 'إضافة مهمة للروتين'),
        content: TextField(
          controller: controller, autofocus: true,
          decoration: InputDecoration(hintText: habit ? 'مثال: قراءة 10 صفحات' : 'مثال: تمرين اليوم'),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('إضافة')),
        ],
      ),
    );
    if (name == null || name.trim().isEmpty) return;
    if (habit) {
      if (store.habits.any((h) => h.name.toLowerCase() == name.toLowerCase())) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('العادة موجودة بالفعل')));
        return;
      }
      await store.addHabit(name);
    } else {
      await store.addTask(name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _dashboard(),
      _routine(),
      _statistics(),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('رفيق', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800, color: purpleBright)),
          Text('خطوة صغيرة كل يوم', style: TextStyle(fontSize: 12, color: muted)),
        ]),
        actions: [
          IconButton(tooltip: 'إضافة', onPressed: () => addItem(habit: tab != 1), icon: const Icon(Icons.add_circle_outline, color: purpleBright, size: 28)),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(child: AnimatedSwitcher(duration: const Duration(milliseconds: 180), child: pages[tab])),
      bottomNavigationBar: NavigationBar(
        backgroundColor: panel, indicatorColor: purple.withOpacity(.22),
        selectedIndex: tab, onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.auto_awesome_outlined), selectedIcon: Icon(Icons.auto_awesome), label: 'الرئيسية'),
          NavigationDestination(icon: Icon(Icons.checklist_outlined), selectedIcon: Icon(Icons.checklist), label: 'روتين اليوم'),
          NavigationDestination(icon: Icon(Icons.insights_outlined), selectedIcon: Icon(Icons.insights), label: 'الإحصائيات'),
        ],
      ),
    );
  }

  Widget _dashboard() {
    final today = dateKey(DateTime.now());
    final doneToday = store.habits.where((h) => h.completed.contains(today)).length;
    final rate = store.habits.isEmpty ? 0 : (doneToday / store.habits.length * 100).round();
    return ListView(padding: const EdgeInsets.fromLTRB(16, 10, 16, 24), children: [
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(colors: [Color(0xFF38245F), Color(0xFF1D1830)], begin: Alignment.topRight, end: Alignment.bottomLeft),
          border: Border.all(color: purple.withOpacity(.3)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('ابدأ من جديد، كل يوم فرصة', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('التقدم مش لازم يكون مثالي؛ المهم إنك تكمّل.', style: TextStyle(color: muted)),
          const SizedBox(height: 18),
          Row(children: [
            Expanded(child: _miniMetric('إنجاز العادات', '$doneToday/${store.habits.length}', Icons.check_circle_outline)),
            const SizedBox(width: 10),
            Expanded(child: _miniMetric('نسبة اليوم', '$rate%', Icons.trending_up)),
          ]),
        ]),
      ),
      const SizedBox(height: 24),
      _sectionTitle('عاداتك', 'سجّل الالتزام عند إنجاز العادة'),
      const SizedBox(height: 10),
      if (store.habits.isEmpty) _empty('لسه مفيش عادات', 'اضغط + وأضف أول عادة تبدأ بها.')
      else ...store.habits.map(_habitCard),
      const SizedBox(height: 20),
      _sectionTitle('تذكير صغير', 'الانتكاسة مش نهاية الطريق'),
      const SizedBox(height: 10),
      Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(18)),
        child: const Row(children: [
          Icon(Icons.favorite_outline, color: purpleBright, size: 28), SizedBox(width: 12),
          Expanded(child: Text('لو يومك ما مشيش زي ما خططت، راجع السبب وارجع تاني من غير جلد للذات.', style: TextStyle(color: muted, height: 1.5))),
        ]),
      ),
    ]);
  }

  Widget _habitCard(Habit h) {
    final done = h.completed.contains(dateKey(DateTime.now()));
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(18), border: Border.all(color: done ? green.withOpacity(.35) : Colors.white.withOpacity(.04))),
      child: Row(children: [
        Container(width: 44, height: 44, decoration: BoxDecoration(color: purple.withOpacity(.16), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.bolt, color: purpleBright)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(h.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 4),
          Text('🔥 ${h.streak} يوم متتالي  ·  أفضل سلسلة ${h.bestStreak}', style: const TextStyle(color: muted, fontSize: 12)),
        ])),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: muted),
          onSelected: (v) async {
            if (v == 'relapse') {
              final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
                backgroundColor: panel, title: const Text('تسجيل انتكاسة؟'),
                content: Text('سيتم تسجيل انتكاسة اليوم وإعادة حساب سلسلة «${h.name}».'),
                actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('تأكيد'))],
              ));
              if (ok == true) await store.relapse(h);
            } else if (v == 'delete') {
              await store.deleteHabit(h);
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'relapse', child: Text('تسجيل انتكاسة')),
            PopupMenuItem(value: 'delete', child: Text('حذف العادة')),
          ],
        ),
        IconButton(
          tooltip: done ? 'إلغاء تسجيل اليوم' : 'سجّل اليوم',
          onPressed: () => store.toggleHabitToday(h),
          style: IconButton.styleFrom(backgroundColor: done ? green.withOpacity(.16) : purple.withOpacity(.16)),
          icon: Icon(done ? Icons.check_circle : Icons.circle_outlined, color: done ? green : purpleBright),
        ),
      ]),
    );
  }

  Widget _routine() {
    final key = selectedKey;
    final tasks = store.tasks.where((t) => t.created.compareTo(key) <= 0).toList();
    final done = tasks.where((t) => store.taskDone(t, key)).length;
    return ListView(padding: const EdgeInsets.all(16), children: [
      _sectionTitle('روتين اليوم', 'أنجز خطوة واحدة في كل مرة'),
      const SizedBox(height: 14),
      Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(18)),
        child: Row(children: [
          const Icon(Icons.calendar_month, color: purpleBright),
          const SizedBox(width: 10),
          Expanded(child: Text('${selectedDay.day}/${selectedDay.month}/${selectedDay.year}', style: const TextStyle(fontWeight: FontWeight.bold))),
          IconButton(onPressed: () => setState(() => selectedDay = selectedDay.subtract(const Duration(days: 1)), icon: const Icon(Icons.chevron_right)),
          IconButton(onPressed: () => setState(() => selectedDay = selectedDay.add(const Duration(days: 1)), icon: const Icon(Icons.chevron_left)),
          TextButton(onPressed: () => setState(() => selectedDay = DateTime.now()), child: const Text('اليوم')),
        ]),
      ),
      const SizedBox(height: 12),
      LinearProgressIndicator(value: tasks.isEmpty ? 0 : done / tasks.length, minHeight: 7, borderRadius: BorderRadius.circular(10), backgroundColor: panel2, color: purpleBright),
      const SizedBox(height: 8),
      Text('أنجزت $done من ${tasks.length} مهام', style: const TextStyle(color: muted)),
      const SizedBox(height: 12),
      if (tasks.isEmpty) _empty('جدولك فاضي', 'اضغط + لإضافة مهام الروتين.')
      else ...tasks.map((t) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(16)),
        child: CheckboxListTile(
          value: store.taskDone(t, key),
          onChanged: (_) => store.toggleTask(t, key),
          activeColor: purple, checkColor: bg,
          title: Text(t.name, style: TextStyle(decoration: store.taskDone(t, key) ? TextDecoration.lineThrough : null, color: store.taskDone(t, key) ? muted : Colors.white)),
          secondary: IconButton(icon: const Icon(Icons.delete_outline, color: muted), onPressed: () => store.deleteTask(t)),
          controlAffinity: ListTileControlAffinity.leading,
        ),
      )),
      const SizedBox(height: 12),
      FilledButton.icon(onPressed: () => addItem(habit: false), icon: const Icon(Icons.add), label: const Text('إضافة مهمة')),
    ]);
  }

  Widget _statistics() {
    final today = DateTime.now();
    final todayKey = dateKey(today);
    final doneToday = store.habits.where((h) => h.completed.contains(todayKey)).length;
    final allRelapses = store.habits.fold<int>(0, (sum, h) => sum + h.relapses.length);
    final best = store.habits.fold<int>(0, (m, h) => h.bestStreak > m ? h.bestStreak : m);
    final current = store.habits.fold<int>(0, (m, h) => h.streak > m ? h.streak : m);
    var weekDone = 0, weekTotal = 0;
    for (var i = 0; i < 7; i++) {
      final day = dateKey(today.subtract(Duration(days: i)));
      final tasks = store.tasks.where((t) => t.created.compareTo(day) <= 0);
      weekTotal += tasks.length;
      weekDone += tasks.where((t) => store.taskDone(t, day)).length;
    }
    final weekRate = weekTotal == 0 ? 0 : (weekDone / weekTotal * 100).round();
    return ListView(padding: const EdgeInsets.all(16), children: [
      _sectionTitle('إحصائياتك', 'لاحظ تقدمك بدل ما تقارن نفسك بغيرك'),
      const SizedBox(height: 14),
      GridView.count(
        crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.3,
        children: [
          _statCard('العادات النشطة', '${store.habits.length}', Icons.bolt),
          _statCard('إنجاز اليوم', '$doneToday/${store.habits.length}', Icons.task_alt),
          _statCard('أفضل سلسلة', '$best يوم', Icons.emoji_events_outlined),
          _statCard('أعلى سلسلة حالية', '$current يوم', Icons.local_fire_department_outlined),
          _statCard('انتكاسات مسجلة', '$allRelapses', Icons.restart_alt),
          _statCard('إنجاز المهام أسبوعيًا', '$weekRate%', Icons.insights),
        ],
      ),
      const SizedBox(height: 18),
      Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(18)),
        child: const Text('كل يوم فرصة جديدة. قِس تقدمك على نفسك، واعتبر كل محاولة خبرة تساعدك تكمل.', style: TextStyle(color: muted, height: 1.6))),
    ]);
  }

  Widget _miniMetric(String label, String value, IconData icon) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: Colors.black.withOpacity(.17), borderRadius: BorderRadius.circular(15)),
    child: Row(children: [Icon(icon, color: purpleBright), const SizedBox(width: 9), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: muted, fontSize: 11)),
      const SizedBox(height: 4), Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
    ]))]),
  );

  Widget _sectionTitle(String title, String subtitle) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
    const SizedBox(height: 4), Text(subtitle, style: const TextStyle(color: muted, fontSize: 12)),
  ]);

  Widget _empty(String title, String subtitle) => Container(
    padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(18)),
    child: Column(children: [const Icon(Icons.auto_awesome, color: purpleBright, size: 32), const SizedBox(height: 8), Text(title, style: const TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 5), Text(subtitle, style: const TextStyle(color: muted), textAlign: TextAlign.center)]),
  );

  Widget _statCard(String title, String value, IconData icon) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(18), border: Border.all(color: purple.withOpacity(.12))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Icon(icon, color: purpleBright, size: 25),
      Text(value, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800)),
      Text(title, style: const TextStyle(color: muted, fontSize: 12)),
    ]),
  );
}
