import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:maa_messaging/maa_messaging.dart';

import 'firebase_options.dart';
import 'open_street_map.dart';

const plum = Color(0xFF33213E);
const orange = Color(0xFFFF7657);
const cream = Color(0xFFFFF8F1);
const green = Color(0xFF35A879);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  var firebaseReady = false;
  final options = maaFirebaseOptions();
  if (options != null) {
    try {
      await Firebase.initializeApp(options: options);
      firebaseReady = true;
      await MaaMessaging.initialize('restaurant', accent: orange);
    } catch (error) {
      debugPrint('Firebase is not configured yet: $error');
    }
  }
  runApp(MaaRestaurantApp(firebaseReady: firebaseReady));
}

class MaaRestaurantApp extends StatelessWidget {
  const MaaRestaurantApp({super.key, required this.firebaseReady});
  final bool firebaseReady;
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
      home: MaaUpdateGate(
          role: 'restaurant',
          accent: orange,
          enabled: firebaseReady,
          child: const Directionality(
              textDirection: TextDirection.rtl, child: RestaurantShell())));
}

class RestaurantShell extends StatefulWidget {
  const RestaurantShell({super.key});
  @override
  State<RestaurantShell> createState() => _RestaurantShellState();
}

class _RestaurantShellState extends State<RestaurantShell> {
  int tab = 0;
  bool open = true;
  final Map<String, String> orderStates = {
    '#1042': 'طلب جديد',
    '#1041': 'قيد التحضير',
    '#1040': 'جاهز للاستلام'
  };
  void advance(String id) =>
      setState(() => orderStates[id] = switch (orderStates[id]) {
            'طلب جديد' => 'قيد التحضير',
            'قيد التحضير' => 'جاهز للاستلام',
            _ => 'تم التسليم'
          });

  @override
  Widget build(BuildContext context) {
    final pages = [
      RestaurantHome(
          open: open,
          orders: orderStates,
          onOpenChanged: (v) => setState(() => open = v),
          onAdvance: advance),
      RestaurantOrders(orders: orderStates, onAdvance: advance),
      const RestaurantMenu(),
      const RestaurantReports(),
      const RestaurantMore()
    ];
    return Scaffold(
        body: SafeArea(child: IndexedStack(index: tab, children: pages)),
        bottomNavigationBar: NavigationBar(
            selectedIndex: tab,
            indicatorColor: orange.withValues(alpha: .16),
            onDestinationSelected: (v) => setState(() => tab = v),
            destinations: const [
              NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: 'الرئيسية'),
              NavigationDestination(
                  icon: Icon(Icons.receipt_long_outlined),
                  selectedIcon: Icon(Icons.receipt_long),
                  label: 'الطلبات'),
              NavigationDestination(
                  icon: Icon(Icons.restaurant_menu), label: 'القائمة'),
              NavigationDestination(
                  icon: Icon(Icons.bar_chart_outlined),
                  selectedIcon: Icon(Icons.bar_chart),
                  label: 'التقارير'),
              NavigationDestination(
                  icon: Icon(Icons.grid_view), label: 'المزيد')
            ]));
  }
}

