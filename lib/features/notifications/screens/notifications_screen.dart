// ═══════════════════════════════════════════════════════════════════════════════
// notifications_screen.dart
// InuaFund — Refined Notifications UI
// Features: live API, IndexedDB-style cache via shared_preferences, search,
//           filter, swipe-to-delete, detail overlay, push toggle, animations
// ═══════════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/network/notification_service_web.dart';

// ─────────────────────────────────────────────────────────────────────────────
// THEME TOKENS
// ─────────────────────────────────────────────────────────────────────────────

class _C {
  static const bg          = Color(0xFFF4F6F5);
  static const surface     = Color(0xFFFFFFFF);
  static const border      = Color(0xFFE8EBE9);
  static const ink         = Color(0xFF0D1F18);
  static const inkMid      = Color(0xFF3D5248);
  static const inkSoft     = Color(0xFF8FA89D);
  static const green       = Color(0xFF0A5C38);
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
  static const shadow      = Color(0x08000000);
}

// ─────────────────────────────────────────────────────────────────────────────
// NOTIFICATION TYPE CONFIG
// ─────────────────────────────────────────────────────────────────────────────

enum NotifType {
  system,
  campaignUpdate,
  campaignEnded,
  makeWithdrawal,
  withdrawalSuccess,
  newDonation,
  donationReceived,
  goalReached,
  message,
  admin,
  welcome,
  unknown,
}

class NotifTypeCfg {
  final String emoji;
  final Color bg;
  final Color fg;
  final String label;
  const NotifTypeCfg({
    required this.emoji,
    required this.bg,
    required this.fg,
    required this.label,
  });
}

const Map<NotifType, NotifTypeCfg> kNotifTypes = {
  NotifType.system:             NotifTypeCfg(emoji: '🔔', bg: _C.blueLight,   fg: _C.blue,     label: 'System'),
  NotifType.campaignUpdate:     NotifTypeCfg(emoji: '✅', bg: _C.greenLight,  fg: _C.greenMid, label: 'Campaign'),
  NotifType.campaignEnded:      NotifTypeCfg(emoji: '⏹️', bg: _C.grayLight,   fg: _C.gray,     label: 'Ended'),
  NotifType.makeWithdrawal:     NotifTypeCfg(emoji: '💳', bg: _C.amberLight,  fg: _C.amber,    label: 'Withdrawal'),
  NotifType.withdrawalSuccess:  NotifTypeCfg(emoji: '💰', bg: _C.greenLight,  fg: _C.green,    label: 'Paid Out'),
  NotifType.newDonation:        NotifTypeCfg(emoji: '❤️',  bg: _C.pinkLight,   fg: _C.pink,     label: 'Donation'),
  NotifType.donationReceived:   NotifTypeCfg(emoji: '🎁', bg: _C.orangeLight, fg: _C.orange,   label: 'Received'),
  NotifType.goalReached:        NotifTypeCfg(emoji: '🏆', bg: _C.amberLight,  fg: _C.amber,    label: 'Goal!'),
  NotifType.message:            NotifTypeCfg(emoji: '💬', bg: _C.purpleLight, fg: _C.purple,   label: 'Message'),
  NotifType.admin:              NotifTypeCfg(emoji: '⚠️',  bg: _C.redLight,    fg: _C.red,      label: 'Admin'),
  NotifType.welcome:            NotifTypeCfg(emoji: '🌟', bg: _C.tealLight,   fg: _C.teal,     label: 'Welcome'),
  NotifType.unknown:            NotifTypeCfg(emoji: 'ℹ️',  bg: _C.grayLight,   fg: _C.gray,     label: 'Other'),
};

