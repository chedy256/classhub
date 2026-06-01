import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class PdfController extends ChangeNotifier {
  MethodChannel? _channel;
  int _currentPage = 0;
  int _totalPages = 0;
  bool _isDark = false;

  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  bool get isDark => _isDark;

  // Called once the platform view is created and viewId is known
  void attachChannel(int viewId) {
    _channel = MethodChannel('pdf_viewer/control/$viewId');
    _fetchPageCount();
  }

  Future<void> _fetchPageCount() async {
    final count = await _channel?.invokeMethod<int>('getPageCount') ?? 0;
    _totalPages = count;
    notifyListeners();
  }

  Future<void> setDarkMode(bool dark) async {
    _isDark = dark;
    await _channel?.invokeMethod('setDarkMode', {'isDark': dark});
    notifyListeners();
  }

  Future<void> jumpToPage(int page) async {
    _currentPage = page.clamp(0, _totalPages - 1);
    await _channel?.invokeMethod('jumpToPage', {'page': _currentPage});
    notifyListeners();
  }

  Future<void> syncCurrentPage() async {
    final page = await _channel?.invokeMethod<int>('getCurrentPage') ?? 0;
    _currentPage = page;
    notifyListeners();
  }

  @override
  void dispose() {
    _channel = null;
    super.dispose();
  }
}