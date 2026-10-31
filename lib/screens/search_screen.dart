import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:marquee/marquee.dart';
import 'package:thunghiem1/models/plant_suggestion.dart';
import 'package:thunghiem1/services/api_service.dart';
import 'package:thunghiem1/screens/plant_detail_sheet.dart';
import 'package:thunghiem1/widgets/back_nav_button.dart';
import 'package:thunghiem1/widgets/search_text_field.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _api = ApiService();

  // ── Controller-based search: listens for every text change reliably ──
  final _controller = TextEditingController();
  Timer? _debounce;

  // Suggestion state (always visible, fetched once on init / on refresh)
  bool _loadingSuggestions = true;
  List<PlantSuggestion> _suggestions = [];

  // Search-result state (shown below suggestions whenever query is non-empty)
  bool _loadingSearch = false;
  String _query = '';
  List<PlantSuggestion> _searchResults = [];
  String? _searchError;

  // Guard against double-tapping
  bool _isOpeningSheet = false;

  // ─────────────────── Detail sheet ────────────────────────────

  Future<void> _openDetailSheet(PlantSuggestion item) async {
    if (_isOpeningSheet) return;
    setState(() => _isOpeningSheet = true);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          PlantDetailSheet(prediction: item, showActions: false),
    );
    if (mounted) setState(() => _isOpeningSheet = false);
  }

  // ───────────────────────── Lifecycle ─────────────────────────

  @override
  void initState() {
    super.initState();
    // Listen via controller so both keyboard input AND programmatic setText
    // both trigger the search reliably.
    _controller.addListener(_onControllerChanged);
    _loadSuggestions();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  // ─────────────────────── Search logic ────────────────────────

  void _onControllerChanged() {
    final q = _controller.text.trim();
    if (q == _query) return; // no-op if text hasn't actually changed

    _debounce?.cancel();
    setState(() {
      _query = q;
      if (q.isEmpty) {
        _searchResults = [];
        _searchError = null;
        _loadingSearch = false;
      } else {
        _loadingSearch = true;
        _searchError = null;
      }
    });

    if (q.isEmpty) return;
    _debounce = Timer(const Duration(milliseconds: 400), () => _doSearch(q));
  }

  Future<void> _doSearch(String q) async {
    try {
      final data = await _api.searchPlants(q, limit: 20);
      if (!mounted) return;
      final rawList = data['results'];
      final results = rawList is List
          ? rawList
                .whereType<Map<String, dynamic>>()
                .map(PlantSuggestion.fromJson)
                .toList()
          : <PlantSuggestion>[];
      setState(() {
        _searchResults = results;
        _loadingSearch = false;
        _searchError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingSearch = false;
        _searchError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  // ─────────────────── Suggestion logic ────────────────────────

  Future<void> _loadSuggestions() async {
    setState(() => _loadingSuggestions = true);
    try {
      final raw = await _api.getRandomSuggestions(limit: 4);
      if (!mounted) return;
      setState(() {
        _suggestions = raw.map(PlantSuggestion.fromJson).toList();
        _loadingSuggestions = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingSuggestions = false);
    }
  }

  // ──────────────────────── Build ──────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── Sticky top area: header + search bar + suggestions ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),

                    // Header
                    Row(
                      children: [
                        const BackNavButton(),
                        Expanded(
                          child: Center(
                            child: Text(
                              'Search',
                              style: GoogleFonts.inter(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF1B4332),
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            _controller.clear();
                            _loadSuggestions();
                          },
                          icon: const Icon(
                            Icons.refresh_rounded,
                            color: Color(0xFF2D6A4F),
                            size: 26,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Search bar (controller-driven)
                    SearchTextField(
                      hintText: 'Tìm kiếm cây trồng...',
                      readOnly: false,
                      autoFocus: true,
                      heroTag: 'search_bar_detail',
                      controller: _controller,
                    ),
                    const SizedBox(height: 24),

                    // ── Suggestions section — only visible when query is empty ──
                    if (_query.isEmpty) ...[
                      Text(
                        'Gợi ý cho bạn',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildSuggestionGrid(),
                      const SizedBox(height: 28),
                    ],

                    // ── Results header (only when there is a query) ──
                    if (_query.isNotEmpty) ...[
                      Text(
                        _loadingSearch
                            ? 'Đang tìm kiếm...'
                            : _searchError != null
                            ? 'Lỗi tìm kiếm'
                            : 'Kết quả (${_searchResults.length})',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
              ),
            ),

            // ── Dynamic results list (below suggestions) ──
            if (_query.isEmpty)
              const SliverToBoxAdapter(child: SizedBox.shrink())
            else if (_loadingSearch)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: CircularProgressIndicator(color: Color(0xFF2D6A4F)),
                  ),
                ),
              )
            else if (_searchError != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 40,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.wifi_off_rounded,
                        color: Colors.grey,
                        size: 48,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _searchError!,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => _doSearch(_query),
                        child: const Text(
                          'Thử lại',
                          style: TextStyle(color: Color(0xFF2D6A4F)),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (_searchResults.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 40,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.search_off_rounded,
                        color: Colors.grey,
                        size: 48,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Không tìm thấy kết quả cho "$_query"',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final item = _searchResults[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildResultCard(item),
                    );
                  }, childCount: _searchResults.length),
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }

  // ─────────────────── Suggestion grid ─────────────────────────

  Widget _buildSuggestionGrid() {
    if (_loadingSuggestions) {
      return const SizedBox(
        height: 80,
        child: Center(
          child: CircularProgressIndicator(color: Color(0xFF2D6A4F)),
        ),
      );
    }
    if (_suggestions.isEmpty) {
      return SizedBox(
        height: 60,
        child: Center(
          child: Text(
            'Không có gợi ý',
            style: GoogleFonts.inter(fontSize: 14, color: Colors.grey),
          ),
        ),
      );
    }

    // 2-column grid with fixed height so it doesn't expand infinitely
    const crossAxisCount = 2;
    const cardAspectRatio = 1.1; // Slightly taller proportion
    const spacing = 20.0; // Slightly more spacing
    const extraPadding = 16.0; // Padding to reduce width
    final screenWidth = MediaQuery.sizeOf(context).width;
    final cardWidth =
        (screenWidth -
            40 -
            (extraPadding * 2) -
            spacing * (crossAxisCount - 1)) /
        crossAxisCount;
    final cardHeight = cardWidth / cardAspectRatio;
    final rows = (_suggestions.length / crossAxisCount).ceil();
    final gridHeight = rows * cardHeight + (rows - 1) * spacing;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: extraPadding),
      child: SizedBox(
        height: gridHeight,
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _suggestions.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            childAspectRatio: cardAspectRatio,
          ),
          itemBuilder: (context, index) =>
              _buildSuggestionCard(_suggestions[index]),
        ),
      ),
    );
  }

  Widget _buildSuggestionCard(PlantSuggestion item) {
    return GestureDetector(
      onTap: () {
        // Set text and the controller listener will fire _onControllerChanged
        _controller.text = item.commonName;
        // Move cursor to end
        _controller.selection = TextSelection.fromPosition(
          TextPosition(offset: _controller.text.length),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 14,
              child: Marquee(
                text: item.scientificName,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF2D6A4F),
                ),
                blankSpace: 30,
                velocity: 30,
                pauseAfterRound: const Duration(seconds: 1),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              item.commonName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────── Result card ─────────────────────────────

  Widget _buildResultCard(PlantSuggestion item) {
    final hasImage = item.imageUrl != null && item.imageUrl!.isNotEmpty;

    return GestureDetector(
      onTap: () => _openDetailSheet(item),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // ── Thumbnail image (or fallback icon) ──
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: hasImage
                  ? Image.network(
                      item.imageUrl!,
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _plantIconBox(),
                    )
                  : _plantIconBox(),
            ),
            const SizedBox(width: 14),

            // ── Name columns ──
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Common name (tên thông thường)
                  Text(
                    item.commonName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  if (item.scientificName.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    // Scientific name (tên khoa học)
                    SizedBox(
                      height: 16,
                      child: Marquee(
                        text: item.scientificName,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: const Color(0xFF2D6A4F),
                        ),
                        blankSpace: 30,
                        velocity: 30,
                        pauseAfterRound: const Duration(seconds: 1),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              color: Colors.grey,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  Widget _plantIconBox() {
    return Container(
      width: 64,
      height: 64,
      color: const Color(0xFFE8F5E9),
      child: const Icon(Icons.eco_rounded, color: Color(0xFF2D6A4F), size: 28),
    );
  }
}
