import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../pagination.dart';
import '../store.dart';
import '../themes.dart';

class ReaderPage extends StatefulWidget {
  final Book book;
  const ReaderPage({super.key, required this.book});

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> {
  final _store = Store.instance;
  final _controller = PageController();
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  String _text = '';
  List<Chapter> _chapters = const [];
  int _chapterIndex = 0;
  int _offset = 0; // 当前章节内字符偏移
  List<PageSlice> _pages = const [PageSlice(0, 0)];
  int _contentStartInChapter = 0;
  int _currentPage = 0;
  String _cacheKey = '';
  int? _pendingJump;
  bool _menuVisible = false;
  bool _loading = true;
  String? _error;

  /// 章节分页缓存键前缀（含书名，跨实例复用）
  String _pageKey(int chapter, double w, double h) =>
      '${widget.book.id}|$chapter|$w|$h|${_store.fontSize}';

  String? _prefetchKey;
  ChapterPaginator? _prefetcher;
  bool _prefetchRunning = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final text = await _store.loadText(widget.book);
      final chapters = _store.chaptersFor(widget.book, text);
      _text = text;
      _chapters = chapters;
      _chapterIndex = widget.book.chapterIndex.clamp(0, chapters.length - 1);
      _offset = widget.book.charOffset;
      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _loading = false;
        _error = '打开失败：$e';
      });
    }
  }

  Chapter get _chapter => _chapters[_chapterIndex];
  ReaderTheme get _theme => readerThemes[_store.themeIndex];

  /// 取出某章的正文（剥掉与页眉重复的首行标题），返回 [正文, 章内起始偏移]
  (String, int) _chapterContent(int index) {
    final ch = _chapters[index];
    var content = _text.substring(ch.start, ch.end);
    var contentStart = 0;
    final nl = content.indexOf('\n');
    if (nl > 0 && content.substring(0, nl).trim() == ch.title.trim()) {
      content = content.substring(nl + 1);
      contentStart = nl + 1;
    }
    return (content, contentStart);
  }

  /// 尺寸/字号/章节变化时重新分页，并定位到 _offset 所在页
  void _ensurePages(double w, double h) {
    final key = '$_chapterIndex|$w|$h|${_store.fontSize}';
    if (key == _cacheKey) return;
    _cacheKey = key;
    final (content, contentStart) = _chapterContent(_chapterIndex);
    _contentStartInChapter = contentStart;
    final cached = PageCache.get(_pageKey(_chapterIndex, w, h));
    if (cached != null) {
      _pages = cached;
    } else {
      _pages = paginateChapter(content,
          width: w, height: h, fontSize: _store.fontSize);
      PageCache.put(_pageKey(_chapterIndex, w, h), _pages);
    }
    final rel = _offset - contentStart;
    var idx = rel <= 0 ? 0 : _pages.indexWhere((p) => rel < p.end);
    if (idx < 0) idx = _pages.length - 1;
    _pendingJump = idx;
    _currentPage = idx;
    _schedulePrefetch(w, h);
  }

  /// 分帧预热下一章：每次只算 2 页，避免可感知的卡顿
  void _schedulePrefetch(double w, double h) {
    final next = _chapterIndex + 1;
    if (next >= _chapters.length) return;
    final key = _pageKey(next, w, h);
    if (PageCache.get(key) != null) return;
    if (_prefetchRunning && _prefetchKey == key) return;
    final (content, _) = _chapterContent(next);
    _prefetchKey = key;
    _prefetcher = ChapterPaginator(content,
        width: w, height: h, fontSize: _store.fontSize);
    if (_prefetchRunning) return;
    _prefetchRunning = true;
    _runPrefetchStep();
  }

  void _runPrefetchStep() {
    if (!mounted) {
      _prefetchRunning = false;
      return;
    }
    final p = _prefetcher;
    if (p == null) {
      _prefetchRunning = false;
      return;
    }
    p.advance(2);
    if (p.done) {
      final key = _prefetchKey;
      if (key != null) PageCache.put(key, List.of(p.pages));
      _prefetcher = null;
      _prefetchKey = null;
      _prefetchRunning = false;
      return;
    }
    // 借渲染帧的空隙继续算
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _runPrefetchStep();
      WidgetsBinding.instance.scheduleFrame();
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  void _scheduleJump() {
    final target = _pendingJump;
    if (target == null) return;
    _pendingJump = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_controller.hasClients) {
        _controller.jumpToPage(target);
      } else {
        _pendingJump = target; // 下一帧再试
      }
    });
  }

  void _onPageChanged(int idx) {
    setState(() {
      _currentPage = idx;
      _menuVisible = false;
    });
    final ch = _chapter;
    if (idx < _pages.length) {
      _offset = _contentStartInChapter + _pages[idx].start;
    } else {
      _offset = ch.end - ch.start; // 章末卡片
    }
    _saveProgress();
  }

  void _saveProgress() {
    _store.saveProgress(
      widget.book,
      chapterIndex: _chapterIndex,
      charOffset: _offset,
      absOffset: _chapter.start + _offset,
      chapterTitle: _chapter.title,
    );
  }

  void _nextChapter() {
    if (_chapterIndex >= _chapters.length - 1) {
      _toast('已经是最后一章了');
      return;
    }
    setState(() {
      _chapterIndex++;
      _offset = 0;
      _cacheKey = '';
    });
    _saveProgress();
  }

  void _prevChapter() {
    if (_chapterIndex <= 0) {
      _toast('已经是第一章了');
      return;
    }
    setState(() {
      _chapterIndex--;
      _offset = _chapters[_chapterIndex].end - _chapters[_chapterIndex].start;
      _cacheKey = '';
    });
    _saveProgress();
  }

  void _jumpToChapter(int i) {
    setState(() {
      _chapterIndex = i;
      _offset = 0;
      _cacheKey = '';
    });
    _saveProgress();
  }

  void _nextPage() {
    if (_currentPage >= _pages.length - 1) {
      _nextChapter();
    } else {
      _controller.nextPage(
          duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    }
  }

  void _prevPage() {
    if (_currentPage <= 0) {
      _prevChapter();
    } else {
      _controller.previousPage(
          duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    }
  }

  void _onTapUp(TapUpDetails d, double width) {
    final x = d.localPosition.dx;
    if (x < width / 3) {
      _prevPage();
    } else if (x > width * 2 / 3) {
      _nextPage();
    } else {
      setState(() => _menuVisible = !_menuVisible);
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 1)));
  }

  void _changeFontSize(double delta) {
    final v = (_store.fontSize + delta).clamp(12.0, 32.0);
    if (v == _store.fontSize) return;
    _store.setFontSize(v);
    setState(() {}); // _ensurePages 会按新字号重排并保住当前位置
  }

  void _changeTheme(int i) {
    _store.setThemeIndex(i);
    setState(() {});
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = _theme;
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: theme.bg,
      endDrawer: _buildChapterDrawer(theme),
      body: MediaQuery.withNoTextScaling(
        child: AnnotatedRegion(
        value: theme.brightness == Brightness.dark
            ? const SystemUiOverlayStyle(
                statusBarBrightness: Brightness.dark,
                statusBarIconBrightness: Brightness.light)
            : const SystemUiOverlayStyle(
                statusBarBrightness: Brightness.light,
                statusBarIconBrightness: Brightness.dark),
        child: SafeArea(
          child: _loading
              ? Center(child: CircularProgressIndicator(color: theme.sub))
              : _error != null
                  ? Center(
                      child: Text(_error!, style: TextStyle(color: theme.fg)))
                  : LayoutBuilder(builder: (context, c) {
                      const hPad = 20.0;
                      const headerH = 26.0;
                      const footerH = 26.0;
                      final contentW = c.maxWidth - hPad * 2;
                      // 预留 2px 安全余量，避免浮点舍入导致末行被裁
                      final contentH = c.maxHeight - headerH - footerH - 2;
                      _ensurePages(contentW, contentH);
                      _scheduleJump();
                      return Stack(
                        children: [
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTapUp: (d) => _onTapUp(d, c.maxWidth),
                            child: PageView.builder(
                              controller: _controller,
                              itemCount: _pages.length + 1,
                              onPageChanged: _onPageChanged,
                              itemBuilder: (context, idx) {
                                if (idx >= _pages.length) {
                                  return _buildEndCard(theme);
                                }
                                final p = _pages[idx];
                                return Padding(
                                  padding: const EdgeInsets.only(
                                      left: hPad,
                                      right: hPad,
                                      top: headerH,
                                      bottom: footerH),
                                  child: Align(
                                    alignment: Alignment.topLeft,
                                    child: Text(
                                      _text.substring(
                                          _chapter.start +
                                              _contentStartInChapter +
                                              p.start,
                                          _chapter.start +
                                              _contentStartInChapter +
                                              p.end),
                                      style: TextStyle(
                                        fontSize: _store.fontSize,
                                        height: 1.8,
                                        color: theme.fg,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          // 页眉：章节名
                          Positioned(
                            top: 4,
                            left: hPad,
                            right: hPad,
                            child: Text(
                              _chapter.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, color: theme.sub),
                            ),
                          ),
                          // 页脚：页码 + 全书进度
                          Positioned(
                            bottom: 4,
                            left: hPad,
                            right: hPad,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${(_currentPage + 1).clamp(1, _pages.length)}/${_pages.length}',
                                  style:
                                      TextStyle(fontSize: 12, color: theme.sub),
                                ),
                                Text(
                                  '${(_bookProgress * 100).toStringAsFixed(1)}%',
                                  style:
                                      TextStyle(fontSize: 12, color: theme.sub),
                                ),
                              ],
                            ),
                          ),
                          if (_menuVisible) _buildTopBar(theme),
                          if (_menuVisible) _buildBottomPanel(theme),
                        ],
                      );
                    }),
        ),
      ),
      ),
    );
  }

  double get _bookProgress {
    if (_text.isEmpty) return 0;
    return ((_chapter.start + _offset) / _text.length).clamp(0.0, 1.0);
  }

  Widget _buildEndCard(ReaderTheme theme) {
    final isLast = _chapterIndex >= _chapters.length - 1;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('本章完', style: TextStyle(fontSize: 16, color: theme.sub)),
          const SizedBox(height: 20),
          if (!isLast)
            OutlinedButton(
              onPressed: _nextChapter,
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.fg,
                side: BorderSide(color: theme.sub),
              ),
              child: Text(
                '下一章：${_chapters[_chapterIndex + 1].title}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            )
          else
            Text('全书完', style: TextStyle(fontSize: 14, color: theme.sub)),
        ],
      ),
    );
  }

  Widget _buildTopBar(ReaderTheme theme) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Material(
        color: theme.panel,
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: 48,
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back, color: theme.fg),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: Text(
                    widget.book.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 16, color: theme.fg),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.toc, color: theme.fg),
                  tooltip: '目录',
                  onPressed: () =>
                      _scaffoldKey.currentState?.openEndDrawer(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomPanel(ReaderTheme theme) {
    final maxPage = _pages.length - 1;
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Material(
        color: theme.panel,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    TextButton(
                      onPressed: _prevChapter,
                      child: Text('上一章',
                          style: TextStyle(color: theme.fg, fontSize: 13)),
                    ),
                    Expanded(
                      child: Slider(
                        value: _currentPage.clamp(0, maxPage).toDouble(),
                        min: 0,
                        max: maxPage < 1 ? 1 : maxPage.toDouble(),
                        divisions: maxPage < 1 ? null : maxPage,
                        activeColor: theme.fg,
                        inactiveColor: theme.sub.withValues(alpha: 0.4),
                        onChanged: maxPage < 1
                            ? null
                            : (v) => _controller.jumpToPage(v.round()),
                      ),
                    ),
                    TextButton(
                      onPressed: _nextChapter,
                      child: Text('下一章',
                          style: TextStyle(color: theme.fg, fontSize: 13)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.remove_circle_outline,
                          color: theme.fg, size: 22),
                      tooltip: '减小字号',
                      onPressed: () => _changeFontSize(-2),
                    ),
                    Text('${_store.fontSize.round()}',
                        style: TextStyle(color: theme.fg, fontSize: 14)),
                    IconButton(
                      icon: Icon(Icons.add_circle_outline,
                          color: theme.fg, size: 22),
                      tooltip: '增大字号',
                      onPressed: () => _changeFontSize(2),
                    ),
                    const Spacer(),
                    for (var i = 0; i < readerThemes.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(left: 10),
                        child: GestureDetector(
                          onTap: () => _changeTheme(i),
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: readerThemes[i].bg,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: i == _store.themeIndex
                                    ? theme.fg
                                    : theme.sub,
                                width: i == _store.themeIndex ? 2 : 1,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChapterDrawer(ReaderTheme theme) {
    return Drawer(
      backgroundColor: theme.panel,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('目录 · ${_chapters.length} 章',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: theme.fg)),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _chapters.length,
                itemBuilder: (context, i) {
                  final selected = i == _chapterIndex;
                  return ListTile(
                    dense: true,
                    title: Text(
                      _chapters[i].title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        color: selected ? theme.fg : theme.sub,
                        fontWeight:
                            selected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    onTap: () {
                      Navigator.of(context).pop();
                      _jumpToChapter(i);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}