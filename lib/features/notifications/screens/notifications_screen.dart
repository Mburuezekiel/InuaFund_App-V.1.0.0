// ═══════════════════════════════════════════════════════════════════════════════
// notifications_screen.dart
// Premium Notifications UI — InuaFund
// Full-featured: list, detail, filter, search, offline cache, animations
// ═══════════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

// ─────────────────────────────────────────────────────────────────────────────
// THEME TOKENS
// ─────────────────────────────────────────────────────────────────────────────

class _C {
  static const bg         = Color(0xFFF7F8FA);
  static const surface    = Color(0xFFFFFFFF);
  static const border     = Color(0xFFECEEF2);
  static const ink        = Color(0xFF0F1923);
  static const inkMid     = Color(0xFF4B5563);
  static const inkSoft    = Color(0xFF9CA3AF);
  static const green      = Color(0xFF0B5E35);
  static const greenMid   = Color(0xFF1A8C52);
  static const greenLight = Color(0xFFDCF5E8);
  static const red        = Color(0xFFD93025);
  static const redLight   = Color(0xFFFFEBE9);
  static const amber      = Color(0xFFE8860A);
  static const amberLight = Color(0xFFFFF3DC);
  static const blue       = Color(0xFF1565C0);
  static const blueLight  = Color(0xFFE3EDFF);
  static const purple     = Color(0xFF6D28D9);
  static const purpleLight= Color(0xFFF0EBFF);
  static const pink       = Color(0xFFBE185D);
  static const pinkLight  = Color(0xFFFFE4F0);
  static const orange     = Color(0xFFEA580C);
  static const orangeLight= Color(0xFFFFEEE5);
  static const teal       = Color(0xFF0D9488);
  static const tealLight  = Color(0xFFE0F7F5);
  static const shadow     = Color(0x0A000000);
  static const shadowMed  = Color(0x14000000);
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
}

class NotifTypeConfig {
  final String emoji;
  final Color bg;
  final Color fg;
  final String label;
  const NotifTypeConfig({
    required this.emoji,
    required this.bg,
    required this.fg,
    required this.label,
  });
}

const Map<NotifType, NotifTypeConfig> kNotifTypes = {
  NotifType.system: NotifTypeConfig(
    emoji: '🔔', bg: _C.blueLight, fg: _C.blue, label: 'System'),
  NotifType.campaignUpdate: NotifTypeConfig(
    emoji: '✅', bg: _C.greenLight, fg: _C.greenMid, label: 'Campaign'),
  NotifType.campaignEnded: NotifTypeConfig(
    emoji: '⏹️', bg: Color(0xFFF3F4F6), fg: Color(0xFF6B7280), label: 'Ended'),
  NotifType.makeWithdrawal: NotifTypeConfig(
    emoji: '💳', bg: _C.amberLight, fg: _C.amber, label: 'Withdrawal'),
  NotifType.withdrawalSuccess: NotifTypeConfig(
    emoji: '💰', bg: _C.greenLight, fg: _C.green, label: 'Paid Out'),
  NotifType.newDonation: NotifTypeConfig(
    emoji: '❤️', bg: _C.pinkLight, fg: _C.pink, label: 'Donation'),
  NotifType.donationReceived: NotifTypeConfig(
    emoji: '🎁', bg: _C.orangeLight, fg: _C.orange, label: 'Received'),
  NotifType.goalReached: NotifTypeConfig(
    emoji: '🏆', bg: _C.amberLight, fg: _C.amber, label: 'Goal!'),
  NotifType.message: NotifTypeConfig(
    emoji: '💬', bg: _C.purpleLight, fg: _C.purple, label: 'Message'),
  NotifType.admin: NotifTypeConfig(
    emoji: '⚠️', bg: _C.redLight, fg: _C.red, label: 'Admin'),
  NotifType.welcome: NotifTypeConfig(
    emoji: '🌟', bg: _C.tealLight, fg: _C.teal, label: 'Welcome'),
};

// ─────────────────────────────────────────────────────────────────────────────
// MODEL
// ─────────────────────────────────────────────────────────────────────────────

