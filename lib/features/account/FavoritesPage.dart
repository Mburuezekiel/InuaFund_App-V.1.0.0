import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../../core/network/auth_service.dart';

// ─────────────────────────────────────────────
//  PALETTE  (matches existing app theme)
// ─────────────────────────────────────────────
class _C {
  static const forestGreen = Color(0xFF0B5E35);
  static const midGreen    = Color(0xFF1A8C52);
  static const limeGreen   = Color(0xFF4CC97A);
  static const savanna     = Color(0xFFE8A020);
  static const crimson     = Color(0xFFD93025);
  static const amber       = Color(0xFFE8860A);
  static const ink         = Color(0xFF0D0D0D);
  static const cloud       = Color(0xFFEEEEEE);
  static const snow        = Color(0xFFF4F6F4);
  static const white       = Color(0xFFFFFFFF);
  static const mist        = Color(0xFF8FA896);
  static const sub         = Color(0xFF6B7280);
  static const bdr         = Color(0xFFE5E7EB);
}

// ─────────────────────────────────────────────
//  MODEL
// ─────────────────────────────────────────────
class FavoriteCampaign {
  final String id;
  final String title;
  final String description;
  final double raised;
  final double goal;
  final String currency;
  final String status;
  final String? endDate;
  final String? imageUrl;

  const FavoriteCampaign({
    required this.id,
    required this.title,
    required this.description,
    required this.raised,
    required this.goal,
    required this.currency,
    required this.status,
    this.endDate,
    this.imageUrl,
  });

  factory FavoriteCampaign.fromJson(Map<String, dynamic> j) {
    double _d(dynamic v) => v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0.0;
    return FavoriteCampaign(
      id:          j['_id']?.toString() ?? j['id']?.toString() ?? '',
      title:       j['title']?.toString() ?? '',
      description: j['description']?.toString() ?? '',
      raised:      _d(j['amountRaised'] ?? j['raised']),
      goal:        _d(j['goal']),
      currency:    j['currency']?.toString() ?? 'KES',
      status:      j['status']?.toString() ?? 'active',
      endDate:     j['endDate']?.toString(),
      imageUrl:    j['imageUrl']?.toString(),
    );
  }

  double get progress => goal > 0 ? (raised / goal * 100).clamp(0, 100) : 0;

  int get daysLeft {
    if (endDate == null) return 0;
    try {
      final diff = DateTime.parse(endDate!).difference(DateTime.now()).inDays;
      return diff > 0 ? diff : 0;
    } catch (_) { return 0; }
  }
}

// ─────────────────────────────────────────────
//  API
// ─────────────────────────────────────────────
class _FavoritesApi {
  static const _base = 'https://api.inuafund.co.ke/api';

  static Map<String, String> _headers(String token) => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };

  static Future<List<FavoriteCampaign>> getFavorites(String token) async {
    final res = await http.get(Uri.parse('$_base/favorites'), headers: _headers(token))
        .timeout(const Duration(seconds: 12));

    
    if (res.statusCode == 200) {
      final dynamic decoded = json.decode(res.body);
      debugPrint('=== DECODED TYPE: ${decoded.runtimeType} ===');

      List<dynamic> rawList = [];

      // Case 1: entire response is a List
      if (decoded is List) {
        rawList = decoded;
      }
      // Case 2: response is a Map
      else if (decoded is Map) {
        final body = decoded as Map<String, dynamic>;
        debugPrint('=== TOP-LEVEL KEYS: ${body.keys.toList()} ===');

        // Try every known key at top level first
        for (final key in ['favorites', 'campaigns', 'data', 'items', 'results', 'records']) {
          if (body[key] is List) {
            rawList = body[key] as List;
            debugPrint('=== FOUND LIST AT KEY: $key, length: ${rawList.length} ===');
            break;
          }
          // One level deeper
          if (body[key] is Map) {
            final inner = body[key] as Map<String, dynamic>;
            debugPrint('=== KEY "$key" is Map, inner keys: ${inner.keys.toList()} ===');
            for (final innerKey in ['favorites', 'campaigns', 'items', 'results', 'records', 'data']) {
              if (inner[innerKey] is List) {
                rawList = inner[innerKey] as List;
                debugPrint('=== FOUND LIST AT $key.$innerKey, length: ${rawList.length} ===');
                break;
              }
            }
            if (rawList.isNotEmpty) break;
          }
        }

        // Last resort: find ANY list value in the top-level map
        if (rawList.isEmpty) {
          for (final entry in body.entries) {
            if (entry.value is List) {
              rawList = entry.value as List;
              debugPrint('=== FALLBACK: found list at key "${entry.key}", length: ${rawList.length} ===');
              break;
            }
          }
        }
      }

      debugPrint('=== RAW LIST LENGTH: ${rawList.length} ===');
      if (rawList.isNotEmpty) {
        debugPrint('=== FIRST ITEM TYPE: ${rawList.first.runtimeType} ===');
        debugPrint('=== FIRST ITEM: ${rawList.first} ===');
      }

      // Safely parse — skip anything that isn't a Map
      return rawList
          .where((e) => e is Map)
          .map((e) => FavoriteCampaign.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }

    throw Exception('Failed to load favorites (${res.statusCode}): ${res.body}');
  }

  static Future<void> removeFavorite(String campaignId, String token) async {
    final res = await http.delete(
      Uri.parse('$_base/favorites/$campaignId'),
      headers: _headers(token),
    ).timeout(const Duration(seconds: 12));
    if (res.statusCode != 200 && res.statusCode != 204) {
      throw Exception('Failed to remove favorite');
    }
  }
}

