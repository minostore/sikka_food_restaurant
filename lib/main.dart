import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:maa_messaging/maa_messaging.dart';

import 'firebase_options.dart';
import 'open_street_map.dart';

const plum = Color(0xFF33213E);
const orange = Color(0xFFFF7657);
const cream = Color(0xFFFFF8F1);
const green = Color(0xFF35A879);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MaaSession? session;
  final options = maaFirebaseOptions();
  if (options != null) {
    try {
      await Firebase.initializeApp(options: options);
      session = MaaSession('restaurant')..start();
      await MaaMessaging.initialize('restaurant', accent: orange);
    } catch (error) {
      debugPrint('Firebase is not configured yet: $error');
    }
  }
  runApp(MaaRestaurantApp(session: session));
}

class MaaRestaurantApp extends StatelessWidget {
  const MaaRestaurantApp({super.key, required this.session});
  final MaaSession? session;
  @override
  Widget build(BuildContext context) => MaterialApp(
      navigatorKey: MaaMessaging.navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'معًا - المطعم',
      locale: const Locale('ar', 'EG'),
      supportedLocales: const [Locale('ar', 'EG'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: cream,
          colorScheme: ColorScheme.fromSeed(
              seedColor: orange, primary: orange, secondary: plum),
          textTheme: ThemeData.light().textTheme.apply(fontFamily: 'Tajawal'),
          appBarTheme: const AppBarTheme(
              backgroundColor: plum, foregroundColor: Colors.white)),
      home: session == null
          ? const Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(
                  body: Padding(
                      padding: EdgeInsets.all(28),
                      child: Center(
                          child: Text(
                              'لم يُربط التطبيق بمشروع Firebase بعد.\nابنِ التطبيق مع قيم FIREBASE_* و MAA_API_URL كما في ملف README.',
                              textAlign: TextAlign.center)))))
          : MaaAuthGate(
              session: session!,
              accent: orange,
              appTitle: 'معًا — تطبيق المطعم',
              builder: (_) => MaaUpdateGate(
                  role: 'restaurant',
                  accent: orange,
                  enabled: true,
                  child: Directionality(
                      textDirection: TextDirection.rtl,
                      child: RestaurantShell(session: session!)))));
}

Stream<List<Map<String, dynamic>>> restaurantOrders(MaaSession s) => s.db
    .collection('orders')
    .where('restaurantUid', isEqualTo: s.uid)
    .snapshots()
    .map((q) => maaSortedOrders(q.docs.map((d) => d.data())));

Future<void> setOrderStatus(Map<String, dynamic> o, String status,
    {String? reason}) {
  return FirebaseFirestore.instance.collection('orders').doc('${o['id']}').update({
    'status': status,
    'updated': maaNow(),
    'history': maaAppendHistory(o['history'], status),
    if (reason != null) 'cancelReason': reason,
  });
}

class RestaurantShell extends StatefulWidget {
  const RestaurantShell({super.key, required this.session});
  final MaaSession session;
  @override
  State<RestaurantShell> createState() => _RestaurantShellState();
}

class _RestaurantShellState extends State<RestaurantShell> {
  int tab = 0;
  StreamSubscription<List<Map<String, dynamic>>>? _sub;
  final Set<String> _seen = {};
  bool _first = true;

  @override
  void initState() {
    super.initState();
    // إشعار محلي عند وصول طلب جديد أثناء فتح التطبيق
    _sub = restaurantOrders(widget.session).listen((orders) {
      for (final o in orders) {
        final id = '${o['id']}';
        if (_seen.add(id) && !_first && o['status'] == orderNew) {
          MaaMessaging.showLocal('طلب جديد ${o['order']}', '${o['customer']} • ${maaMoney(maaNum(o['total']))}');
        }
      }
      _first = false;
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    final pages = [
      RestaurantHome(session: s),
      RestaurantOrders(session: s),
      RestaurantMenu(session: s),
      RestaurantReports(session: s),
      RestaurantMore(session: s),
    ];
    return Scaffold(
        body: SafeArea(child: IndexedStack(index: tab, children: pages)),
        bottomNavigationBar: NavigationBar(
            selectedIndex: tab,
            indicatorColor: orange.withValues(alpha: .16),
            onDestinationSelected: (v) => setState(() => tab = v),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'الرئيسية'),
              NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'الطلبات'),
              NavigationDestination(icon: Icon(Icons.restaurant_menu), label: 'القائمة'),
              NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'التقارير'),
              NavigationDestination(icon: Icon(Icons.grid_view), label: 'المزيد')
            ]));
  }
}

