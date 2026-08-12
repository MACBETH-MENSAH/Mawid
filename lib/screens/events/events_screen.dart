import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/event.dart';
import '../../providers/data_refresh_provider.dart';
import '../../services/event_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/event_card.dart';
import '../../widgets/mawid_top_bar.dart';
import 'event_details_screen.dart';
import 'filter_bottom_sheet.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  final _eventService = EventService.instance;
  final _searchController = TextEditingController();
  Timer? _debounce;

  static const _categories = [
    'All Events',
    'Technology',
    'Business',
    'Music & Arts',
    'Education',
  ];
  String _selectedCategory = 'All Events';

  List<EventModel> _events = [];
  bool _isLoading = true;
  String? _error;
  int _loadedForVersion = -1;

  @override
  void initState() {
    super.initState();
    // Deliberately not loading here — see the matching comment in
    // activity_screen.dart / home_screen.dart. build() below triggers the
    // first load and reloads again whenever DataRefreshProvider signals
    // that something changed elsewhere (this tab previously never
    // refreshed after a create/edit/delete happened on another screen).
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _maybeLoad(int refreshVersion) {
    if (_loadedForVersion == refreshVersion) return;
    _loadedForVersion = refreshVersion;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await _eventService.fetchPublishedEvents(
        searchQuery: _searchController.text,
        category: _selectedCategory == 'All Events' ? null : _selectedCategory,
      );
      setState(() {
        _events = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Could not load events.';
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _load);
  }

  void _openFilters() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const FilterBottomSheet(),
    );
    // Filter application itself doesn't wire into query params yet in this
    // stage — it's a UI-complete modal. Hook its results into _load() once
    // the "When" / "Sort by" filter state needs to affect the query.
  }

  @override
  Widget build(BuildContext context) {
    final refreshVersion = context.watch<DataRefreshProvider>().version;
    _maybeLoad(refreshVersion);

    return Scaffold(
      appBar: const MawidTopBar(),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    decoration: const InputDecoration(
                      hintText: 'Search events...',
                      prefixIcon: Icon(Icons.search, color: Colors.black54),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.tune),
                    onPressed: _openFilters,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final category = _categories[i];
                  final selected = category == _selectedCategory;
                  return ChoiceChip(
                    label: Text(category),
                    selected: selected,
                    onSelected: (_) {
                      setState(() => _selectedCategory = category);
                      _load();
                    },
                    selectedColor: AppColors.accent,
                    backgroundColor: AppColors.surface,
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide.none,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Text(_error!,
                      style: const TextStyle(color: AppColors.statusDanger)),
                ),
              )
            else if (_events.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.search_off,
                            size: 40, color: AppColors.textMuted),
                        SizedBox(height: 12),
                        Text(
                          'No events found',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Try a different search or check back later.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ..._events.map(
                      (e) => EventCard(
                    event: e,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => EventDetailsScreen(eventId: e.id),
                      ),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}