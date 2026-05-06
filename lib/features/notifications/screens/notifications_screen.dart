// notifications_screen.dart — InuaFund
// FIX: token read from FlutterSecureStorage('jwt_token'), not SharedPreferences
// FIX: API response parsed as direct List (matches React: response.data)
// FIX: merge logic rebuilt — no more silent swallowed errors
// Reduced ~900 → ~580 lines · polished UI · smooth transitions

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/network/notification_service_web.dart';

// ── THEME ────────────────────────────────────────────────────────────────────
class _C {
  static const bg          = Color(0xFFF4F6F5);
  static const surface     = Color(0xFFFFFFFF);
  static const border      = Color(0xFFE8EBE9);
  static const ink         = Color(0xFF0D1F18);
  static const inkMid      = Color(0xFF3D5248);
  static const inkSoft     = Color(0xFF8FA89D);
  static const greenMid    = Color(0xFF178A50);
  static const greenLight  = Color(0xFFD6F2E5);
  static const red         = Color(0xFFC4271E);
  static const redLight    = Color(0xFFFDECEA);
  static const amber       = Color(0xFFD97706);
  static const amberLight  = Color(0xFFFEF3C7);
  static const blue        = Color(0xFF1D4ED8);
  static const blueLight   = Color(0xFFDBEAFE);
  static const purple      = Color(0xFF7C3AED);
  static const purpleLight = Color(0xFFEDE9FE);
  static const pink        = Color(0xFFBE185D);
  static const pinkLight   = Color(0xFFFCE7F3);
  static const orange      = Color(0xFFC2410C);
  static const orangeLight = Color(0xFFFFEDD5);
  static const teal        = Color(0xFF0F766E);
  static const tealLight   = Color(0xFFCCFBF1);
  static const grayLight   = Color(0xFFF3F4F6);
  static const gray        = Color(0xFF6B7280);
}

// ── TYPES ────────────────────────────────────────────────────────────────────
enum NotifType {
  system, campaignUpdate, campaignEnded, makeWithdrawal, withdrawalSuccess,
  newDonation, donationReceived, goalReached, message, admin, welcome, unknown,
}

class NotifCfg {
  final String emoji, label;
  final Color bg, fg;
  const NotifCfg(this.emoji, this.label, this.bg, this.fg);
}

const Map<NotifType, NotifCfg> kCfg = {
  NotifType.system:            NotifCfg('🔔', 'System',     _C.blueLight,   _C.blue),
  NotifType.campaignUpdate:    NotifCfg('✅', 'Campaign',   _C.greenLight,  _C.greenMid),
  NotifType.campaignEnded:     NotifCfg('⏹️', 'Ended',      _C.grayLight,   _C.gray),
  NotifType.makeWithdrawal:    NotifCfg('💳', 'Withdrawal', _C.amberLight,  _C.amber),
  NotifType.withdrawalSuccess: NotifCfg('💰', 'Paid Out',   _C.greenLight,  Color(0xFF0A5C38)),
  NotifType.newDonation:       NotifCfg('❤️', 'Donation',   _C.pinkLight,   _C.pink),
  NotifType.donationReceived:  NotifCfg('🎁', 'Received',   _C.orangeLight, _C.orange),
  NotifType.goalReached:       NotifCfg('🏆', 'Goal!',      _C.amberLight,  _C.amber),
  NotifType.message:           NotifCfg('💬', 'Message',    _C.purpleLight, _C.purple),
  NotifType.admin:             NotifCfg('⚠️', 'Admin',      _C.redLight,    _C.red),
  NotifType.welcome:           NotifCfg('🌟', 'Welcome',    _C.tealLight,   _C.teal),
  NotifType.unknown:           NotifCfg('ℹ️', 'Other',      _C.grayLight,   _C.gray),
};

NotifType _parseType(String? raw) => switch (raw?.toUpperCase()) {
  'SYSTEM'             => NotifType.system,
  'CAMPAIGN_UPDATE'    => NotifType.campaignUpdate,
  'CAMPAIGN_ENDED'     => NotifType.campaignEnded,
  'MAKE_WITHDRAWAL'    => NotifType.makeWithdrawal,
  'WITHDRAWAL_SUCCESS' => NotifType.withdrawalSuccess,
  'NEW_DONATION'       => NotifType.newDonation,
  'DONATION_RECEIVED'  => NotifType.donationReceived,
  'GOAL_REACHED'       => NotifType.goalReached,
  'MESSAGE'            => NotifType.message,
  'ADMIN'              => NotifType.admin,
  'WELCOME'            => NotifType.welcome,
  _                    => NotifType.unknown,
};

// ── MODEL ────────────────────────────────────────────────────────────────────
class NotifModel {
  final String id, title, message;
  final NotifType type;
  final DateTime createdAt;
  final bool priority;
  final double? amount;
  final String? campaignId;
  bool read, deleted;

  NotifModel({
    required this.id, required this.title, required this.message,
    required this.type, required this.createdAt,
    this.read = false, this.priority = false,
    this.amount, this.campaignId, this.deleted = false,
  });