class RestaurantHome extends StatelessWidget {
  const RestaurantHome(
      {super.key,
      required this.open,
      required this.orders,
      required this.onOpenChanged,
      required this.onAdvance});
  final bool open;
  final Map<String, String> orders;
  final ValueChanged<bool> onOpenChanged;
  final ValueChanged<String> onAdvance;
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
          title: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('مطعم النخلة',
                    style:
                        TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                Text('القاهرة', style: TextStyle(fontSize: 12))
              ]),
          actions: [
            const MaaNotificationButton(role: 'restaurant', accent: orange)
          ]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              Icon(Icons.circle, color: open ? green : Colors.grey, size: 13),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(open ? 'مفتوح الآن' : 'مغلق مؤقتًا',
                      style: const TextStyle(fontWeight: FontWeight.bold))),
              Switch(
                  value: open,
                  activeThumbColor: green,
                  onChanged: onOpenChanged)
            ])),
        const SizedBox(height: 12),
        Row(children: const [
          Expanded(
              child: SmallStat(
                  title: 'طلبات اليوم', value: '24', icon: Icons.receipt_long)),
          SizedBox(width: 9),
          Expanded(
              child: SmallStat(
                  title: 'قيد التحضير', value: '1', icon: Icons.soup_kitchen)),
          SizedBox(width: 9),
          Expanded(
              child: SmallStat(
                  title: 'مكتملة', value: '18', icon: Icons.check_circle))
        ]),
        const SizedBox(height: 20),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('الطلبات الجديدة',
              style: TextStyle(
                  fontSize: 20, color: plum, fontWeight: FontWeight.w900)),
          TextButton(onPressed: () {}, child: const Text('عرض الكل'))
        ]),
        ...orders.entries.map((entry) => OrderTile(
            id: entry.key,
            state: entry.value,
            onAction: () => onAdvance(entry.key))),
        const SizedBox(height: 14),
        const Text('موقع المطعم — القاهرة',
            style: TextStyle(
                fontSize: 18, color: plum, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        const OpenStreetMapPreview(height: 190),
        const Padding(
            padding: EdgeInsets.only(top: 5),
            child: Text(
                'موقع تجريبي ثابت؛ ربط عنوان المطعم الفعلي سيأتي مع إعدادات Firebase.',
                style: TextStyle(fontSize: 12, color: Colors.black54))),
        const SizedBox(height: 14),
        const Text('ملخص اليوم',
            style: TextStyle(
                fontSize: 19, color: plum, fontWeight: FontWeight.w900)),
        const SizedBox(height: 9),
        const Row(children: [
          Expanded(
              child: SmallStat(
                  title: 'المبيعات', value: '4,820 ج.م', icon: Icons.payments)),
          SizedBox(width: 10),
          Expanded(
              child: SmallStat(
                  title: 'متوسط الطلب',
                  value: '26 ج.م',
                  icon: Icons.shopping_bag))
        ])
      ]));
}

class SmallStat extends StatelessWidget {
  const SmallStat(
      {super.key,
      required this.title,
      required this.value,
      required this.icon});
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
            Text(value,
                style:
                    const TextStyle(fontWeight: FontWeight.w900, color: plum)),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, color: Colors.black54))
          ])));
}

class OrderTile extends StatelessWidget {
  const OrderTile(
      {super.key,
      required this.id,
      required this.state,
      required this.onAction});
  final String id, state;
  final VoidCallback onAction;
  @override
  Widget build(BuildContext context) {
    final next = switch (state) {
      'طلب جديد' => 'قبول الطلب',
      'قيد التحضير' => 'تحديث الحالة',
      'جاهز للاستلام' => 'تأكيد التسليم',
      _ => 'مكتمل'
    };
    return Card(
        color: Colors.white,
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 10),
        child: Padding(
            padding: const EdgeInsets.all(13),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(id,
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, color: plum)),
                Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                        color: state == 'تم التسليم'
                            ? const Color(0xFFE5F5ED)
                            : orange.withValues(alpha: .13),
                        borderRadius: BorderRadius.circular(20)),
                    child: Text(state, style: const TextStyle(fontSize: 12)))
              ]),
              const SizedBox(height: 8),
              const Text('أحمد سالم  •  حي مدينة نصر، القاهرة'),
              const Text('مندي دجاج × 2    •    سلطة عربية × 1'),
              const Divider(),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('الإجمالي  68 ج.م',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                FilledButton(
                    onPressed: state == 'تم التسليم' ? null : onAction,
                    style: FilledButton.styleFrom(backgroundColor: orange),
                    child: Text(next))
              ])
            ])));
  }
}