class RestaurantHome extends StatelessWidget {
  const RestaurantHome({super.key, required this.session});
  final MaaSession session;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final open = session.profile['accepting'] == 'مفتوح';
        return Scaffold(
            appBar: AppBar(
                title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(session.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                  Text(session.publicId, style: const TextStyle(fontSize: 12))
                ]),
                actions: const [MaaNotificationButton(role: 'restaurant', accent: orange)]),
            body: StreamBuilder<List<Map<String, dynamic>>>(
                stream: restaurantOrders(session),
                builder: (context, snap) {
                  final orders = snap.data ?? const <Map<String, dynamic>>[];
                  final today = maaNow().substring(0, 10);
                  final todays = orders.where((o) => '${o['date']}'.startsWith(today)).toList();
                  final done = todays.where((o) => o['status'] == orderDone).toList();
                  final sales = done.fold<num>(0, (n, o) => n + maaNum(o['subtotal']));
                  final fresh = orders.where((o) => o['status'] == orderNew || o['status'] == orderPreparing).toList();
                  final lat = session.profile['lat'];
                  return ListView(padding: const EdgeInsets.all(16), children: [
                    Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                        child: Row(children: [
                          Icon(Icons.circle, color: open ? green : Colors.grey, size: 13),
                          const SizedBox(width: 8),
                          Expanded(child: Text(open ? 'مفتوح الآن — يستقبل الطلبات' : 'مغلق مؤقتًا', style: const TextStyle(fontWeight: FontWeight.bold))),
                          Switch(
                              value: open,
                              activeThumbColor: green,
                              onChanged: (v) => session.profileRef.update({'accepting': v ? 'مفتوح' : 'مغلق مؤقتًا', 'lastActivity': maaNow()}))
                        ])),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: SmallStat(title: 'طلبات اليوم', value: '${todays.length}', icon: Icons.receipt_long)),
                      const SizedBox(width: 9),
                      Expanded(child: SmallStat(title: 'نشطة الآن', value: '${fresh.length}', icon: Icons.soup_kitchen)),
                      const SizedBox(width: 9),
                      Expanded(child: SmallStat(title: 'مكتملة', value: '${done.length}', icon: Icons.check_circle))
                    ]),
                    const SizedBox(height: 20),
                    const Text('الطلبات الواردة', style: TextStyle(fontSize: 20, color: plum, fontWeight: FontWeight.w900)),
                    if (fresh.isEmpty)
                      const Padding(padding: EdgeInsets.all(20), child: Center(child: Text('لا توجد طلبات جديدة.', style: TextStyle(color: Colors.black54)))),
                    ...fresh.map((o) => OrderTile(order: o)),
                    const SizedBox(height: 14),
                    const Text('موقع المطعم', style: TextStyle(fontSize: 18, color: plum, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    OpenStreetMapPreview(height: 190, pins: [if (lat is num) MapPin(lat.toDouble(), (session.profile['lng'] as num).toDouble(), Icons.restaurant, orange)]),
                    Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: lat is num
                            ? const Text('هذا الموقع يظهر للعميل والسائق وللإدارة.', style: TextStyle(fontSize: 12, color: Colors.black54))
                            : OutlinedButton.icon(
                                onPressed: () async {
                                  final p = await maaCurrentPosition();
                                  if (p != null) await session.profileRef.update({'lat': p.lat, 'lng': p.lng});
                                },
                                icon: const Icon(Icons.my_location),
                                label: const Text('تحديد موقع المطعم من هذا الجهاز'))),
                    const SizedBox(height: 14),
                    Row(children: [
                      Expanded(child: SmallStat(title: 'مبيعات اليوم', value: maaMoney(sales), icon: Icons.payments)),
                      const SizedBox(width: 10),
                      Expanded(child: SmallStat(title: 'متوسط الطلب', value: done.isEmpty ? '—' : maaMoney((sales / done.length).round()), icon: Icons.shopping_bag))
                    ])
                  ]);
                }));
      });
}

class SmallStat extends StatelessWidget {
  const SmallStat({super.key, required this.title, required this.value, required this.icon});
  final String title, value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Card(
      color: Colors.white,
      elevation: 0,
      child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
          child: Column(children: [
            Icon(icon, color: orange),
            const SizedBox(height: 7),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w900, color: plum)),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: Colors.black54))
          ])));
}

class OrderTile extends StatelessWidget {
  const OrderTile({super.key, required this.order});
  final Map<String, dynamic> order;