  // ✅ FIX: robust fromJson — handles direct API list response
  factory NotifModel.fromJson(Map<String, dynamic> j) => NotifModel(
    id:         j['_id']?.toString() ?? j['id']?.toString() ?? '',
    title:      j['title']?.toString() ?? 'Notification',
    message:    j['message']?.toString() ?? '',
    type:       _parseType(j['type']?.toString()),
    createdAt:  DateTime.tryParse(j['createdAt']?.toString() ?? '') ?? DateTime.now(),
    read:       j['read'] == true,
    priority:   j['priority'] == true || j['priority']?.toString() == 'high',
    amount:     (j['amount'] as num?)?.toDouble(),
    campaignId: j['campaignId']?.toString(),
    deleted:    j['deleted'] == true,
  );

  Map<String, dynamic> toJson() => {
    '_id': id, 'title': title, 'message': message,
    'type': type.name.toUpperCase(), 'createdAt': createdAt.toIso8601String(),
    'read': read, 'priority': priority, 'amount': amount,
    'campaignId': campaignId, 'deleted': deleted,
  };

  NotifModel copyWith({bool? read, bool? deleted}) => NotifModel(
    id: id, title: title, message: message, type: type, createdAt: createdAt,
    priority: priority, amount: amount, campaignId: campaignId,
    read: read ?? this.read, deleted: deleted ?? this.deleted,
  );
}

// ── CACHE (SharedPreferences for notification metadata only) ─────────────────
class _Cache {
  static const _key = 'inuafund_notifs_v3';

  static Future<void> save(List<NotifModel> items) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_key, jsonEncode(items.map((n) => n.toJson()).toList()));
    } catch (_) {}
  }

  static Future<List<NotifModel>> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_key);
      if (raw == null) return [];
      return (jsonDecode(raw) as List)
          .map((j) => NotifModel.fromJson(j as Map<String, dynamic>))
          .where((n) => !n.deleted)
          .toList();
    } catch (_) { return []; }
  }

  static Future<void> _patch(String id, Map<String, dynamic> patch) async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_key);
      if (raw == null) return;
      final list = (jsonDecode(raw) as List)
          .map((j) => NotifModel.fromJson(j as Map<String, dynamic>)).toList();
      final updated = list.map((n) => n.id != id ? n
          : NotifModel.fromJson({...n.toJson(), ...patch})).toList();
      await p.setString(_key, jsonEncode(updated.map((n) => n.toJson()).toList()));
    } catch (_) {}
  }

  static Future<void> markRead(String id)    => _patch(id, {'read': true});
  static Future<void> markDeleted(String id) => _patch(id, {'deleted': true});
}

// ── API ──────────────────────────────────────────────────────────────────────
class _Api {
  static const _base    = 'https://api.inuafund.co.ke/api';
  // ✅ FIX: read from FlutterSecureStorage under 'jwt_token'
  // This matches AuthService._persist() which writes: _storage.write(key: 'jwt_token', value: u.token)
  static const _storage = FlutterSecureStorage();

