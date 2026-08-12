import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class FilterBottomSheet extends StatefulWidget {
  const FilterBottomSheet({super.key});

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
  String _when = 'Anytime';
  String _category = 'All';
  String _location = 'Anywhere';
  String _sortBy = 'Relevance';
  String _status = 'Upcoming';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Filter',
                    style:
                        TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _FilterRow(
              label: 'When',
              value: _when,
              options: const ['Anytime', 'Today', 'This week', 'This month'],
              onChanged: (v) => setState(() => _when = v),
            ),
            _FilterRow(
              label: 'Category',
              value: _category,
              options: const [
                'All',
                'Technology',
                'Business',
                'Music & Arts',
                'Education'
              ],
              onChanged: (v) => setState(() => _category = v),
            ),
            _FilterRow(
              label: 'Location',
              value: _location,
              options: const ['Anywhere', 'Accra', 'Kumasi', 'Virtual'],
              onChanged: (v) => setState(() => _location = v),
            ),
            _FilterRow(
              label: 'Sort by',
              value: _sortBy,
              options: const ['Relevance', 'Date: soonest', 'Price: low to high'],
              onChanged: (v) => setState(() => _sortBy = v),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              children: ['Upcoming', 'Attending', 'Past'].map((status) {
                final selected = status == _status;
                return ChoiceChip(
                  label: Text(status),
                  selected: selected,
                  onSelected: (_) => setState(() => _status = status),
                  selectedColor: AppColors.accentDark.withValues(alpha: 0.3),
                  backgroundColor: AppColors.surfaceElevated,
                  labelStyle: TextStyle(
                    color:
                        selected ? AppColors.accent : AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: selected ? AppColors.accent : AppColors.border,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop({
                'when': _when,
                'category': _category,
                'location': _location,
                'sortBy': _sortBy,
                'status': _status,
              }),
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  const _FilterRow({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          final selected = await showModalBottomSheet<String>(
            context: context,
            backgroundColor: AppColors.surfaceElevated,
            builder: (_) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: options
                    .map((o) => ListTile(
                          title: Text(o),
                          trailing: o == value
                              ? const Icon(Icons.check, color: AppColors.accent)
                              : null,
                          onTap: () => Navigator.of(context).pop(o),
                        ))
                    .toList(),
              ),
            ),
          );
          if (selected != null) onChanged(selected);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
              Row(
                children: [
                  Text(value,
                      style: const TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(width: 4),
                  const Icon(Icons.keyboard_arrow_down,
                      color: AppColors.textSecondary),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