// ─────────────────────────────────────────────
//  HELPERS
// ─────────────────────────────────────────────
String _kes(double v) {
  if (v >= 1000000) return 'KES ${(v / 1000000).toStringAsFixed(1)}M';
  if (v >= 1000)    return 'KES ${(v / 1000).toStringAsFixed(1)}K';
  return 'KES ${v.toStringAsFixed(0)}';
}

// ─────────────────────────────────────────────
//  SORT / FILTER ENUMS
// ─────────────────────────────────────────────
enum _SortField { endDate, title, raised, progress }
enum _SortDir   { asc, desc }
enum _ViewMode  { grid, list }

// ─────────────────────────────────────────────
//  MAIN SCREEN
// ─────────────────────────────────────────────
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen>
    with TickerProviderStateMixin {
  List<FavoriteCampaign> _favorites = [];
  bool _loading = true;
  String? _error;

  final _searchCtrl = TextEditingController();
  String _search = '';
  String _statusFilter = 'all';
  _SortField _sortField = _SortField.endDate;
  _SortDir   _sortDir   = _SortDir.asc;
  _ViewMode  _viewMode  = _ViewMode.grid;
  bool _showFilters = false;

  // Animations
  late AnimationController _fadeCtrl;
  late Animation<double>   _fadeAnim;
  late AnimationController _filterCtrl;
  late Animation<double>   _filterAnim;

  // Stagger list for cards
  final List<AnimationController> _cardCtrls = [];

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _filterCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _filterAnim = CurvedAnimation(parent: _filterCtrl, curve: Curves.easeInOut);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      if (!auth.isAuthenticated) {
        context.go('/login');
      } else {
        _fetch(auth.token);
      }
    });
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _filterCtrl.dispose();
    _searchCtrl.dispose();
    for (final c in _cardCtrls) c.dispose();
    super.dispose();
  }

  Future<void> _fetch(String token) async {
    setState(() { _loading = true; _error = null; });
    for (final c in _cardCtrls) c.dispose();
    _cardCtrls.clear();

    try {
      final favs = await _FavoritesApi.getFavorites(token);
      // Build per-card animation controllers
      for (var i = 0; i < favs.length; i++) {
        final ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
        _cardCtrls.add(ctrl);
      }
      setState(() { _favorites = favs; _loading = false; });
      _fadeCtrl.forward(from: 0);
      // Stagger card entrances
      for (var i = 0; i < _cardCtrls.length; i++) {
        Future.delayed(Duration(milliseconds: 60 * i), () {
          if (mounted) _cardCtrls[i].forward();
        });
      }
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _remove(String campaignId) async {
    final auth = context.read<AuthProvider>();
    try {
      await _FavoritesApi.removeFavorite(campaignId, auth.token);
      setState(() => _favorites.removeWhere((f) => f.id == campaignId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Removed from favorites'),
            backgroundColor: _C.midGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to remove. Try again.'),
            backgroundColor: _C.crimson,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  void _share(FavoriteCampaign c) {
    final url = 'https://inuafund.co.ke/campaigns/${c.id}';
    final msg = 'Hey there! Check out this campaign: "${c.title}". '
        'Every donation makes a real difference! $url';
    Clipboard.setData(ClipboardData(text: msg));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(children: [
          Icon(Icons.check_circle_outline_rounded, color: _C.white, size: 16),
          SizedBox(width: 8),
          Text('Link copied to clipboard!'),
        ]),
        backgroundColor: _C.midGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _toggleFilters() {
    setState(() => _showFilters = !_showFilters);
    if (_showFilters) {
      _filterCtrl.forward();
    } else {
      _filterCtrl.reverse();
    }
  }

  List<FavoriteCampaign> get _filtered {
    var list = [..._favorites];
    if (_search.isNotEmpty) {
      list = list.where((f) => f.title.toLowerCase().contains(_search.toLowerCase())).toList();
    }
    if (_statusFilter != 'all') {
      list = list.where((f) => f.status == _statusFilter).toList();
    }
    list.sort((a, b) {
      int cmp;
      switch (_sortField) {
        case _SortField.title:    cmp = a.title.compareTo(b.title); break;
        case _SortField.raised:   cmp = a.raised.compareTo(b.raised); break;
        case _SortField.progress: cmp = a.progress.compareTo(b.progress); break;
        default:                  cmp = a.daysLeft.compareTo(b.daysLeft);
      }
      return _sortDir == _SortDir.asc ? cmp : -cmp;
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (!auth.isAuthenticated) return const SizedBox.shrink();
    if (_loading) return const _LoadingScreen();
    if (_error != null) {
      return _ErrorScreen(error: _error!, onRetry: () => _fetch(auth.token));
    }

    final items = _filtered;

    return Scaffold(
      backgroundColor: _C.snow,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── HEADER ──
              SliverToBoxAdapter(child: _buildHeader(auth.token)),

              // ── SEARCH ──
              SliverToBoxAdapter(child: _buildSearch()),

              // ── FILTERS PANEL ──
              SliverToBoxAdapter(child: _buildFilterPanel()),

              // ── STATS BAR ──
              if (_favorites.isNotEmpty)
                SliverToBoxAdapter(child: _buildStatsBar()),

              // ── CONTENT ──
              if (items.isEmpty)
                SliverFillRemaining(child: _buildEmptyState())
              else if (_viewMode == _ViewMode.grid)
                _buildGrid(items)
              else
                _buildList(items),

              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          ),
        ),
      ),
    );
  }

  // ── HEADER ───────────────────────────────────
  Widget _buildHeader(String token) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_C.crimson, Color(0xFFFF6B6B)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.favorite_rounded, color: _C.white, size: 16),
                  ),
                  const SizedBox(width: 10),
                  const Text('My Favourites',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: _C.ink,
                      letterSpacing: -0.5,
                    ),
                  ),
                ]),
                const SizedBox(height: 4),
                Text(
                  '${_favorites.length} saved campaign${_favorites.length == 1 ? '' : 's'}',
                  style: const TextStyle(fontSize: 13, color: _C.mist),
                ),
              ],
            ),
          ),
          // Refresh
          GestureDetector(
            onTap: () => _fetch(token),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _C.midGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.refresh_rounded, color: _C.midGreen, size: 20),
            ),
          ),
          const SizedBox(width: 8),
          // View toggle
          Container(
            decoration: BoxDecoration(
              color: _C.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _C.bdr),
            ),
            child: Row(children: [
              _ViewBtn(
                icon: Icons.grid_view_rounded,
                selected: _viewMode == _ViewMode.grid,
                onTap: () => setState(() => _viewMode = _ViewMode.grid),
              ),
              _ViewBtn(
                icon: Icons.view_list_rounded,
                selected: _viewMode == _ViewMode.list,
                onTap: () => setState(() => _viewMode = _ViewMode.list),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  // ── SEARCH ───────────────────────────────────
  Widget _buildSearch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: _C.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: _C.ink.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 3))],
              ),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _search = v),
                style: const TextStyle(fontSize: 14, color: _C.ink),
                decoration: InputDecoration(
                  hintText: 'Search favourites...',
                  hintStyle: const TextStyle(color: _C.mist, fontSize: 14),
                  prefixIcon: const Icon(Icons.search_rounded, color: _C.mist, size: 20),
                  suffixIcon: _search.isNotEmpty
                      ? GestureDetector(
                          onTap: () { _searchCtrl.clear(); setState(() => _search = ''); },
                          child: const Icon(Icons.close_rounded, color: _C.mist, size: 18),
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.transparent,
                  contentPadding: const EdgeInsets.symmetric(vertical: 13),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Filter toggle button
          GestureDetector(
            onTap: _toggleFilters,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: _showFilters ? _C.midGreen : _C.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: _C.ink.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 3))],
              ),
              child: Icon(Icons.tune_rounded,
                color: _showFilters ? _C.white : _C.ink,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── FILTER PANEL ─────────────────────────────
  Widget _buildFilterPanel() {
    return SizeTransition(
      sizeFactor: _filterAnim,
      axisAlignment: -1,
      child: FadeTransition(
        opacity: _filterAnim,
        child: Container(
          margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _C.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _C.bdr),
            boxShadow: [BoxShadow(color: _C.ink.withOpacity(0.04), blurRadius: 12)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Filters & Sorting',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _C.ink),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _FilterDropdown<String>(
                      label: 'Status',
                      value: _statusFilter,
                      items: const {
                        'all': 'All Statuses',
                        'active': 'Active',
                        'completed': 'Completed',
                        'pending': 'Pending',
                      },
                      onChanged: (v) => setState(() => _statusFilter = v),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _FilterDropdown<_SortField>(
                      label: 'Sort by',
                      value: _sortField,
                      items: const {
                        _SortField.endDate:  'Time Left',
                        _SortField.title:    'Name',
                        _SortField.raised:   'Amount Raised',
                        _SortField.progress: 'Progress',
                      },
                      onChanged: (v) => setState(() => _sortField = v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => setState(() =>
                        _sortDir = _sortDir == _SortDir.asc ? _SortDir.desc : _SortDir.asc),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _C.snow,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _sortDir == _SortDir.asc
                            ? Icons.arrow_upward_rounded
                            : Icons.arrow_downward_rounded,
                        size: 18,
                        color: _C.midGreen,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── STATS BAR ────────────────────────────────
  Widget _buildStatsBar() {
    final total  = _favorites.length;
    final active = _favorites.where((f) => f.status == 'active').length;
    final totalRaised = _favorites.fold(0.0, (s, f) => s + f.raised);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Row(
        children: [
          _StatPill(label: '$total saved',       icon: Icons.bookmark_rounded,       color: _C.midGreen),
          const SizedBox(width: 8),
          _StatPill(label: '$active active',     icon: Icons.bolt_rounded,           color: _C.savanna),
          const SizedBox(width: 8),
          _StatPill(label: _kes(totalRaised),    icon: Icons.trending_up_rounded,    color: _C.forestGreen),
        ],
      ),
    );
  }

  // ── EMPTY STATE ──────────────────────────────
  Widget _buildEmptyState() {
    final hasFilters = _search.isNotEmpty || _statusFilter != 'all';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: _C.crimson.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.favorite_border_rounded, size: 36, color: _C.crimson),
            ),
            const SizedBox(height: 20),
            Text(
              hasFilters ? 'No matches found' : 'No favourites yet',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _C.ink),
            ),
            const SizedBox(height: 8),
            Text(
              hasFilters
                  ? 'Try adjusting your search or filters.'
                  : 'Start exploring campaigns and save the ones you love!',
              textAlign: TextAlign.center,
              style: const TextStyle(color: _C.mist, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: () => context.push('/explore'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_C.midGreen, _C.forestGreen],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: _C.midGreen.withOpacity(0.35), blurRadius: 14, offset: const Offset(0, 5)),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.explore_rounded, color: _C.white, size: 18),
                    SizedBox(width: 8),
                    Text('Browse Campaigns',
                      style: TextStyle(color: _C.white, fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── GRID VIEW ────────────────────────────────
  Widget _buildGrid(List<FavoriteCampaign> items) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.72,
        ),
        delegate: SliverChildBuilderDelegate(
          (ctx, i) {
            final c = items[i];
            // Find original index for animation controller
            final origIdx = _favorites.indexWhere((f) => f.id == c.id);
            final ctrl = (origIdx >= 0 && origIdx < _cardCtrls.length)
                ? _cardCtrls[origIdx]
                : null;

            Widget card = _GridCard(
              campaign: c,
              onRemove: () => _remove(c.id),
              onShare: () => _share(c),
              onTap: () => context.push('/campaigns/${c.id}'),
            );

            if (ctrl != null) {
              card = AnimatedBuilder(
                animation: ctrl,
                builder: (_, child) => Transform.translate(
                  offset: Offset(0, 30 * (1 - ctrl.value)),
                  child: Opacity(opacity: ctrl.value.clamp(0.0, 1.0), child: child),
                ),
                child: card,
              );
            }
            return card;
          },
          childCount: items.length,
        ),
      ),
    );
  }

  // ── LIST VIEW ────────────────────────────────
  Widget _buildList(List<FavoriteCampaign> items) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (ctx, i) {
            final c = items[i];
            final origIdx = _favorites.indexWhere((f) => f.id == c.id);
            final ctrl = (origIdx >= 0 && origIdx < _cardCtrls.length)
                ? _cardCtrls[origIdx]
                : null;

            Widget card = Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ListCard(
                campaign: c,
                onRemove: () => _remove(c.id),
                onShare: () => _share(c),
                onTap: () => context.push('/campaigns/${c.id}'),
              ),
            );

            if (ctrl != null) {
              card = AnimatedBuilder(
                animation: ctrl,
                builder: (_, child) => Transform.translate(
                  offset: Offset(40 * (1 - ctrl.value), 0),
                  child: Opacity(opacity: ctrl.value.clamp(0.0, 1.0), child: child),
                ),
                child: card,
              );
            }
            return card;
          },
          childCount: items.length,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  GRID CARD
// ─────────────────────────────────────────────
class _GridCard extends StatefulWidget {
  final FavoriteCampaign campaign;
  final VoidCallback onRemove;
  final VoidCallback onShare;
  final VoidCallback onTap;

  const _GridCard({
    required this.campaign,
    required this.onRemove,
    required this.onShare,
    required this.onTap,
  });

  @override
  State<_GridCard> createState() => _GridCardState();
}

class _GridCardState extends State<_GridCard> with SingleTickerProviderStateMixin {
  late AnimationController _pressCtrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 100));
    _scaleAnim = Tween(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() { _pressCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final c = widget.campaign;
    final pct = c.progress;

    return GestureDetector(
      onTapDown: (_) => _pressCtrl.forward(),
      onTapUp: (_) { _pressCtrl.reverse(); widget.onTap(); },
      onTapCancel: () => _pressCtrl.reverse(),
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Container(
          decoration: BoxDecoration(
            color: _C.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(color: _C.ink.withOpacity(0.07), blurRadius: 16, offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top badge row ──
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 8, 0),
                child: Row(
                  children: [
                    _StatusBadge(status: c.status),
                    const Spacer(),
                    _IconAction(icon: Icons.share_rounded,         color: _C.sub,    onTap: widget.onShare),
                    _IconAction(icon: Icons.favorite_rounded,      color: _C.crimson, onTap: widget.onRemove),
                  ],
                ),
              ),
              // ── Title ──
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Text(c.title,
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _C.ink, height: 1.3),
                ),
              ),
              // ── Description ──
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                child: Text(c.description,
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: _C.mist, height: 1.4),
                ),
              ),
              const Spacer(),
              // ── Progress section ──
              Container(
                margin: const EdgeInsets.fromLTRB(0, 8, 0, 0),
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                decoration: const BoxDecoration(
                  color: _C.snow,
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_kes(c.raised),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _C.forestGreen),
                        ),
                        Text('${pct.toStringAsFixed(0)}%',
                          style: const TextStyle(fontSize: 11, color: _C.mist, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct / 100,
                        minHeight: 5,
                        backgroundColor: _C.cloud,
                        valueColor: AlwaysStoppedAnimation(
                          pct >= 100 ? _C.savanna : _C.limeGreen,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.schedule_rounded, size: 11, color: _C.mist),
                        const SizedBox(width: 3),
                        Text('${c.daysLeft} days left',
                          style: const TextStyle(fontSize: 10, color: _C.mist),
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
    );
  }
}