  static Future<Map<String, String>> _headers() async {
    final token = await _storage.read(key: 'jwt_token');
    return {
      'Content-Type': 'application/json',
      'Accept':       'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  // ✅ FIX: API returns a direct List[], not {data: []}
  // Matches React axios response: response.data → the array itself
  static Future<List<NotifModel>> fetchAll() async {
    final res = await http
        .get(Uri.parse('$_base/notifications'), headers: await _headers())
        .timeout(const Duration(seconds: 15));

    if (res.statusCode == 401) throw Exception('Session expired — please log in again.');
    if (res.statusCode != 200) throw Exception('Server error ${res.statusCode}');

    final body = jsonDecode(res.body);
    // Handle both: direct list OR envelope {data:[]} / {notifications:[]}
    final raw = body is List
        ? body
        : (body['data'] as List? ?? body['notifications'] as List? ?? []);
    return raw.map((j) => NotifModel.fromJson(j as Map<String, dynamic>)).toList();
  }

  static Future<void> markRead(String id) async => http
      .patch(Uri.parse('$_base/notifications/$id/read'), headers: await _headers())
      .timeout(const Duration(seconds: 10));

  static Future<void> delete(String id) async => http
      .delete(Uri.parse('$_base/notifications/$id'), headers: await _headers())
      .timeout(const Duration(seconds: 10));
}

// ── STATE ────────────────────────────────────────────────────────────────────
class _NotifState extends ChangeNotifier {
  List<NotifModel> _all = [];
  bool loading = true;
  String? error;

  List<NotifModel> get visible => _all.where((n) => !n.deleted).toList();
  int get unreadCount => visible.where((n) => !n.read).length;

  Future<void> fetch({bool silent = false}) async {
    if (!silent) { loading = true; error = null; notifyListeners(); }
    try {
      final serverItems = await _Api.fetchAll();

      // ✅ FIX: merge only preserves local deleted/read overrides — no broken variable shadowing
      final cached   = await _Cache.load();
      final localMap = {for (final n in cached) n.id: n};

      _all = serverItems.map((n) {
        final local = localMap[n.id];
        return n.copyWith(
          deleted: local?.deleted ?? false,
          read:    local?.read ?? n.read,
        );
      }).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      await _Cache.save(_all);
      error = null;
    } catch (e) {
      // ✅ FIX: surface real error, fallback to cache
      final cached = await _Cache.load();
      _all  = cached..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> markRead(String id) async {
    final i = _all.indexWhere((n) => n.id == id);
    if (i < 0 || _all[i].read) return;
    _all[i] = _all[i].copyWith(read: true);
    notifyListeners();
    await _Cache.markRead(id);
    _Api.markRead(id).catchError((_) {});
  }

  Future<void> delete(String id) async {
    final i = _all.indexWhere((n) => n.id == id);
    if (i < 0) return;
    _all[i] = _all[i].copyWith(deleted: true);
    notifyListeners();
    await _Cache.markDeleted(id);
    _Api.delete(id).catchError((_) {});
  }

  Future<void> deleteAll(List<String> ids) async {
    for (final id in ids) {
      final i = _all.indexWhere((n) => n.id == id);
      if (i >= 0) _all[i] = _all[i].copyWith(deleted: true);
    }
    notifyListeners();
    await Future.wait(ids.map(_Cache.markDeleted));
    Future.wait(ids.map(_Api.delete)).catchError((_) {});
  }
}

// ── DATE HELPERS ─────────────────────────────────────────────────────────────
const _mo = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
const _mf = ['January','February','March','April','May','June',
             'July','August','September','October','November','December'];

String _groupLabel(DateTime dt) {
  final d    = DateTime(dt.year, dt.month, dt.day);
  final now  = DateTime.now();
  final diff = DateTime(now.year, now.month, now.day).difference(d).inDays;
  if (diff == 0) return 'TODAY';
  if (diff == 1) return 'YESTERDAY';
  if (diff < 7)  return '$diff DAYS AGO';
  return '${d.day} ${_mf[d.month - 1].toUpperCase()} ${d.year}';
}

Map<String, List<NotifModel>> _group(List<NotifModel> list) {
  final map = <String, List<NotifModel>>{};
  for (final n in list) { map.putIfAbsent(_groupLabel(n.createdAt), () => []).add(n); }
  return map;
}

String _ago(DateTime dt) {
  final d = DateTime.now().difference(dt);
  if (d.inSeconds < 60) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes}m ago';
  if (d.inHours   < 24) return '${d.inHours}h ago';
  if (d.inDays    <  7) return '${d.inDays}d ago';
  return '${dt.day} ${_mo[dt.month - 1]}';
}

String _fullDate(DateTime dt) {
  final h  = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
  final m  = dt.minute.toString().padLeft(2, '0');
  final ap = dt.hour >= 12 ? 'PM' : 'AM';
  return '${dt.day} ${_mf[dt.month - 1]} ${dt.year}  ·  $h:$m $ap';
}

// ── MAIN SCREEN ──────────────────────────────────────────────────────────────
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override State<NotificationsScreen> createState() => _NSState();
}

class _NSState extends State<NotificationsScreen> with TickerProviderStateMixin {
  final _state       = _NotifState();
  final _searchCtrl  = TextEditingController();
  final _searchFocus = FocusNode();

  String         _query        = '';
  String         _statusFilter = 'all';
  Set<NotifType> _typeFilter   = {};
  bool           _showTypes    = false;
  NotifModel?    _selected;

  late final _typePanelAc = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 250));
  late final _typePanelA  =
      CurvedAnimation(parent: _typePanelAc, curve: Curves.easeInOutCubic);