NotifType _parseType(String? raw) {
  switch (raw?.toUpperCase()) {
    case 'SYSTEM':             return NotifType.system;
    case 'CAMPAIGN_UPDATE':    return NotifType.campaignUpdate;
    case 'CAMPAIGN_ENDED':     return NotifType.campaignEnded;
    case 'MAKE_WITHDRAWAL':    return NotifType.makeWithdrawal;
    case 'WITHDRAWAL_SUCCESS': return NotifType.withdrawalSuccess;
    case 'NEW_DONATION':       return NotifType.newDonation;
    case 'DONATION_RECEIVED':  return NotifType.donationReceived;
    case 'GOAL_REACHED':       return NotifType.goalReached;
    case 'MESSAGE':            return NotifType.message;
    case 'ADMIN':              return NotifType.admin;
    case 'WELCOME':            return NotifType.welcome;
    default:                   return NotifType.unknown;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MODEL
// ─────────────────────────────────────────────────────────────────────────────

class NotificationModel {
  final String id;
  final String title;
  final String message;
  final NotifType type;
  final DateTime createdAt;
  final bool priority;
  final double? amount;
  final String? campaignId;
  bool read;
  bool deleted;

  NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.createdAt,
    this.read = false,
    this.priority = false,
    this.amount,
    this.campaignId,
    this.deleted = false,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> j) {
    return NotificationModel(
      id:         j['_id']?.toString() ?? j['id']?.toString() ?? '',
      title:      j['title']?.toString() ?? '',
      message:    j['message']?.toString() ?? '',
      type:       _parseType(j['type']?.toString()),
      createdAt:  j['createdAt'] != null
          ? DateTime.tryParse(j['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      read:       j['read'] == true,
      priority:   j['priority'] == true || j['priority'] == 'high',
      amount:     j['amount'] != null ? (j['amount'] as num).toDouble() : null,
      campaignId: j['campaignId']?.toString(),
      deleted:    j['deleted'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    '_id':        id,
    'title':      title,
    'message':    message,
    'type':       type.name.toUpperCase(),
    'createdAt':  createdAt.toIso8601String(),
    'read':       read,
    'priority':   priority,
    'amount':     amount,
    'campaignId': campaignId,
    'deleted':    deleted,
  };

  NotificationModel copyWith({bool? read, bool? deleted}) => NotificationModel(
    id: id, title: title, message: message, type: type,
    createdAt: createdAt, priority: priority, amount: amount, campaignId: campaignId,
    read: read ?? this.read,
    deleted: deleted ?? this.deleted,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// LOCAL CACHE (shared_preferences)
// ─────────────────────────────────────────────────────────────────────────────

class _Cache {
  static const _key = 'inuafund_notifications_v2';

  static Future<void> save(List<NotificationModel> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(items.map((n) => n.toJson()).toList());
      await prefs.setString(_key, encoded);
    } catch (_) {}
  }

  static Future<List<NotificationModel>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return [];
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((j) => NotificationModel.fromJson(j as Map<String, dynamic>))
          .where((n) => !n.deleted)
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> markDeleted(String id) async {
    final items = await load();
    // Include deleted ones for this operation
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return;
      final list = (jsonDecode(raw) as List<dynamic>)
          .map((j) => NotificationModel.fromJson(j as Map<String, dynamic>))
          .toList();
      final updated = list.map((n) => n.id == id ? n.copyWith(deleted: true) : n).toList();
      await prefs.setString(_key, jsonEncode(updated.map((n) => n.toJson()).toList()));
    } catch (_) {}
  }

  static Future<void> markRead(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return;
      final list = (jsonDecode(raw) as List<dynamic>)
          .map((j) => NotificationModel.fromJson(j as Map<String, dynamic>))
          .toList();
      final updated = list.map((n) => n.id == id ? n.copyWith(read: true) : n).toList();
      await prefs.setString(_key, jsonEncode(updated.map((n) => n.toJson()).toList()));
    } catch (_) {}
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// API SERVICE
// ─────────────────────────────────────────────────────────────────────────────

class _Api {
  static const _base = 'https://api.inuafund.co.ke/api';

  static Future<String?> _token() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  static Future<Map<String, String>> _headers() async {
    final token = await _token();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Fetch all notifications from server
  static Future<List<NotificationModel>> fetchNotifications() async {
    final headers = await _headers();
    final res = await http
        .get(Uri.parse('$_base/notifications'), headers: headers)
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw Exception('Server returned ${res.statusCode}');
    }
    final body = jsonDecode(res.body);
    final list = body is List ? body : (body['data'] as List? ?? []);
    return list
        .map((j) => NotificationModel.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  /// Delete a notification on server
  static Future<void> deleteNotification(String id) async {
    final headers = await _headers();
    await http
        .delete(Uri.parse('$_base/notifications/$id'), headers: headers)
        .timeout(const Duration(seconds: 10));
  }

  /// Mark notification as read on server
  static Future<void> markRead(String id) async {
    final headers = await _headers();
    await http
        .patch(Uri.parse('$_base/notifications/$id/read'), headers: headers)
        .timeout(const Duration(seconds: 10));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STATE MANAGER (ChangeNotifier)
// ─────────────────────────────────────────────────────────────────────────────

class NotificationsState extends ChangeNotifier {
  List<NotificationModel> _all = [];
  bool _loading = true;
  String? _error;

  List<NotificationModel> get visible => _all.where((n) => !n.deleted).toList();
  bool get loading => _loading;
  String? get error => _error;
  int get unreadCount => visible.where((n) => !n.read).length;

  /// Primary fetch: try server first, fallback to cache
  Future<void> fetch({bool silent = false}) async {
    if (!silent) {
      _loading = true;
      _error = null;
      notifyListeners();
    }

    try {
      final serverItems = await _Api.fetchNotifications();
      // Merge: keep local deleted flags
      final cached = await _Cache.load();
      final deletedIds = <String>{};
      // Load raw to get deleted ones
      try {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString('inuafund_notifications_v2');
        if (raw != null) {
          final list = (jsonDecode(raw) as List<dynamic>)
              .map((j) => NotificationModel.fromJson(j as Map<String, dynamic>))
              .toList();
          deletedIds.addAll(list.where((n) => n.deleted).map((n) => n.id));
        }
      } catch (_) {}

      _all = serverItems.map((n) => n.deleted || deletedIds.contains(n.id)
          ? n.copyWith(deleted: true)
          : n).toList();

      await _Cache.save(_all);
    } catch (e) {
      // Fallback to cache
      final cached = await _Cache.load();
      if (cached.isNotEmpty) {
        _all = cached;
        _error = 'Offline — showing cached data';
      } else {
        _error = 'Failed to load notifications';
      }
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> markRead(String id) async {
    final idx = _all.indexWhere((n) => n.id == id);
    if (idx >= 0 && !_all[idx].read) {
      _all[idx] = _all[idx].copyWith(read: true);
      notifyListeners();
      await _Cache.markRead(id);
      _Api.markRead(id).catchError((_) {});
    }
  }

  Future<void> delete(String id) async {
    final idx = _all.indexWhere((n) => n.id == id);
    if (idx >= 0) {
      _all[idx] = _all[idx].copyWith(deleted: true);
      notifyListeners();
      await _Cache.markDeleted(id);
      _Api.deleteNotification(id).catchError((_) {});
    }
  }

  Future<void> deleteAll(List<String> ids) async {
    for (final id in ids) {
      final idx = _all.indexWhere((n) => n.id == id);
      if (idx >= 0) _all[idx] = _all[idx].copyWith(deleted: true);
    }
    notifyListeners();
    await Future.wait(ids.map((id) => _Cache.markDeleted(id)));
    if (ids.isNotEmpty) {
      Future.wait(ids.map((id) => _Api.deleteNotification(id))).catchError((_) {});
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DATE GROUP HELPERS
// ─────────────────────────────────────────────────────────────────────────────

const _months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
const _monthsFull = ['January','February','March','April','May','June','July','August','September','October','November','December'];
const _weekdays = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];

String _groupLabel(DateTime dt) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final d = DateTime(dt.year, dt.month, dt.day);
  final diff = today.difference(d).inDays;
  if (diff == 0) return 'TODAY';
  if (diff == 1) return 'YESTERDAY';
  if (diff < 7)  return '$diff DAYS AGO';
  return '${d.day} ${_monthsFull[d.month - 1].toUpperCase()} ${d.year}';
}

Map<String, List<NotificationModel>> _group(List<NotificationModel> list) {
  final map = <String, List<NotificationModel>>{};
  for (final n in list) {
    final key = _groupLabel(n.createdAt);
    map.putIfAbsent(key, () => []).add(n);
  }
  return map;
}

String _timeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inSeconds < 60)  return 'just now';
  if (diff.inMinutes < 60)  return '${diff.inMinutes}m ago';
  if (diff.inHours < 24)    return '${diff.inHours}h ago';
  if (diff.inDays < 7)      return '${diff.inDays}d ago';
  return '${dt.day} ${_months[dt.month - 1]}';
}

String _formatFull(DateTime dt) {
  final wd = _weekdays[dt.weekday - 1];
  final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
  final m = dt.minute.toString().padLeft(2, '0');
  final ampm = dt.hour >= 12 ? 'PM' : 'AM';
  return '$wd, ${dt.day} ${_monthsFull[dt.month - 1]} ${dt.year}  ·  $h:$m $ampm';
}

String _formatAmount(double v) {
  if (v >= 1000000) return 'KES ${(v / 1000000).toStringAsFixed(1)}M';
  if (v >= 1000)    return 'KES ${(v / 1000).toStringAsFixed(0)}K';
  return 'KES ${v.toStringAsFixed(0)}';
}

// ─────────────────────────────────────────────────────────────────────────────
// MAIN SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with TickerProviderStateMixin {

  final _state = NotificationsState();
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();

  String _searchQuery   = '';
  String _statusFilter  = 'all';
  Set<NotifType> _typeFilter = {};
  bool _showTypePanel   = false;
  NotificationModel? _selected;

  late final AnimationController _typePanelAc = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 260));
  late final Animation<double> _typePanelH =
      CurvedAnimation(parent: _typePanelAc, curve: Curves.easeInOutCubic);

  late final AnimationController _detailAc = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 320));
  late final Animation<Offset> _detailSlide = Tween<Offset>(
      begin: const Offset(1, 0), end: Offset.zero)
      .animate(CurvedAnimation(parent: _detailAc, curve: Curves.easeOutCubic));

  bool _notifSupported    = false;
  bool _notifSubscribed   = false;
  bool _notifLoading      = true;

  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    _state.addListener(_rebuild);
    _state.fetch();
    _loadPushStatus();
    // Auto-refresh every 60 seconds
    _autoRefreshTimer = Timer.periodic(
        const Duration(seconds: 60), (_) => _state.fetch(silent: true));
  }

  Future<void> _loadPushStatus() async {
    setState(() => _notifLoading = true);
    try {
      final status = await NotificationService.instance.getNotificationStatus();
      if (!mounted) return;
      setState(() {
        _notifSupported  = status.isSupported;
        _notifSubscribed = status.isSubscribed;
      });
    } catch (_) {}
    if (mounted) setState(() => _notifLoading = false);
  }

  Future<void> _togglePush() async {
    if (!_notifSupported) {
      _snack('Push notifications are not supported in this browser');
      return;
    }
    setState(() => _notifLoading = true);
    try {
      if (_notifSubscribed) {
        await NotificationService.instance.unsubscribe();
        _snack('Push notifications disabled');
      } else {
        await NotificationService.instance.requestPermission();
        _snack('Push notifications enabled ✓');
      }
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      await _loadPushStatus();
    }
  }

  void _rebuild() => setState(() {});

  @override
  void dispose() {
    _state.removeListener(_rebuild);
    _autoRefreshTimer?.cancel();
    _typePanelAc.dispose();
    _detailAc.dispose();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  // ── Filtered list ──────────────────────────────────────────────────────────
  List<NotificationModel> get _filtered {
    var list = _state.visible;
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
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

  // ── Actions ────────────────────────────────────────────────────────────────
  void _openDetail(NotificationModel n) {
    HapticFeedback.selectionClick();
    setState(() => _selected = n);
    _state.markRead(n.id);
    _detailAc.forward(from: 0);
  }

  void _closeDetail() {
    _detailAc.reverse().then((_) {
      if (mounted) setState(() => _selected = null);
    });
  }

  void _deleteItem(String id) {
    HapticFeedback.mediumImpact();
    _state.delete(id);
    _snack('Notification deleted');
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: GoogleFonts.dmSans(fontWeight: FontWeight.w600, color: Colors.white)),
      backgroundColor: isError ? _C.red : _C.ink,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      duration: const Duration(seconds: 3),
    ));
  }

  void _confirmDeleteAll() {
    showDialog(
      context: context,
      builder: (_) => _ConfirmDialog(
        title: 'Clear All Notifications',
        message:
            'Delete all ${_filtered.length} notification${_filtered.length == 1 ? '' : 's'}? This cannot be undone.',
        confirmLabel: 'Delete All',
        onConfirm: () {
          _state.deleteAll(_filtered.map((n) => n.id).toList());
          _snack('All notifications cleared');
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: _C.bg,
        body: Stack(
          children: [
            _buildBody(),
            if (_selected != null)
              SlideTransition(
                position: _detailSlide,
                child: _NotificationDetail(
                  notification: _selected!,
                  onClose: _closeDetail,
                  onDelete: (id) {
                    _closeDetail();
                    Future.delayed(const Duration(milliseconds: 340),
                        () => _deleteItem(id));
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() => Column(
    children: [
      _buildHeader(),
      _buildSearchBar(),
      _buildStatusChips(),
      _buildTypePanel(),
      _buildCountRow(),
      Expanded(child: _buildList()),
    ],
  );

  // ── HEADER ─────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    final unread = _state.unreadCount;
    return Container(
      color: _C.surface,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 12),
          child: Row(
            children: [
              _IconBtn(
                icon: Icons.arrow_back_ios_new_rounded,
                onTap: () => Navigator.maybePop(context),
              ),
              const SizedBox(width: 4),
              // Push toggle button
              if (!_notifLoading && _notifSupported)
                _IconBtn(
                  icon: _notifSubscribed
                      ? Icons.notifications_active_rounded
                      : Icons.notifications_none_rounded,
                  color: _notifSubscribed ? _C.greenMid : _C.ink,
                  onTap: _togglePush,
                ),
              const Spacer(),
              // Title + badges
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Notifications',
                      style: GoogleFonts.dmSans(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          color: _C.ink,
                          letterSpacing: -0.5)),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (unread > 0) _Badge(
                        label: '$unread unread',
                        bg: _C.greenLight,
                        fg: _C.greenMid,
                      ),
                      if (unread > 0 && !_notifLoading) const SizedBox(width: 6),
                      if (!_notifLoading) _Badge(
                        label: !_notifSupported
                            ? 'Push unsupported'
                            : (_notifSubscribed ? 'Push on' : 'Push off'),
                        bg: _notifSubscribed ? _C.greenLight : _C.blueLight,
                        fg: _notifSubscribed ? _C.greenMid : _C.blue,
                      ),
                    ],
                  ),
                ],
              ),
              const Spacer(),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _IconBtn(
                    icon: Icons.refresh_rounded,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _state.fetch();
                      _loadPushStatus();
                    },
                  ),
                  if (_filtered.isNotEmpty) _IconBtn(
                    icon: Icons.delete_outline_rounded,
                    color: _C.red,
                    onTap: _confirmDeleteAll,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── SEARCH BAR ─────────────────────────────────────────────────────────────
  Widget _buildSearchBar() => Container(
    color: _C.surface,
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 46,
      decoration: BoxDecoration(
        color: _C.bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _searchFocus.hasFocus ? _C.greenMid : _C.border,
          width: _searchFocus.hasFocus ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
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
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          if (_searchQuery.isNotEmpty)
            GestureDetector(
              onTap: () {
                _searchCtrl.clear();
                setState(() => _searchQuery = '');
                _searchFocus.unfocus();
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Icon(Icons.close_rounded, color: _C.inkSoft, size: 18),
              ),
            ),
        ],
      ),
    ),
  );

  // ── STATUS CHIPS ───────────────────────────────────────────────────────────
  Widget _buildStatusChips() => Container(
    color: _C.surface,
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
    child: Row(
      children: [
        _Chip(label: 'All',      active: _statusFilter == 'all',      onTap: () => setState(() => _statusFilter = 'all')),
        const SizedBox(width: 8),
        _Chip(label: 'Unread',   active: _statusFilter == 'unread',   onTap: () => setState(() => _statusFilter = 'unread')),
        const SizedBox(width: 8),
        _Chip(label: 'Priority', active: _statusFilter == 'priority', onTap: () => setState(() => _statusFilter = 'priority'), accent: _C.amber),
        const Spacer(),
        GestureDetector(
          onTap: () {
            setState(() => _showTypePanel = !_showTypePanel);
            _showTypePanel ? _typePanelAc.forward() : _typePanelAc.reverse();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color:  _typeFilter.isNotEmpty ? _C.greenLight : _C.bg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: _typeFilter.isNotEmpty ? _C.greenMid : _C.border,
                  width: 1.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.tune_rounded, size: 14,
                    color: _typeFilter.isNotEmpty ? _C.greenMid : _C.inkMid),
                const SizedBox(width: 5),
                Text(_typeFilter.isNotEmpty ? 'Types (${_typeFilter.length})' : 'Type',
                    style: GoogleFonts.dmSans(
                        fontSize: 12, fontWeight: FontWeight.w700,
                        color: _typeFilter.isNotEmpty ? _C.greenMid : _C.inkMid)),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  // ── TYPE PANEL (collapsible) ───────────────────────────────────────────────
  Widget _buildTypePanel() => SizeTransition(
    sizeFactor: _typePanelH,
    child: Container(
      color: _C.surface,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1, color: _C.border),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: kNotifTypes.entries
                .where((e) => e.key != NotifType.unknown)
                .map((e) {
              final active = _typeFilter.contains(e.key);
              final cfg = e.value;
              return GestureDetector(
                onTap: () => setState(() =>
                    active ? _typeFilter.remove(e.key) : _typeFilter.add(e.key)),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: active ? cfg.bg : _C.bg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: active ? cfg.fg : _C.border, width: 1.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(cfg.emoji, style: const TextStyle(fontSize: 13)),
                      const SizedBox(width: 5),
                      Text(cfg.label,
                          style: GoogleFonts.dmSans(
                              fontSize: 12, fontWeight: FontWeight.w700,
                              color: active ? cfg.fg : _C.inkMid)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          if (_typeFilter.isNotEmpty) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => setState(() => _typeFilter.clear()),
              child: Text('Clear filters',
                  style: GoogleFonts.dmSans(
                      fontSize: 12, fontWeight: FontWeight.w700, color: _C.red)),
            ),
          ],
        ],
      ),
    ),
  );

  // ── COUNT ROW ──────────────────────────────────────────────────────────────
  Widget _buildCountRow() => Container(
    color: _C.surface,
    child: Column(
      children: [
        const Divider(height: 1, thickness: 1, color: _C.border),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          child: Row(
            children: [
              Text(
                '${_filtered.length} notification${_filtered.length == 1 ? '' : 's'}',
                style: GoogleFonts.dmSans(
                    fontSize: 12, color: _C.inkSoft, fontWeight: FontWeight.w500),
              ),
              if (_state.error != null) ...[
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.wifi_off_rounded, size: 13, color: _C.amber),
                    const SizedBox(width: 4),
                    Text(_state.error!,
                        style: GoogleFonts.dmSans(
                            fontSize: 12, color: _C.amber, fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );

  // ── LIST ───────────────────────────────────────────────────────────────────
  Widget _buildList() {
    if (_state.loading) return _buildSkeletons();
    if (_filtered.isEmpty) return _buildEmpty();

    final groups = _group(_filtered);
    final keys   = groups.keys.toList();

    return RefreshIndicator(
      color: _C.greenMid,
      backgroundColor: _C.surface,
      onRefresh: () => _state.fetch(),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 40),
        itemCount: keys.length,
        itemBuilder: (_, gi) {
          final key   = keys[gi];
          final items = groups[key]!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _GroupHeader(label: key),
              ...List.generate(
                items.length,
                (ii) => _NotifTile(
                  notification: items[ii],
                  stagger: ii + gi * 10,
                  onTap: () => _openDetail(items[ii]),
                  onDelete: () => _deleteItem(items[ii].id),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSkeletons() => ListView.builder(
    itemCount: 5,
    padding: const EdgeInsets.only(top: 12),
    itemBuilder: (_, i) => _SkeletonTile(index: i),
  );

  Widget _buildEmpty() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 88, height: 88,
          decoration: const BoxDecoration(color: _C.greenLight, shape: BoxShape.circle),
          child: const Center(child: Text('🔔', style: TextStyle(fontSize: 40))),
        ),
        const SizedBox(height: 20),
        Text('All caught up!',
            style: GoogleFonts.dmSans(
                fontWeight: FontWeight.w900, fontSize: 22, color: _C.ink)),
        const SizedBox(height: 8),
        Text(
          _searchQuery.isNotEmpty
              ? 'No results for "$_searchQuery"'
              : 'No notifications yet',
          style: GoogleFonts.dmSans(fontSize: 14, color: _C.inkSoft),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// GROUP HEADER
// ─────────────────────────────────────────────────────────────────────────────

class _GroupHeader extends StatelessWidget {
  final String label;
  const _GroupHeader({required this.label});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
    child: Row(
      children: [
        Text(label,
            style: GoogleFonts.dmSans(
                fontSize: 11, fontWeight: FontWeight.w800,
                color: _C.inkSoft, letterSpacing: 0.8)),
        const SizedBox(width: 10),
        const Expanded(child: Divider(color: _C.border, height: 1)),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// NOTIFICATION TILE
// ─────────────────────────────────────────────────────────────────────────────

class _NotifTile extends StatefulWidget {
  final NotificationModel notification;
  final int stagger;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _NotifTile({
    required this.notification,
    required this.stagger,
    required this.onTap,
    required this.onDelete,
  });

  @override State<_NotifTile> createState() => _NotifTileState();
}

class _NotifTileState extends State<_NotifTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 350 + (widget.stagger % 8) * 40));
  late final Animation<double> _fade =
      CurvedAnimation(parent: _ac, curve: Curves.easeOut);
  late final Animation<Offset> _slide = Tween<Offset>(
      begin: const Offset(0, 0.10), end: Offset.zero)
      .animate(CurvedAnimation(parent: _ac, curve: Curves.easeOutCubic));

  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: (widget.stagger % 10) * 35), () {
      if (mounted) _ac.forward();
    });
  }

  @override void dispose() { _ac.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final cfg = kNotifTypes[widget.notification.type]!;
    final n   = widget.notification;

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
            decoration: BoxDecoration(
              color: _C.redLight,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.delete_outline_rounded, color: _C.red, size: 24),
                const SizedBox(height: 3),
                Text('Delete',
                    style: GoogleFonts.dmSans(
                        fontSize: 11, fontWeight: FontWeight.w700, color: _C.red)),
              ],
            ),
          ),
          onDismissed: (_) => widget.onDelete(),
          child: MouseRegion(
            onEnter: (_) => setState(() => _hovered = true),
            onExit:  (_) => setState(() => _hovered = false),
            child: GestureDetector(
              onTap: widget.onTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                decoration: BoxDecoration(
                  color: _C.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: n.read ? _C.border : cfg.fg.withOpacity(0.22),
                    width: n.read ? 1 : 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _hovered
                          ? cfg.fg.withOpacity(0.10)
                          : (n.read ? _C.shadow : cfg.fg.withOpacity(0.06)),
                      blurRadius: _hovered ? 20 : 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Left unread accent bar
                        if (!n.read)
                          Container(width: 3, color: cfg.fg),
                        // Content
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(n.read ? 14 : 11, 14, 14, 14),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Icon circle
                                Container(
                                  width: 48, height: 48,
                                  decoration: BoxDecoration(
                                    color: n.read ? _C.grayLight : cfg.bg,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(cfg.emoji,
                                        style: const TextStyle(fontSize: 22))),
                                ),
                                const SizedBox(width: 12),
                                // Text content
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Text(n.title,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: GoogleFonts.dmSans(
                                                    fontWeight: n.read
                                                        ? FontWeight.w600
                                                        : FontWeight.w800,
                                                    fontSize: 14,
                                                    color: _C.ink)),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(_timeAgo(n.createdAt),
                                              style: GoogleFonts.dmSans(
                                                  fontSize: 11,
                                                  color: _C.inkSoft,
                                                  fontWeight: FontWeight.w500)),
                                        ],
                                      ),
                                      const SizedBox(height: 5),
                                      Text(n.message,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.dmSans(
                                              fontSize: 13,
                                              color: n.read ? _C.inkSoft : _C.inkMid,
                                              height: 1.5)),
                                      const SizedBox(height: 9),
                                      Row(
                                        children: [
                                          _TypeBadge(label: cfg.label, bg: cfg.bg, fg: cfg.fg),
                                          if (n.priority) ...[
                                            const SizedBox(width: 6),
                                            _TypeBadge(
                                                label: 'Priority',
                                                bg: _C.redLight,
                                                fg: _C.red),
                                          ],
                                          const Spacer(),
                                          if (!n.read)
                                            Container(
                                              width: 8, height: 8,
                                              decoration: BoxDecoration(
                                                  color: cfg.fg,
                                                  shape: BoxShape.circle,
                                                  boxShadow: [
                                                    BoxShadow(
                                                        color: cfg.fg.withOpacity(0.35),
                                                        blurRadius: 4,
                                                        spreadRadius: 1)
                                                  ]),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NOTIFICATION DETAIL SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class _NotificationDetail extends StatefulWidget {
  final NotificationModel notification;
  final VoidCallback onClose;
  final void Function(String) onDelete;

  const _NotificationDetail({
    required this.notification,
    required this.onClose,
    required this.onDelete,
  });

  @override State<_NotificationDetail> createState() => _NotificationDetailState();
}

class _NotificationDetailState extends State<_NotificationDetail>
    with SingleTickerProviderStateMixin {
  late final AnimationController _contentAc = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 420));
  late final Animation<double> _contentFade =
      CurvedAnimation(parent: _contentAc, curve: Curves.easeOut);
  late final Animation<Offset> _contentSlide = Tween<Offset>(
      begin: const Offset(0, 0.06), end: Offset.zero)
      .animate(CurvedAnimation(parent: _contentAc, curve: Curves.easeOutCubic));

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _contentAc.forward();
    });
  }

  @override void dispose() { _contentAc.dispose(); super.dispose(); }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (_) => _ConfirmDialog(
        title: 'Delete Notification',
        message: 'Are you sure you want to delete this notification?',
        confirmLabel: 'Delete',
        onConfirm: () => widget.onDelete(widget.notification.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final n   = widget.notification;
    final cfg = kNotifTypes[n.type]!;

    return Material(
      color: _C.bg,
      child: Column(
        children: [
          // Header
          Container(
            color: _C.surface,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 12),
                child: Row(
                  children: [
                    _IconBtn(
                        icon: Icons.arrow_back_ios_new_rounded,
                        onTap: widget.onClose),
                    Expanded(
                      child: Text('Notification',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.dmSans(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              color: _C.ink,
                              letterSpacing: -0.5)),
                    ),
                    _IconBtn(
                        icon: Icons.delete_outline_rounded,
                        color: _C.red,
                        onTap: _confirmDelete),
                  ],
                ),
              ),
            ),
          ),
          const Divider(height: 1, thickness: 1, color: _C.border),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: FadeTransition(
                opacity: _contentFade,
                child: SlideTransition(
                  position: _contentSlide,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Icon + meta row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 72, height: 72,
                            decoration: BoxDecoration(
                              color: cfg.bg,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                    color: cfg.fg.withOpacity(0.18),
                                    blurRadius: 20,
                                    offset: const Offset(0, 6))
                              ],
                            ),
                            child: Center(
                                child: Text(cfg.emoji,
                                    style: const TextStyle(fontSize: 34))),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6, runSpacing: 6,
                                  children: [
                                    _TypeBadge(label: cfg.label, bg: cfg.bg, fg: cfg.fg, large: true),
                                    if (n.priority)
                                      _TypeBadge(label: 'Priority', bg: _C.redLight, fg: _C.red, large: true),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(_formatFull(n.createdAt),
                                    style: GoogleFonts.dmSans(
                                        fontSize: 12,
                                        color: _C.inkSoft,
                                        fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Title
                      Text(n.title,
                          style: GoogleFonts.dmSans(
                              fontWeight: FontWeight.w900,
                              fontSize: 22,
                              color: _C.ink,
                              height: 1.25,
                              letterSpacing: -0.5)),
                      const SizedBox(height: 16),

                      // Message body
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: cfg.bg.withOpacity(0.55),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: cfg.fg.withOpacity(0.12)),
                        ),
                        child: Text(n.message,
                            style: GoogleFonts.dmSans(
                                fontSize: 15, color: _C.inkMid, height: 1.7)),
                      ),

                      // Metadata card
                      if (n.amount != null || n.campaignId != null) ...[
                        const SizedBox(height: 20),
                        Container(
                          decoration: BoxDecoration(
                            color: _C.surface,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: _C.border),
                          ),
                          child: Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
                                child: Row(
                                  children: [
                                    Text('Details',
                                        style: GoogleFonts.dmSans(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 14,
                                            color: _C.ink)),
                                  ],
                                ),
                              ),
                              const Divider(height: 1, color: _C.border),
                              if (n.amount != null)
                                _MetaRow(
                                    label: 'Amount',
                                    value: _formatAmount(n.amount!),
                                    valueColor: _C.greenMid),
                              if (n.campaignId != null)
                                _MetaRow(
                                    label: 'Campaign ID',
                                    value: n.campaignId!),
                              _MetaRow(
                                  label: 'Status',
                                  value: n.read ? 'Read' : 'Unread',
                                  valueColor: n.read ? _C.inkSoft : cfg.fg,
                                  isLast: true),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 28),

                      // Delete button
                      GestureDetector(
                        onTap: _confirmDelete,
                        child: Container(
                          height: 54,
                          decoration: BoxDecoration(
                            color: _C.redLight,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: _C.red.withOpacity(0.22)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.delete_outline_rounded,
                                  color: _C.red, size: 20),
                              const SizedBox(width: 8),
                              Text('Delete Notification',
                                  style: GoogleFonts.dmSans(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: _C.red)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// META ROW
// ─────────────────────────────────────────────────────────────────────────────

class _MetaRow extends StatelessWidget {
  final String label, value;
  final Color? valueColor;
  final bool isLast;

  const _MetaRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: Row(
          children: [
            Text(label,
                style: GoogleFonts.dmSans(
                    fontSize: 13, color: _C.inkSoft, fontWeight: FontWeight.w500)),
            const Spacer(),
            Text(value,
                style: GoogleFonts.dmSans(
                    fontSize: 13,
                    color: valueColor ?? _C.ink,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
      if (!isLast) const Divider(height: 1, color: _C.border, indent: 18, endIndent: 18),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// SKELETON TILE
// ─────────────────────────────────────────────────────────────────────────────

class _SkeletonTile extends StatefulWidget {
  final int index;
  const _SkeletonTile({required this.index});
  @override State<_SkeletonTile> createState() => _SkeletonTileState();
}

class _SkeletonTileState extends State<_SkeletonTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100))
    ..repeat(reverse: true);

  @override void dispose() { _ac.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _ac,
    builder: (_, __) {
      final opacity = 0.04 + _ac.value * 0.06;
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _C.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _C.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Skel(w: 48, h: 48, r: 24, opacity: opacity),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Skel(w: double.infinity, h: 13, r: 6, opacity: opacity),
                  const SizedBox(height: 8),
                  _Skel(w: MediaQuery.of(context).size.width * 0.55, h: 11, r: 6, opacity: opacity * 0.75),
                  const SizedBox(height: 6),
                  _Skel(w: MediaQuery.of(context).size.width * 0.35, h: 11, r: 6, opacity: opacity * 0.5),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _Skel extends StatelessWidget {
  final double w, h, r, opacity;
  const _Skel({required this.w, required this.h, required this.r, required this.opacity});
  @override
  Widget build(BuildContext context) => Container(
    width: w, height: h,
    decoration: BoxDecoration(
      color: Colors.black.withOpacity(opacity),
      borderRadius: BorderRadius.circular(r),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED SMALL WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _IconBtn extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  const _IconBtn({required this.icon, required this.onTap, this.color});

  @override State<_IconBtn> createState() => _IconBtnState();
}

class _IconBtnState extends State<_IconBtn> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: widget.onTap,
    onTapDown: (_) => setState(() => _pressed = true),
    onTapUp:   (_) => setState(() => _pressed = false),
    onTapCancel: () => setState(() => _pressed = false),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: 42, height: 42,
      decoration: BoxDecoration(
        color: _pressed
            ? (widget.color?.withOpacity(0.14) ?? _C.border)
            : (widget.color?.withOpacity(0.08) ?? Colors.transparent),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: widget.color?.withOpacity(0.16) ?? _C.border,
            width: 1),
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

  const _Chip({
    required this.label,
    required this.active,
    required this.onTap,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final a = accent ?? _C.greenMid;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? a : _C.bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? a : _C.border, width: 1.5),
        ),
        child: Text(label,
            style: GoogleFonts.dmSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: active ? Colors.white : _C.inkMid)),
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final String label;
  final Color bg, fg;
  final bool large;

  const _TypeBadge({
    required this.label,
    required this.bg,
    required this.fg,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(
        horizontal: large ? 12 : 8, vertical: large ? 4 : 3),
    decoration: BoxDecoration(
        color: bg, borderRadius: BorderRadius.circular(20)),
    child: Text(label,
        style: GoogleFonts.dmSans(
            fontSize: large ? 12 : 11,
            fontWeight: FontWeight.w700,
            color: fg)),
  );
}

class _Badge extends StatelessWidget {
  final String label;
  final Color bg, fg;
  const _Badge({required this.label, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
    child: Text(label,
        style: GoogleFonts.dmSans(
            fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// CONFIRM DIALOG
// ─────────────────────────────────────────────────────────────────────────────

class _ConfirmDialog extends StatelessWidget {
  final String title, message, confirmLabel;
  final VoidCallback onConfirm;

  const _ConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) => AlertDialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    title: Text(title,
        style: GoogleFonts.dmSans(
            fontWeight: FontWeight.w900, fontSize: 19, color: _C.ink)),
    content: Text(message,
        style: GoogleFonts.dmSans(
            color: _C.inkMid, height: 1.55, fontSize: 14)),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text('Cancel',
            style: GoogleFonts.dmSans(
                color: _C.inkMid, fontWeight: FontWeight.w600)),
      ),
      ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: _C.red,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        onPressed: () {
          Navigator.pop(context);
          onConfirm();
        },
        child: Text(confirmLabel,
            style: GoogleFonts.dmSans(
                color: Colors.white, fontWeight: FontWeight.w700)),
      ),
    ],
  );
}