  Future<void> _reject(BuildContext context) async {
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: const Text('رفض الطلب'),
              content: TextField(controller: reason, decoration: const InputDecoration(labelText: 'سبب الرفض')),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('رجوع')),
                FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('رفض')),
              ],
            )));
    if (ok == true) {
      await setOrderStatus(order, orderCancelled, reason: reason.text.trim().isEmpty ? 'رفضه المطعم' : reason.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = '${order['status']}';
    final action = switch (state) {
      orderNew => ('قبول الطلب', orderPreparing),
      orderPreparing => ('الطلب جاهز', orderReady),
      _ => null,
    };
    return Card(
        color: Colors.white,
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 10),
        child: Padding(
            padding: const EdgeInsets.all(13),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('${order['order']}  •  ${order['customerId']}', style: const TextStyle(fontWeight: FontWeight.w900, color: plum)),
                Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: state == orderDone ? const Color(0xFFE5F5ED) : orange.withValues(alpha: .13), borderRadius: BorderRadius.circular(20)),
                    child: Text(state, style: const TextStyle(fontSize: 12)))
              ]),
              const SizedBox(height: 8),
              Text('${order['customer']}  •  ${order['address'] ?? ''}'),
              Text('${order['items']}'),
              if ('${order['notes'] ?? ''}'.isNotEmpty) Text('ملاحظة: ${order['notes']}', style: const TextStyle(color: Colors.black54)),
              if ('${order['driver'] ?? ''}'.isNotEmpty) Text('السائق: ${order['driver']} (${order['driverId']})'),
              const Divider(),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('الإجمالي ${maaMoney(maaNum(order['total']))}', style: const TextStyle(fontWeight: FontWeight.bold)),
                Row(children: [
                  if (state == orderNew) TextButton(onPressed: () => _reject(context), child: const Text('رفض', style: TextStyle(color: Color(0xFFC62828)))),
                  if (action != null)
                    FilledButton(onPressed: () => setOrderStatus(order, action.$2), style: FilledButton.styleFrom(backgroundColor: orange), child: Text(action.$1)),
                ])
              ])
            ])));
  }
}

class RestaurantOrders extends StatelessWidget {
  const RestaurantOrders({super.key, required this.session});
  final MaaSession session;
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('إدارة الطلبات')),
      body: StreamBuilder<List<Map<String, dynamic>>>(
          stream: restaurantOrders(session),
          builder: (context, snap) {
            if (snap.hasError) return const Center(child: Text('تعذر تحميل الطلبات.'));
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            if (snap.data!.isEmpty) return const Center(child: Text('لا توجد طلبات بعد.'));
            return ListView(padding: const EdgeInsets.all(16), children: snap.data!.map((o) => OrderTile(order: o)).toList());
          }));
}

class RestaurantMenu extends StatelessWidget {
  const RestaurantMenu({super.key, required this.session});
  final MaaSession session;

  Future<void> _edit(BuildContext context, [DocumentSnapshot<Map<String, dynamic>>? doc]) async {
    final data = doc?.data() ?? {};
    final name = TextEditingController(text: '${data['name'] ?? ''}');
    final desc = TextEditingController(text: '${data['description'] ?? ''}');
    final price = TextEditingController(text: data['price'] == null ? '' : '${data['price']}');
    final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: Text(doc == null ? 'إضافة صنف' : 'تعديل الصنف'),
              content: SingleChildScrollView(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(controller: name, decoration: const InputDecoration(labelText: 'اسم الصنف')),
                TextField(controller: desc, decoration: const InputDecoration(labelText: 'الوصف')),
                TextField(controller: price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'السعر (ج.م)')),
              ])),
              actions: [
                if (doc != null)
                  TextButton(
                      onPressed: () async {
                        await doc.reference.delete();
                        if (ctx.mounted) Navigator.pop(ctx, false);
                      },
                      child: const Text('حذف', style: TextStyle(color: Color(0xFFC62828)))),
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
                FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حفظ')),
              ],
            )));
    final p = num.tryParse(price.text.trim());
    if (ok != true || name.text.trim().isEmpty || p == null) return;
    final fields = {'name': name.text.trim(), 'description': desc.text.trim(), 'price': p};
    if (doc != null) {
      await doc.reference.update(fields);
    } else {
      await session.db.collection('menuItems').add({
        ...fields,
        'restaurantUid': session.uid,
        'restaurantId': session.publicId,
        'available': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('قائمتي'), actions: [IconButton(onPressed: () => _edit(context), icon: const Icon(Icons.add))]),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: session.db.collection('menuItems').where('restaurantUid', isEqualTo: session.uid).snapshots(),
          builder: (context, snap) {
            if (snap.hasError) return const Center(child: Text('تعذر تحميل القائمة.'));
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final docs = snap.data!.docs;
            if (docs.isEmpty) return const Center(child: Text('أضف أول صنف بالضغط على +'));
            return ListView(
                padding: const EdgeInsets.all(16),
                children: docs.map((d) {
              final m = d.data();
              return Card(
                  color: Colors.white,
                  elevation: 0,
                  child: ListTile(
                      onTap: () => _edit(context, d),
                      leading: CircleAvatar(backgroundColor: orange.withValues(alpha: .13), child: const Icon(Icons.restaurant, color: orange)),
                      title: Text('${m['name']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(maaMoney(maaNum(m['price']))),
                      trailing: Switch(value: m['available'] != false, onChanged: (v) => d.reference.update({'available': v}))));
            }).toList());
          }));
}