class RestaurantOrders extends StatelessWidget {
  const RestaurantOrders(
      {super.key, required this.orders, required this.onAdvance});
  final Map<String, String> orders;
  final ValueChanged<String> onAdvance;
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('إدارة الطلبات')),
      body: ListView(
          padding: const EdgeInsets.all(16),
          children: orders.entries
              .map((e) => OrderTile(
                  id: e.key, state: e.value, onAction: () => onAdvance(e.key)))
              .toList()));
}

class RestaurantMenu extends StatelessWidget {
  const RestaurantMenu({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
          title: const Text('قائمتي'),
          actions: [IconButton(onPressed: () {}, icon: const Icon(Icons.add))]),
      body: ListView(padding: const EdgeInsets.all(16), children: const [
        Text('الأصناف المتاحة',
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w900, color: plum)),
        MenuRow(name: 'مندي دجاج', price: '25 ج.م', icon: Icons.rice_bowl),
        MenuRow(name: 'كبسة لحم', price: '38 ج.م', icon: Icons.dinner_dining),
        MenuRow(name: 'مقلوبة', price: '22 ج.م', icon: Icons.lunch_dining),
        MenuRow(name: 'سلطة عربية', price: '12 ج.م', icon: Icons.eco)
      ]));
}

class MenuRow extends StatelessWidget {
  const MenuRow(
      {super.key, required this.name, required this.price, required this.icon});
  final String name, price;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Card(
      color: Colors.white,
      elevation: 0,
      child: ListTile(
          leading: CircleAvatar(
              backgroundColor: orange.withValues(alpha: .13),
              child: Icon(icon, color: orange)),
          title:
              Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(price),
          trailing: Switch(value: true, onChanged: (_) {})));
}

class RestaurantReports extends StatelessWidget {
  const RestaurantReports({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('التقارير')),
      body: ListView(padding: const EdgeInsets.all(18), children: [
        const Text('أداء آخر 7 أيام',
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w900, color: plum)),
        const SizedBox(height: 16),
        Container(
            height: 220,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(18)),
            child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: const [
                  Bar(height: 70),
                  Bar(height: 115),
                  Bar(height: 90),
                  Bar(height: 145),
                  Bar(height: 125),
                  Bar(height: 175),
                  Bar(height: 155)
                ])),
        const SizedBox(height: 14),
        const Row(children: [
          Expanded(
              child: SmallStat(
                  title: 'إجمالي الطلبات',
                  value: '186',
                  icon: Icons.receipt_long)),
          SizedBox(width: 10),
          Expanded(
              child: SmallStat(
                  title: 'إجمالي المبيعات',
                  value: '4,820 ج.م',
                  icon: Icons.payments))
        ])
      ]));
}

class Bar extends StatelessWidget {
  const Bar({super.key, required this.height});
  final double height;
  @override
  Widget build(BuildContext context) => Container(
      width: 22,
      height: height,
      decoration: BoxDecoration(
          color: green,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(7))));
}

class RestaurantMore extends StatelessWidget {
  const RestaurantMore({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('المزيد')),
      body: ListView(padding: const EdgeInsets.all(16), children: const [
        MoreTile(icon: Icons.local_offer_outlined, label: 'العروض والخصومات'),
        MoreTile(icon: Icons.inventory_2_outlined, label: 'إدارة المخزون'),
        MoreTile(icon: Icons.support_agent, label: 'الدعم والمساعدة'),
        MoreTile(icon: Icons.settings_outlined, label: 'الإعدادات'),
        MoreTile(icon: Icons.logout, label: 'تسجيل الخروج')
      ]));
}

class MoreTile extends StatelessWidget {
  const MoreTile({super.key, required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Card(
      color: Colors.white,
      elevation: 0,
      child: ListTile(
          leading: Icon(icon, color: plum),
          title: Text(label),
          trailing: const Icon(Icons.chevron_left)));
}