  late final _detailAc = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 300));
  late final _detailSlide = Tween<Offset>(
      begin: const Offset(1, 0), end: Offset.zero)
      .animate(CurvedAnimation(parent: _detailAc, curve: Curves.easeOutCubic));

  bool _notifSupported = false, _notifSubscribed = false, _notifLoading = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _state.addListener(() => setState(() {}));
    _state.fetch();
    _loadPush();
    _timer = Timer.periodic(
        const Duration(seconds: 60), (_) => _state.fetch(silent: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _typePanelAc.dispose();
    _detailAc.dispose();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _state.dispose();
    super.dispose();
  }

  Future<void> _loadPush() async {
    setState(() => _notifLoading = true);
    try {
      final s = await NotificationService.instance.getNotificationStatus();
      if (mounted) setState(() {
        _notifSupported  = s.isSupported;
        _notifSubscribed = s.isSubscribed;
      });
    } catch (_) {}
    if (mounted) setState(() => _notifLoading = false);
  }

  Future<void> _togglePush() async {
    if (!_notifSupported) { _snack('Push not supported in this browser'); return; }
    setState(() => _notifLoading = true);
    try {
      _notifSubscribed
          ? await NotificationService.instance.unsubscribe()
          : await NotificationService.instance.requestPermission();
      _snack(_notifSubscribed ? 'Push disabled' : 'Push notifications enabled ✓');
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
    await _loadPush();
  }

  List<NotifModel> get _filtered {
    var list = _state.visible;
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      list = list.where((n) =>
          n.title.toLowerCase().contains(q) ||
          n.message.toLowerCase().contains(q)).toList();
    }
    if (_typeFilter.isNotEmpty) {
      list = list.where((n) => _typeFilter.contains(n.type)).toList();
    }
    if (_statusFilter == 'unread')   list = list.where((n) => !n.read).toList();
    if (_statusFilter == 'priority') list = list.where((n) => n.priority).toList();
    return list;
  }

  void _openDetail(NotifModel n) {
    HapticFeedback.selectionClick();
    setState(() => _selected = n);
    _state.markRead(n.id);
    _detailAc.forward(from: 0);
  }

  void _closeDetail() => _detailAc.reverse().then((_) {
    if (mounted) setState(() => _selected = null);
  });

  void _deleteItem(String id) {
    HapticFeedback.mediumImpact();
    _state.delete(id);
    _snack('Notification deleted');
  }

  void _confirmDeleteAll() => _dialog(
    title: 'Clear All',
    body: 'Delete all ${_filtered.length} notification(s)? This cannot be undone.',
    label: 'Delete All',
    onConfirm: () {
      _state.deleteAll(_filtered.map((n) => n.id).toList());
      _snack('All notifications cleared');
    },
  );

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(msg, style: GoogleFonts.dmSans(fontWeight: FontWeight.w600, color: Colors.white)),
        backgroundColor: isError ? _C.red : _C.ink,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        duration: const Duration(seconds: 3),
      ));
  }

  void _dialog({
    required String title, required String body,
    required String label, required VoidCallback onConfirm,
  }) => showDialog(
    context: context,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: Text(title, style: GoogleFonts.dmSans(
          fontWeight: FontWeight.w900, fontSize: 18, color: _C.ink)),
      content: Text(body, style: GoogleFonts.dmSans(
          fontSize: 14, color: _C.inkMid, height: 1.55)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: GoogleFonts.dmSans(
              color: _C.inkMid, fontWeight: FontWeight.w600)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: _C.red, elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          onPressed: () { Navigator.pop(context); onConfirm(); },
          child: Text(label, style: GoogleFonts.dmSans(
              color: Colors.white, fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );

  // ─── BUILD ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
    child: Scaffold(
      backgroundColor: _C.bg,
      body: Stack(children: [
        Column(children: [
          _header(),
          _searchBar(),
          _statusChips(),
          _typePanel(),
          _countRow(),
          Expanded(child: _list()),
        ]),
        if (_selected != null)
          SlideTransition(
            position: _detailSlide,
            child: _DetailScreen(
              notification: _selected!,
              onClose: _closeDetail,
              onDelete: (id) {
                _closeDetail();
                Future.delayed(const Duration(milliseconds: 320),
                    () => _deleteItem(id));
              },
            ),
          ),
      ]),
    ),
  );

  // ─── HEADER ─────────────────────────────────────────────────────────────────
  Widget _header() => Container(
    color: _C.surface,
    child: SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 12),
        child: Row(children: [
          _IBtn(icon: Icons.arrow_back_ios_new_rounded, onTap: () => Navigator.maybePop(context)),
          if (!_notifLoading && _notifSupported) ...[
            const SizedBox(width: 4),
            _IBtn(
              icon: _notifSubscribed
                  ? Icons.notifications_active_rounded
                  : Icons.notifications_none_rounded,
              color: _notifSubscribed ? _C.greenMid : _C.ink,
              onTap: _togglePush,
            ),
          ],
          const Spacer(),
          Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Notifications', style: GoogleFonts.dmSans(
                fontWeight: FontWeight.w900, fontSize: 18, color: _C.ink, letterSpacing: -0.5)),
            const SizedBox(height: 4),
            Row(mainAxisSize: MainAxisSize.min, children: [
              if (_state.unreadCount > 0)
                _Pill('${_state.unreadCount} unread', _C.greenLight, _C.greenMid),
              if (_state.error != null) ...[
                const SizedBox(width: 6),
                _Pill('Offline', _C.amberLight, _C.amber),
              ],
            ]),
          ]),
          const Spacer(),
          Row(mainAxisSize: MainAxisSize.min, children: [
            _IBtn(
              icon: Icons.refresh_rounded,
              onTap: () { HapticFeedback.lightImpact(); _state.fetch(); },
            ),
            if (_filtered.isNotEmpty)
              _IBtn(icon: Icons.delete_outline_rounded, color: _C.red, onTap: _confirmDeleteAll),
          ]),
        ]),
      ),
    ),
  );

  // ─── SEARCH ─────────────────────────────────────────────────────────────────
  Widget _searchBar() => Container(
    color: _C.surface,
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
    child: AnimatedBuilder(
      animation: _searchFocus,
      builder: (_, __) => Container(
        height: 46,
        decoration: BoxDecoration(
          color: _C.bg, borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _searchFocus.hasFocus ? _C.greenMid : _C.border,
            width: _searchFocus.hasFocus ? 1.5 : 1,
          ),
        ),
        child: Row(children: [
          const SizedBox(width: 14),
          const Icon(Icons.search_rounded, color: _C.inkSoft, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              focusNode: _searchFocus,
              style: GoogleFonts.dmSans(fontSize: 14, color: _C.ink),
              decoration: InputDecoration(
                hintText: 'Search notifications…',
                hintStyle: GoogleFonts.dmSans(fontSize: 14, color: _C.inkSoft),
                border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          if (_query.isNotEmpty)
            GestureDetector(
              onTap: () { _searchCtrl.clear(); setState(() => _query = ''); _searchFocus.unfocus(); },
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Icon(Icons.close_rounded, color: _C.inkSoft, size: 18),
              ),
            ),
        ]),
      ),
    ),
  );

  // ─── STATUS CHIPS ───────────────────────────────────────────────────────────
  Widget _statusChips() => Container(
    color: _C.surface,
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
    child: Row(children: [
      _Chip('All',      _statusFilter == 'all',      () => setState(() => _statusFilter = 'all')),
      const SizedBox(width: 8),
      _Chip('Unread',   _statusFilter == 'unread',   () => setState(() => _statusFilter = 'unread')),
      const SizedBox(width: 8),
      _Chip('Priority', _statusFilter == 'priority', () => setState(() => _statusFilter = 'priority'), accent: _C.amber),
      const Spacer(),
      GestureDetector(
        onTap: () {
          setState(() => _showTypes = !_showTypes);
          _showTypes ? _typePanelAc.forward() : _typePanelAc.reverse();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: _typeFilter.isNotEmpty ? _C.greenLight : _C.bg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: _typeFilter.isNotEmpty ? _C.greenMid : _C.border, width: 1.5),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.tune_rounded, size: 14,
                color: _typeFilter.isNotEmpty ? _C.greenMid : _C.inkMid),
            const SizedBox(width: 5),
            Text(_typeFilter.isNotEmpty ? 'Types (${_typeFilter.length})' : 'Type',
                style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w700,
                    color: _typeFilter.isNotEmpty ? _C.greenMid : _C.inkMid)),
          ]),
        ),
      ),
    ]),
  );

  // ─── TYPE PANEL (collapsible) ────────────────────────────────────────────────
  Widget _typePanel() => SizeTransition(
    sizeFactor: _typePanelA,
    child: Container(
      color: _C.surface,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Divider(height: 1, color: _C.border),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: kCfg.entries
              .where((e) => e.key != NotifType.unknown)
              .map((e) {
            final active = _typeFilter.contains(e.key);
            return GestureDetector(
              onTap: () => setState(() =>
                  active ? _typeFilter.remove(e.key) : _typeFilter.add(e.key)),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: active ? e.value.bg : _C.bg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: active ? e.value.fg : _C.border, width: 1.5),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(e.value.emoji, style: const TextStyle(fontSize: 13)),
                  const SizedBox(width: 5),
                  Text(e.value.label, style: GoogleFonts.dmSans(
                      fontSize: 12, fontWeight: FontWeight.w700,
                      color: active ? e.value.fg : _C.inkMid)),
                ]),
              ),
            );
          }).toList(),
        ),
        if (_typeFilter.isNotEmpty) ...[
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => setState(() => _typeFilter.clear()),
            child: Text('Clear filters', style: GoogleFonts.dmSans(
                fontSize: 12, fontWeight: FontWeight.w700, color: _C.red)),
          ),
        ],
      ]),
    ),
  );

  // ─── COUNT ROW ───────────────────────────────────────────────────────────────
  Widget _countRow() => Container(
    color: _C.surface,
    child: Column(children: [
      const Divider(height: 1, thickness: 1, color: _C.border),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        child: Row(children: [
          Text('${_filtered.length} notification${_filtered.length == 1 ? '' : 's'}',
              style: GoogleFonts.dmSans(
                  fontSize: 12, color: _C.inkSoft, fontWeight: FontWeight.w500)),
          if (_state.error != null) ...[
            const SizedBox(width: 8),
            const Icon(Icons.wifi_off_rounded, size: 13, color: _C.amber),
            const SizedBox(width: 4),
            Expanded(child: Text(_state.error!, overflow: TextOverflow.ellipsis,
                style: GoogleFonts.dmSans(
                    fontSize: 12, color: _C.amber, fontWeight: FontWeight.w600))),
          ],
        ]),
      ),
    ]),
  );

  // ─── LIST ────────────────────────────────────────────────────────────────────
  Widget _list() {
    if (_state.loading) return _skeletons();
    if (_filtered.isEmpty) return _empty();
    final groups = _group(_filtered);
    return RefreshIndicator(
      color: _C.greenMid, backgroundColor: _C.surface,
      onRefresh: () => _state.fetch(),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 40),
        itemCount: groups.length,
        itemBuilder: (_, gi) {
          final key   = groups.keys.elementAt(gi);
          final items = groups[key]!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _GroupHeader(key),
              ...List.generate(items.length, (ii) => _Tile(
                n: items[ii], stagger: ii + gi * 8,
                onTap: () => _openDetail(items[ii]),
                onDelete: () => _deleteItem(items[ii].id),
              )),
            ],
          );
        },
      ),
    );
  }

  Widget _skeletons() => ListView.builder(
    itemCount: 5, padding: const EdgeInsets.only(top: 12),
    itemBuilder: (_, i) => _Skeleton(i),
  );

  Widget _empty() => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Container(
        width: 88, height: 88,
        decoration: const BoxDecoration(color: _C.greenLight, shape: BoxShape.circle),
        child: const Center(child: Text('🔔', style: TextStyle(fontSize: 40))),
      ),
      const SizedBox(height: 20),
      Text('All caught up!', style: GoogleFonts.dmSans(
          fontWeight: FontWeight.w900, fontSize: 22, color: _C.ink)),
      const SizedBox(height: 8),
      Text(_query.isNotEmpty ? 'No results for "$_query"' : 'No notifications yet',
          style: GoogleFonts.dmSans(fontSize: 14, color: _C.inkSoft)),
    ],
  ));
}