class NotificationModel {
  final String id;
  final String title;
  final String message;
  final NotifType type;
  final DateTime createdAt;
  final bool read;
  final bool priority;
  final double? amount;
  final String? campaignId;
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

  NotificationModel copyWith({bool? read, bool? deleted}) => NotificationModel(
    id: id, title: title, message: message, type: type,
    createdAt: createdAt, priority: priority,
    amount: amount, campaignId: campaignId,
    read: read ?? this.read,
    deleted: deleted ?? this.deleted,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// DUMMY DATA
// ─────────────────────────────────────────────────────────────────────────────

List<NotificationModel> _buildDummyData() {
  final now = DateTime.now();
  return [
    NotificationModel(
      id: '1', type: NotifType.newDonation,
      title: 'New Donation Received',
      message: 'James Mwangi donated KES 2,500 to your campaign "Help Mama Wanjiku with Cancer Treatment". Your campaign is now 52% funded!',
      createdAt: now.subtract(const Duration(minutes: 5)),
      priority: true, amount: 2500, campaignId: 'camp_001',
    ),
    NotificationModel(
      id: '2', type: NotifType.goalReached,
      title: '🎉 Goal Reached! Congratulations',
      message: 'Your campaign "Kibera School Desks & Books Drive" has reached its funding goal of KES 120,000. Thank you to all 156 donors who made this possible!',
      createdAt: now.subtract(const Duration(hours: 2)),
      priority: true, amount: 120000, campaignId: 'camp_002',
    ),
    NotificationModel(
      id: '3', type: NotifType.withdrawalSuccess,
      title: 'Withdrawal Successful',
      message: 'Your withdrawal of KES 45,000 has been processed successfully and will reflect in your M-PESA account ending **72 within 24 hours.',
      createdAt: now.subtract(const Duration(hours: 5)),
      amount: 45000,
    ),
    NotificationModel(
      id: '4', type: NotifType.message,
      title: 'New message from Faith Otieno',
      message: 'Hi, I just donated to your campaign. I am so touched by the story. Please keep us updated on Mama Wanjiku\'s progress. Sending prayers your way 🙏',
      createdAt: now.subtract(const Duration(hours: 8)),
      read: true,
    ),
    NotificationModel(
      id: '5', type: NotifType.campaignUpdate,
      title: 'Campaign Milestone Reached',
      message: 'Your campaign "Borehole for Turkana Community" has reached 50% of its funding goal. 201 donors have contributed KES 230,000 so far. Keep sharing!',
      createdAt: now.subtract(const Duration(days: 1, hours: 2)),
      campaignId: 'camp_003',
    ),
    NotificationModel(
      id: '6', type: NotifType.admin,
      title: 'Action Required: Verify Your Identity',
      message: 'To continue withdrawing funds above KES 50,000, you need to complete identity verification. Please submit a copy of your National ID or Passport.',
      createdAt: now.subtract(const Duration(days: 1, hours: 6)),
      priority: true,
    ),
    NotificationModel(
      id: '7', type: NotifType.newDonation,
      title: 'Anonymous Donation Received',
      message: 'An anonymous donor contributed KES 10,000 to "Flood Relief — Tana River Families". Your campaign is now 82% funded with only 7 days remaining!',
      createdAt: now.subtract(const Duration(days: 1, hours: 10)),
      read: true, amount: 10000, campaignId: 'camp_004',
    ),
    NotificationModel(
      id: '8', type: NotifType.system,
      title: 'Scheduled Maintenance',
      message: 'InuaFund will undergo scheduled maintenance on Saturday, April 26th from 2:00 AM to 4:00 AM EAT. Donations and withdrawals will be temporarily unavailable.',
      createdAt: now.subtract(const Duration(days: 2)),
      read: true,
    ),
    NotificationModel(
      id: '9', type: NotifType.campaignEnded,
      title: 'Campaign Ended',
      message: 'Your campaign "Bursary for 12 Students — Kisumu" has ended. Total raised: KES 88,000 out of KES 150,000 goal. Funds have been disbursed to campaign owner.',
      createdAt: now.subtract(const Duration(days: 2, hours: 4)),
      read: true, amount: 88000, campaignId: 'camp_005',
    ),
    NotificationModel(
      id: '10', type: NotifType.welcome,
      title: 'Welcome to InuaFund! 🌿',
      message: 'Karibu! You\'ve successfully joined Kenya\'s leading community fundraising platform. Start by exploring active campaigns or create your own to raise funds for what matters most.',
      createdAt: now.subtract(const Duration(days: 5)),
      read: true,
    ),
  ];
}

// ─────────────────────────────────────────────────────────────────────────────
// SIMPLE IN-MEMORY STATE (swap for Riverpod/Bloc in production)
// ─────────────────────────────────────────────────────────────────────────────

class NotificationsState extends ChangeNotifier {
  List<NotificationModel> _all = [];
  bool _loading = true;

  List<NotificationModel> get all => _all.where((n) => !n.deleted).toList();
  bool get loading => _loading;

  Future<void> fetch() async {
    _loading = true;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 900)); // simulate network
    _all = _buildDummyData();
    _loading = false;
    notifyListeners();
  }

