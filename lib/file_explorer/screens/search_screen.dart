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
    const bgColor = Color(0xFF090C14);
    const cardColor = Color(0xFF111827);
    const accentBlue = Color(0xFF80A3FF);
    const subtitleColor = Color(0xFF6B7280);
    const borderColor = Color(0xFF1F2937);

    final showRecent =
        !_hasSearched && _controller.text.isEmpty && _recentSearches.isNotEmpty;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: TextField(
          controller: _controller,
          focusNode: _focusNode,
          onChanged: (_) => _liveSearch(),
          onSubmitted: (_) => _commitSearch(),
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: InputDecoration(
            hintText: 'Search in ClassHub',
            hintStyle: const TextStyle(color: subtitleColor, fontSize: 15),
            border: InputBorder.none,
            suffixIcon: _controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: subtitleColor,
                      size: 20,
                    ),
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
          ? _buildRecentSearches(subtitleColor, accentBlue)
          : _hasSearched
          ? _buildResults(
              bgColor,
              cardColor,
              accentBlue,
              subtitleColor,
              borderColor,
            )
          : _buildEmptyPrompt(subtitleColor),
    );
  }

  Widget _buildEmptyPrompt(Color subtitleColor) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search,
            color: subtitleColor.withValues(alpha: 0.3),
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            'Search for files and folders',
            style: TextStyle(color: subtitleColor, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentSearches(Color subtitleColor, Color accentBlue) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
          child: Row(
            children: [
              Text(
                'Recent searches',
                style: TextStyle(
                  color: subtitleColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
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
                  style: TextStyle(
                    color: accentBlue,
                    fontSize: 12,
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
            leading: Icon(Icons.history, color: subtitleColor, size: 20),
            title: Text(
              query,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
            trailing: IconButton(
              icon: Icon(Icons.close, color: subtitleColor, size: 18),
              onPressed: () => _removeRecent(query),
            ),
            onTap: () => _onRecentTap(query),
          ),
        ),
      ],
    );
  }

  Widget _buildResults(
    Color bgColor,
    Color cardColor,
    Color accentBlue,
    Color subtitleColor,
    Color borderColor,
  ) {
    if (_results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off,
              color: subtitleColor.withValues(alpha: 0.4),
              size: 64,
            ),
            const SizedBox(height: 16),
            const Text(
              'No results found',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
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
        // Show relative path from root
        final relativePath = p.relative(entity.path, from: widget.rootPath);
        final parentPath = p.dirname(relativePath);

        return GestureDetector(
          onTap: () => Navigator.pop(context, entity.path),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor, width: 1),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: accentBlue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(info.icon, color: accentBlue, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        parentPath != '.'
                            ? '$subtitle  •  $parentPath'
                            : subtitle,
                        style: TextStyle(color: subtitleColor, fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
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
    const accentBlue = Color(0xFF80A3FF);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? accentBlue.withValues(alpha: 0.15)
              : const Color(0xFF111827),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? accentBlue.withValues(alpha: 0.5)
                : const Color(0xFF1F2937),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 16,
                color: selected ? accentBlue : const Color(0xFF6B7280),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: selected ? accentBlue : const Color(0xFF6B7280),
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