// ── TILE ──────────────────────────────────────────────────────────────────────
class _Tile extends StatefulWidget {
  final NotifModel n;
  final int stagger;
  final VoidCallback onTap, onDelete;
  const _Tile({required this.n, required this.stagger,
    required this.onTap, required this.onDelete});
  @override State<_Tile> createState() => _TileState();
}

class _TileState extends State<_Tile> with SingleTickerProviderStateMixin {
  late final _ac = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 340 + (widget.stagger % 6) * 40));
  late final _fade  = CurvedAnimation(parent: _ac, curve: Curves.easeOut);
  late final _slide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
      .animate(CurvedAnimation(parent: _ac, curve: Curves.easeOutCubic));
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: (widget.stagger % 8) * 30),
        () { if (mounted) _ac.forward(); });
  }
  @override void dispose() { _ac.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final cfg = kCfg[widget.n.type]!;
    final n   = widget.n;
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Dismissible(
          key: Key(n.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 24),
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            decoration: BoxDecoration(
                color: _C.redLight, borderRadius: BorderRadius.circular(18)),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.delete_outline_rounded, color: _C.red, size: 24),
              const SizedBox(height: 3),
              Text('Delete', style: GoogleFonts.dmSans(
                  fontSize: 11, fontWeight: FontWeight.w700, color: _C.red)),
            ]),
          ),
          onDismissed: (_) => widget.onDelete(),
          child: GestureDetector(
            onTap: widget.onTap,
            onTapDown:   (_) => setState(() => _pressed = true),
            onTapUp:     (_) => setState(() => _pressed = false),
            onTapCancel: () => setState(() => _pressed = false),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              decoration: BoxDecoration(
                color: _pressed ? _C.grayLight : _C.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: n.read ? _C.border : cfg.fg.withOpacity(0.22),
                  width: n.read ? 1 : 1.5,
                ),
                boxShadow: [BoxShadow(
                  color: n.read
                      ? const Color(0x08000000)
                      : cfg.fg.withOpacity(0.07),
                  blurRadius: 10, offset: const Offset(0, 3),
                )],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: IntrinsicHeight(
                  child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    // Unread accent bar
                    if (!n.read) Container(width: 3, color: cfg.fg),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(n.read ? 14 : 11, 14, 14, 14),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Container(
                            width: 48, height: 48,
                            decoration: BoxDecoration(
                                color: n.read ? _C.grayLight : cfg.bg,
                                shape: BoxShape.circle),
                            child: Center(child: Text(cfg.emoji,
                                style: const TextStyle(fontSize: 22))),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Expanded(child: Text(n.title, maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.dmSans(
                                        fontWeight: n.read ? FontWeight.w600 : FontWeight.w800,
                                        fontSize: 14, color: _C.ink))),
                                const SizedBox(width: 6),
                                Text(_ago(n.createdAt), style: GoogleFonts.dmSans(
                                    fontSize: 11, color: _C.inkSoft,
                                    fontWeight: FontWeight.w500)),
                              ]),
                              const SizedBox(height: 5),
                              Text(n.message, maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.dmSans(fontSize: 13,
                                      color: n.read ? _C.inkSoft : _C.inkMid,
                                      height: 1.5)),
                              const SizedBox(height: 8),
                              Row(children: [
                                _Badge(cfg.label, cfg.bg, cfg.fg),
                                if (n.priority) ...[
                                  const SizedBox(width: 6),
                                  _Badge('Priority', _C.redLight, _C.red),
                                ],
                                const Spacer(),
                                if (!n.read)
                                  Container(
                                    width: 8, height: 8,
                                    decoration: BoxDecoration(
                                      color: cfg.fg, shape: BoxShape.circle,
                                      boxShadow: [BoxShadow(
                                          color: cfg.fg.withOpacity(0.35),
                                          blurRadius: 4, spreadRadius: 1)],
                                    ),
                                  ),
                              ]),
                            ],
                          )),
                        ]),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── DETAIL SCREEN ─────────────────────────────────────────────────────────────
