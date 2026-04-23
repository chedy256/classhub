import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../models/file_type_info.dart';
import '../services/file_explorer_service.dart';
import '../services/search_service.dart';

class SearchScreen extends StatefulWidget {
  final String rootPath;

  const SearchScreen({super.key, required this.rootPath});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final SearchService _searchService = SearchService();
  final FileExplorerService _fileExplorerService = FileExplorerService();

  SearchFilter _filter = SearchFilter.all;
  List<String> _recentSearches = [];
  List<FileSystemEntity> _results = [];
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    _recentSearches = _searchService.loadRecentSearches(widget.rootPath);
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _liveSearch() {
    final query = _controller.text.trim();
    if (query.isEmpty) {
      setState(() {
        _results = [];
        _hasSearched = false;
      });
      return;
    }
    setState(() {
      _results = _searchService.search(widget.rootPath, query, _filter);
      _hasSearched = true;
    });
  }

  void _commitSearch() {
    final query = _controller.text.trim();
    if (query.isEmpty) return;
    _searchService.addRecentSearch(widget.rootPath, query);
    setState(() {
      _recentSearches = _searchService.loadRecentSearches(widget.rootPath);
    });
  }

  void _onFilterChanged(SearchFilter filter) {
    setState(() => _filter = filter);
    _liveSearch();
  }

  void _onRecentTap(String query) {
    _controller.text = query;
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: query.length),
    );
    _liveSearch();
    _commitSearch();
  }

  void _removeRecent(String query) {
    _searchService.removeRecentSearch(widget.rootPath, query);
    setState(() {
      _recentSearches = _searchService.loadRecentSearches(widget.rootPath);
    });
  }

  @override
  Widget build(BuildContext context) {
    final showRecent =
        !_hasSearched && _controller.text.isEmpty && _recentSearches.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          focusNode: _focusNode,
          onChanged: (_) => _liveSearch(),
          onSubmitted: (_) => _commitSearch(),
          decoration: InputDecoration(
            hintText: 'Search in ClassHub',
            border: InputBorder.none,
            suffixIcon: _controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      _controller.clear();
                      setState(() {
                        _results = [];
                        _hasSearched = false;
                      });
                      _focusNode.requestFocus();
                    },
                  )
                : null,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                _FilterChip(
                  label: 'All',
                  selected: _filter == SearchFilter.all,
                  onTap: () => _onFilterChanged(SearchFilter.all),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Folders',
                  icon: Icons.folder_outlined,
                  selected: _filter == SearchFilter.folders,
                  onTap: () => _onFilterChanged(SearchFilter.folders),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Files',
                  icon: Icons.description_outlined,
                  selected: _filter == SearchFilter.files,
                  onTap: () => _onFilterChanged(SearchFilter.files),
                ),
              ],
            ),
          ),
        ),
      ),
      body: showRecent
          ? _buildRecentSearches()
          : _hasSearched
              ? _buildResults()
              : _buildEmptyPrompt(),
    );
  }

  Widget _buildEmptyPrompt() {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search,
            color: theme.colorScheme.onSurfaceVariant,
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            'Search for files and folders',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentSearches() {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
          child: Row(
            children: [
              Text(
                'Recent searches',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  _searchService.clearRecentSearches(widget.rootPath);
                  setState(() => _recentSearches = []);
                },
                child: Text(
                  'Clear all',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        ..._recentSearches.map(
          (query) => ListTile(
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            leading: Icon(Icons.history),
            title: Text(query),
            trailing: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => _removeRecent(query),
            ),
            onTap: () => _onRecentTap(query),
          ),
        ),
      ],
    );
  }

  Widget _buildResults() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off,
              color: colorScheme.onSurfaceVariant,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              'No results found',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      itemCount: _results.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final entity = _results[index];
        final isDir = entity is Directory;
        final name = p.basename(entity.path);
        final info = FileTypeInfo.classify(name, isDirectory: isDir);
        final subtitle = _fileExplorerService.entitySubtitle(entity);
        final relativePath = p.relative(entity.path, from: widget.rootPath);
        final parentPath = p.dirname(relativePath);

        return Card(
          child: InkWell(
            onTap: () => Navigator.pop(context, entity.path),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(info.icon, color: colorScheme.onPrimaryContainer),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          parentPath != '.'
                              ? '$subtitle · $parentPath'
                              : subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 16,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: selected
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onSurfaceVariant,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}