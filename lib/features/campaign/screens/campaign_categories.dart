import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class AppColors {
  static const forestGreen = Color(0xFF0B5E35);
  static const midGreen = Color(0xFF1A8C52);
  static const limeGreen = Color(0xFF4CC97A);
  static const ink = Color(0xFF0D0D0D);
  static const cloud = Color(0xFFEEEEEE);
  static const snow = Color(0xFFF4F6F4);
  static const white = Color(0xFFFFFFFF);
  static const darkMist = Color(0xFF4D6657);
}

class CategoryPage extends StatefulWidget {
  final String category;
  const CategoryPage({super.key, required this.category});

  @override
  State<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage> {
  bool isLoading = true;
  bool _isFetching = false;

  List<dynamic> campaigns = [];
  List<dynamic> filteredCampaigns = [];

  final TextEditingController searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    fetchCampaigns();
  }

  @override
  void didUpdateWidget(covariant CategoryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.category != widget.category) {
      fetchCampaigns();
    }
  }

  @override
  void dispose() {
    searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  String getCategoryIcon(String category) {
    const icons = {
      "education": "🎓",
      "medical": "🏥",
      "water": "💧",
      "animals": "🐕",
      "agriculture": "🌾",
      "technology": "💻",
      "community": "🏘️",
      "business": "💼",
      "emergency": "🚨",
      "environment": "🌳",
      "sports": "⚽",
      "arts": "🎨",
    };
    return icons[category.toLowerCase()] ?? "📋";
  }

  Future<void> fetchCampaigns() async {
    if (_isFetching) return;
    _isFetching = true;

    if (mounted) setState(() => isLoading = true);

    try {
      final response = await http.get(
        Uri.parse("https://api.inuafund.co.ke/api/campaigns"),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        List<dynamic> data = decoded['data'] ?? [];

        final filtered = data.where((c) =>
            (c['category'] ?? '').toLowerCase() ==
            widget.category.toLowerCase()).toList();

        if (!mounted) return;

        setState(() {
          campaigns = filtered;
          filteredCampaigns = filtered;
          isLoading = false;
        });
      } else {
        throw Exception("Failed to load");
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        campaigns = [];
        filteredCampaigns = [];
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to load campaigns")),
      );
    }

    _isFetching = false;
  }

  void _onSearchChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 300), () {
      handleSearch();
    });
  }

  void handleSearch() {
    final query = searchController.text.toLowerCase().trim();

    if (query.isEmpty) {
      setState(() => filteredCampaigns = campaigns);
      return;
    }

    final results = campaigns.where((c) {
      return (c['title'] ?? '').toLowerCase().contains(query) ||
          (c['description'] ?? '').toLowerCase().contains(query) ||
          (c['category'] ?? '').toLowerCase().contains(query) ||
          (c['targetAmount']?.toString() ?? '').contains(query) ||
          (c['currentAmount']?.toString() ?? '').contains(query) ||
          (c['tags'] != null &&
              (c['tags'] as List)
                  .any((tag) => tag.toLowerCase().contains(query)));
    }).toList();

    setState(() => filteredCampaigns = results);
  }

  @override
  Widget build(BuildContext context) {
    final isLarge = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: AppColors.snow,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.ink),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Text(getCategoryIcon(widget.category)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                "${widget.category} Campaigns",
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.ink,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),

      body: RefreshIndicator(
        onRefresh: fetchCampaigns,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            /// 🔥 FIXED SEARCH ROW
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: searchController,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: "Search campaigns...",
                      filled: true,
                      fillColor: AppColors.white,
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                /// ✅ FIX: constrain button width
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: handleSearch,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.midGreen,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    child: const Text("Search"),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Chip(
              backgroundColor: AppColors.limeGreen.withOpacity(0.2),
              label: Text("${filteredCampaigns.length} campaigns"),
            ),

            const SizedBox(height: 16),

            if (isLoading)
              const Center(child: CircularProgressIndicator())
            else if (filteredCampaigns.isEmpty)
              _buildEmptyState()
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredCampaigns.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: isLarge ? 3 : 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.75,
                ),
                itemBuilder: (_, i) =>
                    _CampaignCard(campaign: filteredCampaigns[i]),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Column(
      children: [
        const SizedBox(height: 40),
        Text(getCategoryIcon(widget.category),
            style: const TextStyle(fontSize: 48)),
        const SizedBox(height: 10),
        const Text("No Campaigns Found"),
      ],
    );
  }
}

class _CampaignCard extends StatelessWidget {
  final Map campaign;
  const _CampaignCard({required this.campaign});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 110,
            decoration: const BoxDecoration(
              color: AppColors.cloud,
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(16)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  campaign['title'] ?? "Campaign Title",
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  "KES ${campaign['currentAmount'] ?? 0}",
                  style: const TextStyle(
                    color: AppColors.midGreen,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}