// ─────────────────────────────────────────────
//  LIST CARD
// ─────────────────────────────────────────────
class _ListCard extends StatefulWidget {
  final FavoriteCampaign campaign;
  final VoidCallback onRemove;
  final VoidCallback onShare;
  final VoidCallback onTap;

  const _ListCard({
    required this.campaign,
    required this.onRemove,
    required this.onShare,
    required this.onTap,
  });

  @override
  State<_ListCard> createState() => _ListCardState();
}

class _ListCardState extends State<_ListCard> with SingleTickerProviderStateMixin {
  late AnimationController _pressCtrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 100));
    _scaleAnim = Tween(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() { _pressCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final c = widget.campaign;
    final pct = c.progress;

    return GestureDetector(
      onTapDown: (_) => _pressCtrl.forward(),
      onTapUp: (_) { _pressCtrl.reverse(); widget.onTap(); },
      onTapCancel: () => _pressCtrl.reverse(),
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _C.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(color: _C.ink.withOpacity(0.06), blurRadius: 14, offset: const Offset(0, 3)),
            ],
          ),
          child: Row(
            children: [
              // ── Left: avatar initials ──
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_C.midGreen, _C.forestGreen],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    c.title.isNotEmpty ? c.title[0].toUpperCase() : '?',
                    style: const TextStyle(color: _C.white, fontWeight: FontWeight.w900, fontSize: 20),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // ── Middle: info ──
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      _StatusBadge(status: c.status),
                    ]),
                    const SizedBox(height: 4),
                    Text(c.title,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _C.ink),
                    ),
                    const SizedBox(height: 2),
                    Text(c.description,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: _C.mist),
                    ),
                    const SizedBox(height: 8),
                    // Progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct / 100,
                        minHeight: 5,
                        backgroundColor: _C.cloud,
                        valueColor: AlwaysStoppedAnimation(
                          pct >= 100 ? _C.savanna : _C.limeGreen,
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Text(_kes(c.raised),
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _C.forestGreen),
                        ),
                        const Text('  ·  ', style: TextStyle(color: _C.mist)),
                        Text('${pct.toStringAsFixed(0)}% funded',
                          style: const TextStyle(fontSize: 11, color: _C.mist),
                        ),
                        const Spacer(),
                        const Icon(Icons.schedule_rounded, size: 11, color: _C.mist),
                        const SizedBox(width: 2),
                        Text('${c.daysLeft}d',
                          style: const TextStyle(fontSize: 11, color: _C.mist),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // ── Right: actions ──
              Column(
                children: [
                  _IconAction(icon: Icons.share_rounded,    color: _C.sub,    onTap: widget.onShare),
                  const SizedBox(height: 4),
                  _IconAction(icon: Icons.favorite_rounded, color: _C.crimson, onTap: widget.onRemove),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  REUSABLE SMALL WIDGETS
// ─────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  Color get _bg {
    switch (status) {
      case 'active':    return _C.limeGreen.withOpacity(0.12);
      case 'completed': return _C.midGreen.withOpacity(0.10);
      case 'pending':   return _C.savanna.withOpacity(0.12);
      default:          return _C.cloud;
    }
  }
  Color get _fg {
    switch (status) {
      case 'active':    return _C.forestGreen;
      case 'completed': return _C.midGreen;
      case 'pending':   return _C.amber;
      default:          return _C.mist;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(20)),
      child: Text(
        status[0].toUpperCase() + status.substring(1),
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _fg),
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _IconAction({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 15),
      ),
    );
  }
}