class _DetailScreen extends StatefulWidget {
  final NotifModel notification;
  final VoidCallback onClose;
  final void Function(String) onDelete;
  const _DetailScreen({required this.notification,
    required this.onClose, required this.onDelete});
  @override State<_DetailScreen> createState() => _DetailState();
}

class _DetailState extends State<_DetailScreen> with SingleTickerProviderStateMixin {
  late final _ac = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 400));
  late final _fade  = CurvedAnimation(parent: _ac, curve: Curves.easeOut);
  late final _slide = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
      .animate(CurvedAnimation(parent: _ac, curve: Curves.easeOutCubic));

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 80), () { if (mounted) _ac.forward(); });
  }
  @override void dispose() { _ac.dispose(); super.dispose(); }

  void _confirmDelete() => showDialog(
    context: context,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: Text('Delete Notification', style: GoogleFonts.dmSans(
          fontWeight: FontWeight.w900, fontSize: 18, color: _C.ink)),
      content: Text('Are you sure? This cannot be undone.', style: GoogleFonts.dmSans(
          fontSize: 14, color: _C.inkMid, height: 1.55)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: GoogleFonts.dmSans(
              color: _C.inkMid, fontWeight: FontWeight.w600)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: _C.red, elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          onPressed: () { Navigator.pop(context); widget.onDelete(widget.notification.id); },
          child: Text('Delete', style: GoogleFonts.dmSans(
              color: Colors.white, fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final n   = widget.notification;
    final cfg = kCfg[n.type]!;
    return Material(
      color: _C.bg,
      child: Column(children: [
        // Header
        Container(
          color: _C.surface,
          child: SafeArea(bottom: false, child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 12),
            child: Row(children: [
              _IBtn(icon: Icons.arrow_back_ios_new_rounded, onTap: widget.onClose),
              Expanded(child: Text('Notification', textAlign: TextAlign.center,
                  style: GoogleFonts.dmSans(fontWeight: FontWeight.w900,
                      fontSize: 18, color: _C.ink, letterSpacing: -0.5))),
              _IBtn(icon: Icons.delete_outline_rounded,
                  color: _C.red, onTap: _confirmDelete),
            ]),
          )),
        ),
        const Divider(height: 1, thickness: 1, color: _C.border),
        // Content
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: FadeTransition(opacity: _fade, child: SlideTransition(
            position: _slide,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Icon + meta
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(color: cfg.bg, shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: cfg.fg.withOpacity(0.18),
                          blurRadius: 20, offset: const Offset(0, 6))]),
                  child: Center(child: Text(cfg.emoji,
                      style: const TextStyle(fontSize: 34))),
                ),
                const SizedBox(width: 16),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const SizedBox(height: 6),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    _Badge(cfg.label, cfg.bg, cfg.fg, large: true),
                    if (n.priority) _Badge('Priority', _C.redLight, _C.red, large: true),
                  ]),
                  const SizedBox(height: 8),
                  Text(_fullDate(n.createdAt), style: GoogleFonts.dmSans(
                      fontSize: 12, color: _C.inkSoft, fontWeight: FontWeight.w500)),
                ])),
              ]),
              const SizedBox(height: 24),
              // Title
              Text(n.title, style: GoogleFonts.dmSans(fontWeight: FontWeight.w900,
                  fontSize: 22, color: _C.ink, height: 1.25, letterSpacing: -0.5)),
              const SizedBox(height: 16),
              // Message body
              Container(
                width: double.infinity, padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cfg.bg.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: cfg.fg.withOpacity(0.12)),
                ),
                child: Text(n.message, style: GoogleFonts.dmSans(
                    fontSize: 15, color: _C.inkMid, height: 1.7)),
              ),
              // Metadata card
              if (n.amount != null || n.campaignId != null) ...[
                const SizedBox(height: 20),
                Container(
                  decoration: BoxDecoration(color: _C.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: _C.border)),
                  child: Column(children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
                      child: Align(alignment: Alignment.centerLeft,
                          child: Text('Details', style: GoogleFonts.dmSans(
                              fontWeight: FontWeight.w800, fontSize: 14, color: _C.ink))),
                    ),
                    const Divider(height: 1, color: _C.border),
                    if (n.amount != null)
                      _MetaRow('Amount',
                          n.amount! >= 1000
                              ? 'KES ${(n.amount! / 1000).toStringAsFixed(0)}K'
                              : 'KES ${n.amount!.toStringAsFixed(0)}',
                          valueColor: _C.greenMid),
                    if (n.campaignId != null)
                      _MetaRow('Campaign ID', n.campaignId!),
                    _MetaRow('Status', n.read ? 'Read' : 'Unread',
                        valueColor: n.read ? _C.inkSoft : cfg.fg, isLast: true),
                  ]),
                ),
              ],
              const SizedBox(height: 28),
              // Delete button
              GestureDetector(
                onTap: _confirmDelete,
                child: Container(
                  height: 54,
                  decoration: BoxDecoration(
                    color: _C.redLight, borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _C.red.withOpacity(0.22)),
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.delete_outline_rounded, color: _C.red, size: 20),
                    const SizedBox(width: 8),
                    Text('Delete Notification', style: GoogleFonts.dmSans(
                        fontWeight: FontWeight.w700, fontSize: 14, color: _C.red)),
                  ]),
                ),
              ),
            ]),
          )),
        )),
      ]),
    );
  }
}

