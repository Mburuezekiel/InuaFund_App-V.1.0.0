import 'package:flutter/material.dart';

class AppColors {
  static const forestGreen = Color(0xFF0B5E35);
  static const midGreen    = Color(0xFF1A8C52);
  static const limeGreen   = Color(0xFF4CC97A);
  static const ink         = Color(0xFF0D0D0D);
  static const cloud       = Color(0xFFEEEEEE);
  static const snow        = Color(0xFFF4F6F4);
  static const white       = Color(0xFFFFFFFF);
  static const crimson     = Color(0xFFD93025);
  static const amber       = Color(0xFFE8860A);
  static const mist        = Color(0xFF8FA896);
  static const darkMist    = Color(0xFF4D6657);
}

class CategoryPage extends StatefulWidget {
  final String category;

  const CategoryPage({super.key, required this.category});

  @override
  State<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage> {
  bool isLoading = true;

  List<dynamic> campaigns = [];
  List<dynamic> filteredCampaigns = [];

  final TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchCampaigns();
  }

  String getCategoryIcon(String category) {
    final icons = {
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
    setState(() => isLoading = true);

    try {
      // 🔁 Replace with your API call
      await Future.delayed(const Duration(seconds: 2));

      List<dynamic> data = []; // getApprovedCampaigns()

      final filtered = data.where((c) =>
          (c['category'] ?? '').toLowerCase() ==
          widget.category.toLowerCase()).toList();

      setState(() {
        campaigns = filtered;
        filteredCampaigns = filtered;
      });
    } catch (e) {
      setState(() {
        campaigns = [];
        filteredCampaigns = [];
      });
    } finally {
      setState(() => isLoading = false);
    }
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
          (c['targetAmount']?.toString() ?? '').contains(query);
    }).toList();

    setState(() => filteredCampaigns = results);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.snow,

      /// 🔹 HEADER
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.ink),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Text(
              getCategoryIcon(widget.category),
              style: const TextStyle(fontSize: 22),
            ),
            const SizedBox(width: 8),
            Text(
              "${widget.category} Campaigns",
              style: const TextStyle(
                color: AppColors.ink,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),

      body: Column(
        children: [
          /// 🔍 SEARCH BAR
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: searchController,
                    onSubmitted: (_) => handleSearch(),
                    decoration: InputDecoration(
                      hintText: "Search campaigns...",
                      filled: true,
                      fillColor: AppColors.white,
                      prefixIcon: const Icon(Icons.search),
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: handleSearch,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.midGreen,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text("Search"),
                ),
              ],
            ),
          ),

          /// 📊 COUNT
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Chip(
                backgroundColor: AppColors.limeGreen.withOpacity(0.2),
                label: Text(
                  "${filteredCampaigns.length} campaigns",
                  style: const TextStyle(
                    color: AppColors.forestGreen,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),

          /// 🧾 CONTENT
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredCampaigns.isEmpty
                    ? _buildEmptyState()
                    : GridView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredCampaigns.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.75,
                        ),
                        itemBuilder: (context, index) {
                          final campaign = filteredCampaigns[index];
                          return _CampaignCard(campaign: campaign);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              getCategoryIcon(widget.category),
              style: const TextStyle(fontSize: 48),
            ),
            const SizedBox(height: 16),
            const Text(
              "No Campaigns Found",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Try adjusting your search or start a new campaign.",
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.darkMist),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.midGreen,
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 14),
              ),
              onPressed: () {},
              child: const Text("Start Campaign"),
            )
          ],
        ),
      ),
    );
  }
}

/// 🧾 CAMPAIGN CARD
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
          /// IMAGE PLACEHOLDER
          Container(
            height: 110,
            decoration: const BoxDecoration(
              color: AppColors.cloud,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(16),
              ),
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
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.ink,
                  ),
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