class _ViewBtn extends StatelessWidget {
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _ViewBtn({required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: selected ? _C.midGreen.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18, color: selected ? _C.midGreen : _C.mist),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  const _StatPill({required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }
}

class _FilterDropdown<T> extends StatelessWidget {
  final String label;
  final T value;
  final Map<T, String> items;
  final ValueChanged<T> onChanged;
  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _C.sub)),
        const SizedBox(height: 5),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: _C.snow,
            borderRadius: BorderRadius.circular(10),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              style: const TextStyle(color: _C.ink, fontSize: 12, fontWeight: FontWeight.w500),
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _C.mist, size: 16),
              items: items.entries.map((e) => DropdownMenuItem(
                value: e.key,
                child: Text(e.value, overflow: TextOverflow.ellipsis),
              )).toList(),
              onChanged: (v) { if (v != null) onChanged(v); },
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  LOADING / ERROR
// ─────────────────────────────────────────────
class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();
  @override
  Widget build(BuildContext context) => const Scaffold(
    backgroundColor: _C.snow,
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: _C.midGreen, strokeWidth: 3),
          SizedBox(height: 16),
          Text('Loading your favourites...',
            style: TextStyle(color: _C.mist, fontSize: 14, fontWeight: FontWeight.w500)),
        ],
      ),
    ),
  );
}

class _ErrorScreen extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorScreen({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _C.snow,
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _C.crimson.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.wifi_off_rounded, size: 40, color: _C.crimson),
            ),
            const SizedBox(height: 20),
            const Text('Something went wrong',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _C.ink),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _C.crimson.withOpacity(0.07),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(error, style: const TextStyle(color: _C.crimson, fontSize: 12), textAlign: TextAlign.center),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _C.midGreen,
                foregroundColor: _C.white,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}