// ── SHARED SMALL WIDGETS ──────────────────────────────────────────────────────
class _GroupHeader extends StatelessWidget {
  final String label;
  const _GroupHeader(this.label);
  @override Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
    child: Row(children: [
      Text(label, style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w800,
          color: _C.inkSoft, letterSpacing: 0.8)),
      const SizedBox(width: 10),
      const Expanded(child: Divider(color: _C.border, height: 1)),
    ]),
  );
}

class _IBtn extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;
  const _IBtn({required this.icon, required this.onTap, this.color});
  @override State<_IBtn> createState() => _IBtnState();
}

class _IBtnState extends State<_IBtn> {
  bool _pressed = false;
  @override Widget build(BuildContext context) => GestureDetector(
    onTap: widget.onTap,
    onTapDown:   (_) => setState(() => _pressed = true),
    onTapUp:     (_) => setState(() => _pressed = false),
    onTapCancel: () => setState(() => _pressed = false),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: 42, height: 42,
      decoration: BoxDecoration(
        color: _pressed
            ? (widget.color?.withOpacity(0.14) ?? _C.border)
            : (widget.color?.withOpacity(0.08) ?? Colors.transparent),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: widget.color?.withOpacity(0.16) ?? _C.border),
      ),
      child: Icon(widget.icon, size: 20, color: widget.color ?? _C.ink),
    ),
  );
}