  void markRead(String id) {
    final idx = _all.indexWhere((n) => n.id == id);
    if (idx >= 0) { _all[idx] = _all[idx].copyWith(read: true); notifyListeners(); }
  }

  void delete(String id) {
    final idx = _all.indexWhere((n) => n.id == id);
    if (idx >= 0) { _all[idx] = _all[idx].copyWith(deleted: true); notifyListeners(); }
  }

  void deleteAll(List<String> ids) {
    for (final id in ids) {
      final idx = _all.indexWhere((n) => n.id == id);
      if (idx >= 0) _all[idx] = _all[idx].copyWith(deleted: true);
    }
    notifyListeners();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DATE GROUP HELPERS
// ─────────────────────────────────────────────────────────────────────────────

String _groupLabel(DateTime dt) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final d = DateTime(dt.year, dt.month, dt.day);
  final diff = today.difference(d).inDays;
  if (diff == 0) return 'TODAY';
  if (diff == 1) return 'YESTERDAY';
  if (diff < 7)  return '${diff} DAYS AGO';
  return '${d.day} ${_months[d.month - 1]} ${d.year}'.toUpperCase();
}

const _months = ['JAN','FEB','MAR','APR','MAY','JUN','JUL','AUG','SEP','OCT','NOV','DEC'];

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
  if (diff.inMinutes < 1)  return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24)   return '${diff.inHours}h ago';
  if (diff.inDays < 7)     return '${diff.inDays}d ago';
  return '${dt.day} ${_months[dt.month - 1]}';
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

  String _searchQuery = '';
  String _statusFilter = 'all';      // all | unread | priority
  Set<NotifType> _typeFilter = {};
  bool _showFilters = false;
  NotificationModel? _selected;

  late final AnimationController _filterAnim = AnimationController(
    vsync: this, duration: const Duration(milliseconds: 280));
  late final Animation<double> _filterHeight =
    CurvedAnimation(parent: _filterAnim, curve: Curves.easeInOutCubic);

  late final AnimationController _detailAnim = AnimationController(
    vsync: this, duration: const Duration(milliseconds: 320));
  late final Animation<Offset> _detailSlide = Tween<Offset>(
    begin: const Offset(1, 0), end: Offset.zero)
    .animate(CurvedAnimation(parent: _detailAnim, curve: Curves.easeOutCubic));

  @override
  void initState() {
    super.initState();
    _state.fetch();
    _state.addListener(_rebuild);
  }

  void _rebuild() => setState(() {});

  @override
  void dispose() {
    _state.removeListener(_rebuild);
    _filterAnim.dispose();
    _detailAnim.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Filtered list ──────────────────────────────────────────────────────────
  List<NotificationModel> get _filtered {
    var list = _state.all;
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((n) =>
        n.title.toLowerCase().contains(q) ||
        n.message.toLowerCase().contains(q)).toList();
    }
    if (_typeFilter.isNotEmpty) {
      list = list.where((n) => _typeFilter.contains(n.type)).toList();
    }
    if (_statusFilter == 'unread') list = list.where((n) => !n.read).toList();
    if (_statusFilter == 'priority') list = list.where((n) => n.priority).toList();
    return list;
  }

  void _openDetail(NotificationModel n) {
    HapticFeedback.selectionClick();
    setState(() => _selected = n);
    _state.markRead(n.id);
    _detailAnim.forward(from: 0);
  }

  void _closeDetail() {
    _detailAnim.reverse().then((_) => setState(() => _selected = null));
  }

  void _delete(String id) {
    HapticFeedback.mediumImpact();
    _state.delete(id);
    _showSnack('Notification deleted');
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.dmSans(fontWeight: FontWeight.w600, color: Colors.white)),
      backgroundColor: _C.ink,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 2),
    ));
  }

  // ── Delete all confirm ─────────────────────────────────────────────────────
  void _confirmDeleteAll() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Clear All', style: GoogleFonts.dmSans(fontWeight: FontWeight.w800, fontSize: 20)),
        content: Text('Delete all ${_filtered.length} notifications? This cannot be undone.',
          style: GoogleFonts.dmSans(color: _C.inkMid, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.dmSans(color: _C.inkMid, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _C.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () {
              Navigator.pop(context);
              _state.deleteAll(_filtered.map((n) => n.id).toList());
              _showSnack('All notifications cleared');
            },
            child: Text('Delete All', style: GoogleFonts.dmSans(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
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
            // Main list view
            _buildListView(),
            // Detail overlay (slides in from right)
            if (_selected != null)
              SlideTransition(
                position: _detailSlide,
                child: _NotificationDetail(
                  notification: _selected!,
                  onClose: _closeDetail,
                  onDelete: (id) { _closeDetail(); Future.delayed(const Duration(milliseconds: 340), () => _delete(id)); },
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildListView() => Column(
    children: [
      _buildHeader(),
      _buildSearchBar(),
      _buildFilterBar(),
      _buildStatusRow(),
      Expanded(child: _buildList()),
    ],
  );

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    final unread = _state.all.where((n) => !n.read).length;
    return Container(
      color: _C.surface,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
          child: Row(
            children: [
              _IconBtn(icon: Icons.arrow_back_ios_new_rounded, onTap: () => Navigator.maybePop(context)),
              const Spacer(),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Notifications',
                    style: GoogleFonts.dmSans(fontWeight: FontWeight.w800, fontSize: 18, color: _C.ink, letterSpacing: -0.4)),
                  if (unread > 0)
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: _C.greenLight, borderRadius: BorderRadius.circular(20)),
                      child: Text('$unread unread',
                        style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w700, color: _C.greenMid)),
                    ),
                ],
              ),
              const Spacer(),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _IconBtn(
                    icon: Icons.refresh_rounded,
                    onTap: () { HapticFeedback.lightImpact(); _state.fetch(); },
                  ),
                  if (_filtered.isNotEmpty)
                    _IconBtn(icon: Icons.delete_outline_rounded, onTap: _confirmDeleteAll, color: _C.red),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Search bar ────────────────────────────────────────────────────────────
  Widget _buildSearchBar() => Container(
    color: _C.surface,
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
    child: Container(
      height: 46,
      decoration: BoxDecoration(
        color: _C.bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.border),
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          const Icon(Icons.search_rounded, color: _C.inkSoft, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchCtrl,
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
              onTap: () { _searchCtrl.clear(); setState(() => _searchQuery = ''); },
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Icon(Icons.close_rounded, color: _C.inkSoft, size: 18),
              ),
            ),
        ],
      ),
    ),
  );

  // ── Filter bar ────────────────────────────────────────────────────────────
  Widget _buildFilterBar() => Column(
    children: [
      // Toggle button row
      Container(
        color: _C.surface,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Row(
          children: [
            _FilterChip(label: 'All',      active: _statusFilter == 'all',      onTap: () => setState(() => _statusFilter = 'all')),
            const SizedBox(width: 8),
            _FilterChip(label: 'Unread',   active: _statusFilter == 'unread',   onTap: () => setState(() => _statusFilter = 'unread')),
            const SizedBox(width: 8),
            _FilterChip(label: 'Priority', active: _statusFilter == 'priority', onTap: () => setState(() => _statusFilter = 'priority'), accent: _C.amber),
            const Spacer(),
            GestureDetector(
              onTap: () {
                setState(() => _showFilters = !_showFilters);
                _showFilters ? _filterAnim.forward() : _filterAnim.reverse();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _typeFilter.isNotEmpty ? _C.greenLight : _C.bg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _typeFilter.isNotEmpty ? _C.greenMid : _C.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.tune_rounded, size: 14,
                      color: _typeFilter.isNotEmpty ? _C.greenMid : _C.inkMid),
                    const SizedBox(width: 5),
                    Text(_typeFilter.isNotEmpty ? 'Filtered (${_typeFilter.length})' : 'Type',
                      style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w700,
                        color: _typeFilter.isNotEmpty ? _C.greenMid : _C.inkMid)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      // Collapsible type filters
      SizeTransition(
        sizeFactor: _filterHeight,
        child: Container(
          color: _C.surface,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Divider(height: 1),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: kNotifTypes.entries.map((e) {
                  final active = _typeFilter.contains(e.key);
                  final cfg = e.value;
                  return GestureDetector(
                    onTap: () => setState(() {
                      active ? _typeFilter.remove(e.key) : _typeFilter.add(e.key);
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: active ? cfg.bg : _C.bg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: active ? cfg.fg : _C.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(cfg.emoji, style: const TextStyle(fontSize: 12)),
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
                    style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w700, color: _C.red)),
                ),
              ],
            ],
          ),
        ),
      ),
    ],
  );

  // ── Status row ────────────────────────────────────────────────────────────
  Widget _buildStatusRow() => Container(
    color: _C.surface,
    child: Column(
      children: [
        const Divider(height: 1, thickness: 1, color: _C.border),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Text('${_filtered.length} notification${_filtered.length == 1 ? '' : 's'}',
                style: GoogleFonts.dmSans(fontSize: 13, color: _C.inkSoft, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    ),
  );

  // ── Notification list ─────────────────────────────────────────────────────
  Widget _buildList() {
    if (_state.loading) return _buildSkeletons();
    if (_filtered.isEmpty) return _buildEmpty();

    final groups = _group(_filtered);
    final keys = groups.keys.toList();

    return RefreshIndicator(
      color: _C.greenMid,
      backgroundColor: _C.surface,
      onRefresh: _state.fetch,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 32),
        itemCount: keys.length,
        itemBuilder: (_, gi) {
          final groupKey = keys[gi];
          final items = groups[groupKey]!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _GroupHeader(label: groupKey),
              ...List.generate(items.length, (ii) => _NotifItemTile(
                notification: items[ii],
                index: ii + gi * 10,
                onTap: () => _openDetail(items[ii]),
                onDelete: () => _delete(items[ii].id),
              )),
            ],
          );
        },
      ),
    );
  }

  // ── Skeleton loaders ──────────────────────────────────────────────────────
  Widget _buildSkeletons() => ListView.builder(
    itemCount: 5,
    padding: const EdgeInsets.only(top: 8),
    itemBuilder: (_, i) => _SkeletonTile(index: i),
  );

  // ── Empty state ───────────────────────────────────────────────────────────
  Widget _buildEmpty() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 90, height: 90,
          decoration: BoxDecoration(color: _C.greenLight, shape: BoxShape.circle),
          child: const Center(child: Text('🔔', style: TextStyle(fontSize: 40))),
        ),
        const SizedBox(height: 20),
        Text('All caught up!',
          style: GoogleFonts.dmSans(fontWeight: FontWeight.w800, fontSize: 20, color: _C.ink)),
        const SizedBox(height: 8),
        Text(_searchQuery.isNotEmpty ? 'No results for "$_searchQuery"' : 'No notifications yet',
          style: GoogleFonts.dmSans(fontSize: 14, color: _C.inkSoft)),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// GROUP HEADER WIDGET
// ─────────────────────────────────────────────────────────────────────────────

class _GroupHeader extends StatelessWidget {
  final String label;
  const _GroupHeader({required this.label});

  @override
  Widget build(BuildContext context) => Container(
    color: _C.bg,
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
    child: Row(
      children: [
        Text(label,
          style: GoogleFonts.dmSans(
            fontSize: 11, fontWeight: FontWeight.w800,
            color: _C.inkSoft, letterSpacing: 1.0)),
        const SizedBox(width: 10),
        Expanded(child: Container(height: 1, color: _C.border)),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// NOTIFICATION ITEM TILE
// ─────────────────────────────────────────────────────────────────────────────

class _NotifItemTile extends StatefulWidget {
  final NotificationModel notification;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  const _NotifItemTile({
    required this.notification,
    required this.index,
    required this.onTap,
    required this.onDelete,
  });
  @override State<_NotifItemTile> createState() => _NotifItemTileState();
}

class _NotifItemTileState extends State<_NotifItemTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac = AnimationController(
    vsync: this, duration: Duration(milliseconds: 350 + widget.index * 50));
  late final Animation<double> _fade = CurvedAnimation(parent: _ac, curve: Curves.easeOut);
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 0.12), end: Offset.zero)
    .animate(CurvedAnimation(parent: _ac, curve: Curves.easeOutCubic));

  @override void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: widget.index * 40), () {
      if (mounted) _ac.forward();
    });
  }
  @override void dispose() { _ac.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final cfg = kNotifTypes[widget.notification.type]!;
    final n = widget.notification;

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
            color: _C.redLight,
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.delete_outline_rounded, color: _C.red, size: 24),
                SizedBox(height: 4),
                Text('Delete', style: TextStyle(color: _C.red, fontSize: 11, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          onDismissed: (_) => widget.onDelete(),
          child: GestureDetector(
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              decoration: BoxDecoration(
                color: n.read ? _C.surface : _C.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: n.read ? _C.border : cfg.fg.withOpacity(0.20),
                  width: n.read ? 1 : 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: n.read ? _C.shadow : cfg.fg.withOpacity(0.06),
                    blurRadius: 12, offset: const Offset(0, 3)),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon circle
                    Container(
                      width: 46, height: 46,
                      decoration: BoxDecoration(
                        color: n.read ? const Color(0xFFF3F4F6) : cfg.bg,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(cfg.emoji, style: const TextStyle(fontSize: 20))),
                    ),
                    const SizedBox(width: 12),
                    // Content
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
                                    fontWeight: n.read ? FontWeight.w600 : FontWeight.w800,
                                    fontSize: 14, color: _C.ink)),
                              ),
                              const SizedBox(width: 6),
                              Text(_timeAgo(n.createdAt),
                                style: GoogleFonts.dmSans(
                                  fontSize: 11, color: _C.inkSoft,
                                  fontWeight: FontWeight.w500)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(n.message,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.dmSans(
                              fontSize: 13, color: n.read ? _C.inkSoft : _C.inkMid,
                              height: 1.45)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: cfg.bg,
                                  borderRadius: BorderRadius.circular(20)),
                                child: Text(cfg.label,
                                  style: GoogleFonts.dmSans(
                                    fontSize: 11, fontWeight: FontWeight.w700, color: cfg.fg)),
                              ),
                              if (n.priority) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: _C.redLight,
                                    borderRadius: BorderRadius.circular(20)),
                                  child: Text('Priority',
                                    style: GoogleFonts.dmSans(
                                      fontSize: 11, fontWeight: FontWeight.w700, color: _C.red)),
                                ),
                              ],
                              const Spacer(),
                              // Unread dot
                              if (!n.read)
                                Container(
                                  width: 8, height: 8,
                                  decoration: BoxDecoration(
                                    color: cfg.fg, shape: BoxShape.circle)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
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
    vsync: this, duration: const Duration(milliseconds: 400));

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 120), () {
      if (mounted) _contentAc.forward();
    });
  }
  @override void dispose() { _contentAc.dispose(); super.dispose(); }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Notification',
          style: GoogleFonts.dmSans(fontWeight: FontWeight.w800, fontSize: 18)),
        content: Text('Are you sure you want to delete this notification?',
          style: GoogleFonts.dmSans(color: _C.inkMid, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.dmSans(color: _C.inkMid, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _C.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () {
              Navigator.pop(context);
              widget.onDelete(widget.notification.id);
            },
            child: Text('Delete', style: GoogleFonts.dmSans(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.notification;
    final cfg = kNotifTypes[n.type]!;
    final formattedDate = _formatFull(n.createdAt);

    return Material(
      color: _C.surface,
      child: Column(
        children: [
          // Header
          SafeArea(
            bottom: false,
            child: Container(
              color: _C.surface,
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
              child: Row(
                children: [
                  _IconBtn(icon: Icons.arrow_back_ios_new_rounded, onTap: widget.onClose),
                  Expanded(
                    child: Text('Notification',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.dmSans(
                        fontWeight: FontWeight.w800, fontSize: 18, color: _C.ink, letterSpacing: -0.4)),
                  ),
                  _IconBtn(icon: Icons.delete_outline_rounded, onTap: _confirmDelete, color: _C.red),
                ],
              ),
            ),
          ),
          const Divider(height: 1, thickness: 1, color: _C.border),
          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: AnimatedBuilder(
                animation: _contentAc,
                builder: (_, __) {
                  final v = CurvedAnimation(parent: _contentAc, curve: Curves.easeOutCubic).value;
                  return Opacity(
                    opacity: v,
                    child: Transform.translate(
                      offset: Offset(0, 20 * (1 - v)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Icon + type badge
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 68, height: 68,
                                decoration: BoxDecoration(color: cfg.bg, shape: BoxShape.circle,
                                  boxShadow: [BoxShadow(color: cfg.fg.withOpacity(0.15), blurRadius: 16, offset: const Offset(0, 6))]),
                                child: Center(child: Text(cfg.emoji, style: const TextStyle(fontSize: 32))),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: cfg.bg, borderRadius: BorderRadius.circular(20)),
                                          child: Text(cfg.label,
                                            style: GoogleFonts.dmSans(
                                              fontSize: 12, fontWeight: FontWeight.w800, color: cfg.fg)),
                                        ),
                                        if (n.priority) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: _C.redLight, borderRadius: BorderRadius.circular(20)),
                                            child: Text('Priority',
                                              style: GoogleFonts.dmSans(
                                                fontSize: 12, fontWeight: FontWeight.w800, color: _C.red)),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(formattedDate,
                                      style: GoogleFonts.dmSans(fontSize: 12, color: _C.inkSoft, fontWeight: FontWeight.w500)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          // Title
                          Text(n.title,
                            style: GoogleFonts.dmSans(
                              fontWeight: FontWeight.w900, fontSize: 22, color: _C.ink,
                              height: 1.25, letterSpacing: -0.4)),
                          const SizedBox(height: 16),
                          // Message
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: cfg.bg.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: cfg.fg.withOpacity(0.10)),
                            ),
                            child: Text(n.message,
                              style: GoogleFonts.dmSans(
                                fontSize: 15, color: _C.inkMid, height: 1.65)),
                          ),
                          // Metadata
                          if (n.amount != null || n.campaignId != null) ...[
                            const SizedBox(height: 20),
                            const Divider(color: _C.border),
                            const SizedBox(height: 16),
                            Text('Details',
                              style: GoogleFonts.dmSans(
                                fontWeight: FontWeight.w800, fontSize: 15, color: _C.ink)),
                            const SizedBox(height: 12),
                            if (n.amount != null) _MetaRow(
                              label: 'Amount',
                              value: 'KES ${_formatAmount(n.amount!)}',
                              valueColor: _C.greenMid,
                            ),
                            if (n.campaignId != null) _MetaRow(
                              label: 'Campaign ID',
                              value: n.campaignId!,
                            ),
                            _MetaRow(
                              label: 'Status',
                              value: n.read ? 'Read' : 'Unread',
                              valueColor: n.read ? _C.inkSoft : cfg.fg,
                            ),
                          ],
                          const SizedBox(height: 32),
                          // Delete button
                          GestureDetector(
                            onTap: _confirmDelete,
                            child: Container(
                              height: 52,
                              decoration: BoxDecoration(
                                color: _C.redLight,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: _C.red.withOpacity(0.2)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.delete_outline_rounded, color: _C.red, size: 20),
                                  const SizedBox(width: 8),
                                  Text('Delete Notification',
                                    style: GoogleFonts.dmSans(
                                      fontWeight: FontWeight.w700, fontSize: 14, color: _C.red)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final String label, value;
  final Color? valueColor;
  const _MetaRow({required this.label, required this.value, this.valueColor});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        Text(label, style: GoogleFonts.dmSans(fontSize: 13, color: _C.inkSoft, fontWeight: FontWeight.w500)),
        const Spacer(),
        Text(value, style: GoogleFonts.dmSans(
          fontSize: 13, color: valueColor ?? _C.ink, fontWeight: FontWeight.w700)),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// SKELETON LOADER
// ─────────────────────────────────────────────────────────────────────────────

class _SkeletonTile extends StatefulWidget {
  final int index;
  const _SkeletonTile({required this.index});
  @override State<_SkeletonTile> createState() => _SkeletonTileState();
}

class _SkeletonTileState extends State<_SkeletonTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac = AnimationController(
    vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
  @override void dispose() { _ac.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _ac,
    builder: (_, __) {
      final op = 0.04 + _ac.value * 0.06;
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _C.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _C.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(width: 46, height: 46, decoration: BoxDecoration(
              color: Colors.black.withOpacity(op), shape: BoxShape.circle)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(height: 13, width: double.infinity,
                decoration: BoxDecoration(color: Colors.black.withOpacity(op), borderRadius: BorderRadius.circular(6))),
              const SizedBox(height: 8),
              Container(height: 11, width: MediaQuery.of(context).size.width * 0.55,
                decoration: BoxDecoration(color: Colors.black.withOpacity(op * 0.7), borderRadius: BorderRadius.circular(6))),
              const SizedBox(height: 6),
              Container(height: 11, width: MediaQuery.of(context).size.width * 0.35,
                decoration: BoxDecoration(color: Colors.black.withOpacity(op * 0.5), borderRadius: BorderRadius.circular(6))),
            ])),
          ],
        ),
      );
    },
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED SMALL WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;
  const _IconBtn({required this.icon, required this.onTap, this.color});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 42, height: 42,
      decoration: BoxDecoration(
        color: color != null ? color!.withOpacity(0.08) : _C.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color != null ? color!.withOpacity(0.15) : _C.border),
      ),
      child: Icon(icon, size: 20, color: color ?? _C.ink),
    ),
  );
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  final Color? accent;
  const _FilterChip({required this.label, required this.active, required this.onTap, this.accent});

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
          border: Border.all(color: active ? a : _C.border),
        ),
        child: Text(label,
          style: GoogleFonts.dmSans(
            fontSize: 12, fontWeight: FontWeight.w700,
            color: active ? Colors.white : _C.inkMid)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────────────────────

String _formatFull(DateTime dt) {
  final weekdays = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
  final wd = weekdays[dt.weekday - 1];
  final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
  final m = dt.minute.toString().padLeft(2, '0');
  final ampm = dt.hour >= 12 ? 'PM' : 'AM';
  return '$wd, ${dt.day} ${_months[dt.month - 1]} ${dt.year}  ·  $h:$m $ampm';
}

String _formatAmount(double v) {
  if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
  if (v >= 1000)    return '${(v / 1000).toStringAsFixed(0)}K';
  return v.toStringAsFixed(0);
}