class RestaurantReports extends StatelessWidget {
  const RestaurantReports({super.key, required this.session});
  final MaaSession session;
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('التقارير')),
      body: StreamBuilder<List<Map<String, dynamic>>>(
          stream: restaurantOrders(session),
          builder: (context, snap) {
            final orders = snap.data ?? const <Map<String, dynamic>>[];
            final now = DateTime.now();
            final days = List.generate(7, (i) {
              final d = now.subtract(Duration(days: 6 - i));
              final key = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
              return (key, orders.where((o) => '${o['date']}'.startsWith(key)).length);
            });
            final peak = days.fold<int>(1, (m, d) => d.$2 > m ? d.$2 : m);
            final completed = orders.where((o) => o['status'] == orderDone).toList();
            final sales = completed.fold<num>(0, (n, o) => n + maaNum(o['subtotal']));
            return ListView(padding: const EdgeInsets.all(18), children: [
              const Text('الطلبات آخر 7 أيام', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: plum)),
              const SizedBox(height: 16),
              Container(
                  height: 220,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.end, mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                    for (final d in days)
                      Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                        Text('${d.$2}', style: const TextStyle(fontSize: 11)),
                        Container(width: 22, height: 8 + 140 * d.$2 / peak, decoration: const BoxDecoration(color: green, borderRadius: BorderRadius.vertical(top: Radius.circular(7)))),
                        const SizedBox(height: 4),
                        Text(d.$1.substring(8), style: const TextStyle(fontSize: 11, color: Colors.black54)),
                      ])
                  ])),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: SmallStat(title: 'إجمالي الطلبات', value: '${orders.length}', icon: Icons.receipt_long)),
                const SizedBox(width: 10),
                Expanded(child: SmallStat(title: 'مبيعات مكتملة', value: maaMoney(sales), icon: Icons.payments))
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: SmallStat(title: 'مكتملة', value: '${completed.length}', icon: Icons.check_circle)),
                const SizedBox(width: 10),
                Expanded(child: SmallStat(title: 'ملغاة', value: '${orders.where((o) => o['status'] == orderCancelled).length}', icon: Icons.cancel))
              ]),
            ]);
          }));
}

class RestaurantMore extends StatelessWidget {
  const RestaurantMore({super.key, required this.session});
  final MaaSession session;

  Future<void> _settings(BuildContext context) async {
    final p = session.profile;
    final name = TextEditingController(text: session.name);
    final phone = TextEditingController(text: session.phone);
    final address = TextEditingController(text: session.address);
    final cuisine = TextEditingController(text: '${p['cuisine'] ?? ''}');
    final fee = TextEditingController(text: '${p['deliveryFee'] ?? 15}');
    final min = TextEditingController(text: '${p['minOrder'] ?? 0}');
    final prep = TextEditingController(text: '${p['prepTime'] ?? '25–35 دقيقة'}');
    final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: const Text('إعدادات المطعم'),
              content: SingleChildScrollView(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(controller: name, decoration: const InputDecoration(labelText: 'اسم المطعم')),
                TextField(controller: phone, decoration: const InputDecoration(labelText: 'الهاتف')),
                TextField(controller: address, decoration: const InputDecoration(labelText: 'العنوان')),
                TextField(controller: cuisine, decoration: const InputDecoration(labelText: 'نوع المطبخ (مثال: مشويات)')),
                TextField(controller: fee, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'رسوم التوصيل (ج.م)')),
                TextField(controller: min, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الحد الأدنى للطلب (ج.م)')),
                TextField(controller: prep, decoration: const InputDecoration(labelText: 'وقت التحضير')),
              ])),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
                FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حفظ')),
              ],
            )));
    if (ok != true) return;
    await session.profileRef.update({
      'name': name.text.trim(),
      'phone': phone.text.trim(),
      'address': address.text.trim(),
      'cuisine': cuisine.text.trim(),
      'deliveryFee': num.tryParse(fee.text.trim()) ?? 15,
      'minOrder': num.tryParse(min.text.trim()) ?? 0,
      'prepTime': prep.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('المزيد')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        MoreTile(icon: Icons.settings_outlined, label: 'إعدادات المطعم والتوصيل', onTap: () => _settings(context)),
        MoreTile(
            icon: Icons.support_agent,
            label: 'الدعم والمساعدة',
            onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => MaaSupportPage(session: session, accent: orange)))),
        MoreTile(icon: Icons.logout, label: 'تسجيل الخروج', onTap: session.signOut),
      ]));
}

class MoreTile extends StatelessWidget {
  const MoreTile({super.key, required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
      color: Colors.white,
      elevation: 0,
      child: ListTile(onTap: onTap, leading: Icon(icon, color: plum), title: Text(label), trailing: const Icon(Icons.chevron_left)));
}