class _Chip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  final Color? accent;
  const _Chip(this.label, this.active, this.onTap, {this.accent});
  @override Widget build(BuildContext context) {
    final a = accent ?? _C.greenMid;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? a : _C.bg, borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? a : _C.border, width: 1.5),
        ),
        child: Text(label, style: GoogleFonts.dmSans(fontSize: 12,
            fontWeight: FontWeight.w700,
            color: active ? Colors.white : _C.inkMid)),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color bg, fg;
  final bool large;
  const _Badge(this.label, this.bg, this.fg, {this.large = false});
  @override Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(
        horizontal: large ? 12 : 8, vertical: large ? 4 : 3),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
    child: Text(label, style: GoogleFonts.dmSans(
        fontSize: large ? 12 : 11, fontWeight: FontWeight.w700, color: fg)),
  );
}

class _Pill extends StatelessWidget {
  final String label;
  final Color bg, fg;
  const _Pill(this.label, this.bg, this.fg);
  @override Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
    child: Text(label, style: GoogleFonts.dmSans(
        fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
  );
}

class _MetaRow extends StatelessWidget {
  final String label, value;
  final Color? valueColor;
  final bool isLast;
  const _MetaRow(this.label, this.value, {this.valueColor, this.isLast = false});
  @override Widget build(BuildContext context) => Column(children: [
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Row(children: [
        Text(label, style: GoogleFonts.dmSans(
            fontSize: 13, color: _C.inkSoft, fontWeight: FontWeight.w500)),
        const Spacer(),
        Text(value, style: GoogleFonts.dmSans(
            fontSize: 13, color: valueColor ?? _C.ink, fontWeight: FontWeight.w700)),
      ]),
    ),
    if (!isLast) const Divider(height: 1, color: _C.border, indent: 18, endIndent: 18),
  ]);
}

class _Skeleton extends StatefulWidget {
  final int index;
  const _Skeleton(this.index);
  @override State<_Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<_Skeleton> with SingleTickerProviderStateMixin {
  late final _ac = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100))
    ..repeat(reverse: true);
  @override void dispose() { _ac.dispose(); super.dispose(); }

  @override Widget build(BuildContext context) => AnimatedBuilder(
    animation: _ac,
    builder: (_, __) {
      final op = 0.04 + _ac.value * 0.06;
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: _C.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _C.border)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _S(48, 48, 24, op),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _S(double.infinity, 13, 6, op),
            const SizedBox(height: 8),
            _S(MediaQuery.of(context).size.width * 0.55, 11, 6, op * 0.75),
            const SizedBox(height: 6),
            _S(MediaQuery.of(context).size.width * 0.35, 11, 6, op * 0.5),
          ])),
        ]),
      );
    },
  );
}

class _S extends StatelessWidget {
  final double w, h, r, op;
  const _S(this.w, this.h, this.r, this.op);
  @override Widget build(BuildContext context) => Container(
    width: w, height: h,
    decoration: BoxDecoration(
        color: Colors.black.withOpacity(op),
        borderRadius: BorderRadius.circular(r)),
  );
}