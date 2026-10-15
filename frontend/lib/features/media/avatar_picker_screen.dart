import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:insta_assets_crop/insta_assets_crop.dart';
import 'package:onetouch/core/app_action_button.dart';
import 'package:onetouch/core/app_close_header.dart';
import 'package:onetouch/core/app_dropdown.dart';
import 'package:onetouch/core/app_snack_bar.dart';
import 'package:onetouch/core/app_system_ui.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet.dart';
import 'package:onetouch/features/media/avatar_crop_editor.dart';
import 'package:onetouch/features/media/avatar_photo_library.dart';
import 'package:onetouch/features/media/native_avatar_header.dart';
import 'package:onetouch/l10n/app_localizations.dart';
import 'package:photo_manager/photo_manager.dart';

class AvatarPickerScreen extends StatefulWidget {
  const AvatarPickerScreen(
      {super.key, this.library = const AvatarPhotoLibrary()});

  final AvatarPhotoLibrary library;

  @override
  State<AvatarPickerScreen> createState() => _AvatarPickerScreenState();
}

class _AvatarPickerScreenState extends State<AvatarPickerScreen>
    with WidgetsBindingObserver {
  final _cropKey = GlobalKey<CropState>();
  final _scroll = ScrollController();
  List<AssetPathEntity> _albums = [];
  List<AssetEntity> _photos = [];
  AssetPathEntity? _album;
  PermissionState? _access;
  File? _file;
  ImageProvider? _preview;
  Size? _imageSize;
  AssetEntity? _selectedPhoto;
  int _selection = 0;
  int _albumGeneration = 0;
  int _page = 0;
  bool _loading = true;
  bool _loadingPage = false;
  bool _loadingPhoto = false;
  bool _hasMore = false;
  bool _failed = false;
  bool _pageFailed = false;
  bool _saving = false;
  bool _refreshOnResume = false;
  double _albumLeft = 16;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadLibrary(request: true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _refreshOnResume) {
      _refreshOnResume = false;
      _loadLibrary();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadLibrary({bool request = false}) async {
    final generation = ++_albumGeneration;
    ++_selection;
    setState(() {
      _loading = true;
      _failed = false;
      _file = null;
      _preview = null;
      _imageSize = null;
      _selectedPhoto = null;
      _loadingPhoto = false;
    });
    try {
      final access = await (request
          ? widget.library.requestAccess()
          : widget.library.access());
      final albums = access.hasAccess
          ? await widget.library.albums()
          : <AssetPathEntity>[];
      if (!mounted || generation != _albumGeneration) return;
      setState(() {
        _access = access;
        _albums = albums;
        _album = albums.where((album) => album.isAll).firstOrNull ??
            albums.firstOrNull;
        _photos = [];
        _loading = false;
      });
      if (_album != null) await _openAlbum(_album!);
    } on Object {
      if (!mounted || generation != _albumGeneration) return;
      setState(() {
        _failed = true;
        _loading = false;
      });
    }
  }

  Future<void> _openAlbum(AssetPathEntity album) async {
    final generation = ++_albumGeneration;
    setState(() {
      _album = album;
      _photos = [];
      _page = 0;
      _loadingPage = false;
      _pageFailed = false;
      _hasMore = true;
    });
    await _nextPage();
    if (!mounted || generation != _albumGeneration) return;
    if (_preview == null && !_loadingPhoto && _photos.isNotEmpty) {
      _selectPhoto(_photos.first);
    }
  }

  Future<void> _nextPage() async {
    if (_loadingPage || !_hasMore || _album == null) return;
    final generation = _albumGeneration;
    setState(() {
      _loadingPage = true;
      _pageFailed = false;
    });
    try {
      final photos = await widget.library.photos(_album!, _page);
      if (!mounted || generation != _albumGeneration) return;
      setState(() {
        _photos.addAll(photos);
        _page++;
        _hasMore = photos.length == AvatarPhotoLibrary.pageSize;
        _loadingPage = false;
      });
    } on Object {
      if (!mounted || generation != _albumGeneration) return;
      setState(() {
        _loadingPage = false;
        _pageFailed = true;
      });
    }
  }

  Future<void> _selectPhoto(AssetEntity photo, {Uint8List? thumbnail}) async {
    if (_saving) return;
    if (_selectedPhoto?.id == photo.id) {
      _expandCrop();
      return;
    }
    final selection = _beginSelection(
      photo: photo,
      preview: thumbnail == null ? null : MemoryImage(thumbnail),
      // 미리보기 해상도가 바뀌어도 크롭이 초기화되지 않도록 좌표 기준을 고정해요.
      size: photo.orientatedSize,
    );
    try {
      if (thumbnail == null) {
        final bytes = await widget.library.thumbnail(photo);
        if (!mounted || selection != _selection) return;
        if (bytes == null) throw const FileSystemException('Photo unavailable');
        setState(() {
          _preview = MemoryImage(bytes);
          _loadingPhoto = false;
        });
      }
      // 목록의 디코딩된 이미지를 먼저 보여주고, 크롭 위치를 유지한 채 화질만 높여요.
      final bytes = await widget.library.thumbnail(photo, size: 1600);
      if (!mounted || selection != _selection) return;
      if (bytes == null) throw const FileSystemException('Photo unavailable');
      final preview = MemoryImage(bytes);
      Object? decodeError;
      await precacheImage(preview, context,
          onError: (error, stackTrace) => decodeError = error);
      if (!mounted || selection != _selection) return;
      if (decodeError != null) throw decodeError!;
      setState(() => _preview = preview);
    } on Object {
      _photoFailed(selection);
    }
  }

  int _beginSelection(
      {AssetEntity? photo, ImageProvider? preview, Size? size}) {
    final selection = ++_selection;
    setState(() {
      _loadingPhoto = preview == null;
      _selectedPhoto = photo;
      _file = null;
      _preview = preview;
      _imageSize = size;
    });
    _expandCrop();
    return selection;
  }

  Future<void> _selectFile(File file) async {
    final selection = _beginSelection();
    try {
      // 미리보기는 작게 디코딩하고, 내보낼 때는 원본의 같은 비율 영역을 잘라요.
      final codec = await ui.instantiateImageCodec(await file.readAsBytes(),
          targetWidth: 1600, allowUpscaling: false);
      late final Size size;
      try {
        final frame = await codec.getNextFrame();
        size =
            Size(frame.image.width.toDouble(), frame.image.height.toDouble());
        frame.image.dispose();
      } finally {
        codec.dispose();
      }
      if (!mounted || selection != _selection) return;
      setState(() {
        _file = file;
        _preview =
            ResizeImage(FileImage(file), width: 1600, allowUpscaling: false);
        _imageSize = size;
        _loadingPhoto = false;
      });
    } on Object {
      _photoFailed(selection);
    }
  }

  void _photoFailed(int selection) {
    // 늦게 도착한 이전 선택의 결과나 오류가 현재 사진을 바꾸지 않게 해요.
    if (!mounted || selection != _selection) return;
    setState(() {
      _loadingPhoto = false;
      if (_preview == null) _selectedPhoto = null;
    });
    _showError();
  }

  Future<void> _camera() async {
    try {
      final file = await widget.library.takePhoto();
      if (!mounted || file == null) return;
      await _selectFile(file);
    } on Object {
      if (mounted) _showError();
    }
  }

  void _expandCrop() {
    if (_scroll.hasClients) {
      _scroll.animateTo(0,
          duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
    }
  }

  Future<void> _save() async {
    final area = _cropKey.currentState?.area;
    if (_saving || _loadingPhoto || _preview == null || area == null) return;
    setState(() => _saving = true);
    try {
      // 전체 크기 파일 변환은 확정할 때만 기다리고, 선택 중에는 미리보기를 사용해요.
      final file = _file ?? await widget.library.file(_selectedPhoto!);
      if (!mounted) return;
      if (file == null) throw const FileSystemException('Photo unavailable');
      final result = await exportAvatarCrop(file, area);
      if (mounted) Navigator.of(context).pop(result);
    } on Object {
      if (!mounted) return;
      setState(() => _saving = false);
      _showError();
    }
  }

  void _showError() => showAppSnackBar(context,
      tr(context, 'Unable to update profile photo. Please try again.'));

  Future<void> _manageAccess() async {
    try {
      await widget.library.manageAccess();
      if (mounted) await _loadLibrary();
    } on Object {
      if (mounted) _showError();
    }
  }

  String _albumName(AssetPathEntity album) =>
      album.isAll ? tr(context, 'Recent photos') : album.name;

  Future<void> _showAlbums() async {
    final selected = await showModalBottomSheet<AssetPathEntity>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: .65,
        minChildSize: .4,
        maxChildSize: .92,
        expand: false,
        builder: (context, controller) => Material(
          color: AppColors.of(context).cardBackground,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: SafeArea(
              top: false,
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                  child: AppCloseHeader(
                      title: tr(context, 'Photo albums'),
                      onClose: () => Navigator.pop(context)),
                ),
                Expanded(
                    child: ListView.builder(
                  controller: controller,
                  itemCount: _albums.length,
                  itemBuilder: (context, index) {
                    final album = _albums[index];
                    return ListTile(
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 24),
                      leading:
                          const Icon(Icons.photo_library_outlined, size: 24),
                      title: Text(_albumName(album), style: Body1.style),
                      trailing: album.id == _album?.id
                          ? const Icon(Icons.check, size: 24)
                          : null,
                      onTap: () => Navigator.pop(context, album),
                    );
                  },
                )),
              ])),
        ),
      ),
    );
    if (mounted && selected != null) await _openAlbum(selected);
  }

  Widget _albumBar() {
    final shortcuts = _albums.where((album) =>
        album.isAll ||
        album.albumTypeEx?.darwin?.subtype ==
            PMDarwinAssetCollectionSubtype.smartAlbumFavorites);
    return ColoredBox(
      color: AppColors.of(context).pageBackground,
      child: Column(children: [
        SizedBox(
            height: 56,
            child: Padding(
              padding: EdgeInsets.fromLTRB(_albumLeft, 8, 16, 8),
              child: Row(children: [
                Expanded(
                    child: Align(
                  alignment: Alignment.centerLeft,
                  child: AppDropdown<String>(
                    triggerKey: const ValueKey('avatar-album-menu'),
                    value: _album?.id,
                    selectedLabel: _album == null
                        ? tr(context, 'Recent photos')
                        : _albumName(_album!),
                    maxMenuHeight: 280,
                    options: [
                      for (final album in shortcuts)
                        AppDropdownOption(
                            value: album.id, label: _albumName(album)),
                      AppDropdownOption(
                          value: '__albums',
                          label: tr(context, 'All albums'),
                          dividerBefore: true),
                    ],
                    onChanged: (id) {
                      if (id == '__albums') {
                        _showAlbums();
                      } else {
                        _openAlbum(
                            _albums.firstWhere((album) => album.id == id));
                      }
                    },
                  ),
                )),
              ]),
            )),
        if (_access == PermissionState.limited)
          SizedBox(
              height: 48,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(children: [
                  Expanded(
                      child: Text(
                          tr(context, 'Only selected photos are visible.'),
                          style: Body2.style,
                          maxLines: 2)),
                  TextButton(
                      onPressed: _manageAccess,
                      child: Text(tr(context, 'Manage photos'),
                          style: Body2_b.style)),
                ]),
              )),
      ]),
    );
  }

  Widget _notice(String message, {String? action, VoidCallback? onAction}) =>
      Center(
          child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(tr(context, message),
              style: Body1.style, textAlign: TextAlign.center),
          if (action != null) ...[
            const SizedBox(height: 16),
            AppActionButton(label: tr(context, action), onPressed: onAction),
          ],
        ]),
      ));

  @override
  Widget build(BuildContext context) => AppSystemUi(
        child: PopScope(
          canPop: !_saving,
          child: Scaffold(
            backgroundColor: AppColors.of(context).pageBackground,
            body: SafeArea(
                // 사진 목록은 홈 표시줄 뒤까지 이어지고, 상단 버튼은 안전영역을 지켜요.
                bottom: false,
                child: Column(children: [
              NativeAvatarHeader(
                onCancel: _saving ? null : () => Navigator.of(context).pop(),
                onDone:
                    _saving || _loadingPhoto || _preview == null ? null : _save,
                saving: _saving,
                onCloseIconLeftMeasured: (left) {
                  // Android가 측정한 X 그림의 왼쪽 끝을 앨범 버튼도 함께 써요.
                  if (_albumLeft != left) setState(() => _albumLeft = left);
                },
              ),
              Expanded(
                  child: AbsorbPointer(absorbing: _saving, child: _body())),
            ])),
          ),
        ),
      );

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_failed) {
      return _notice('Unable to load photos.',
          action: 'Retry', onAction: _loadLibrary);
    }
    if (_access?.hasAccess != true) {
      return _notice('Allow photo access to choose a profile photo.',
          action: 'Open settings', onAction: () async {
        _refreshOnResume = true;
        await widget.library.openSettings();
      });
    }
    return LayoutBuilder(builder: (context, constraints) {
      final side = math.min(constraints.maxWidth, constraints.maxHeight * .58);
      final crop = SizedBox.square(
        key: const ValueKey('avatar-crop-region'),
        dimension: side,
        child: _loadingPhoto
            ? const Center(child: CircularProgressIndicator())
            : _preview != null && _imageSize != null
                ? AvatarCropEditor(
                    key: ValueKey(_selection),
                    cropKey: _cropKey,
                    imageSize: _imageSize!,
                    image: Image(
                        key: ValueKey(_selection),
                        image: _preview!,
                        fit: BoxFit.fill,
                        gaplessPlayback: true),
                  )
                : _notice('Choose from Photos'),
      );
      return Stack(clipBehavior: Clip.hardEdge, children: [
        NestedScrollView(
          controller: _scroll,
          headerSliverBuilder: (context, innerScrolled) => [
            SliverToBoxAdapter(child: SizedBox(height: side)),
            SliverPersistentHeader(
              pinned: true,
              delegate: _AlbumHeader(
                  height: _access == PermissionState.limited ? 104 : 56,
                  child: _albumBar()),
            ),
          ],
          body: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification.metrics.extentAfter < 500 && !_pageFailed) {
                _nextPage();
              }
              return false;
            },
            child: CustomScrollView(
              key: PageStorageKey('avatar-grid-${_album?.id}'),
              slivers: [
                SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      mainAxisSpacing: 2,
                      crossAxisSpacing: 2),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    if (index == 0) {
                      return Material(
                        color: AppColors.of(context).subtleBackground,
                        child: InkWell(
                            onTap: _camera,
                            child: Semantics(
                                label: tr(context, 'Take photo'),
                                button: true,
                                child: const Icon(Icons.camera_alt_outlined,
                                    size: 28))),
                      );
                    }
                    final photo = _photos[index - 1];
                    return _PhotoTile(
                      key: ValueKey(photo.id),
                      photo: photo,
                      library: widget.library,
                      selected: photo.id == _selectedPhoto?.id,
                      onTap: (thumbnail) =>
                          _selectPhoto(photo, thumbnail: thumbnail),
                    );
                  }, childCount: _photos.length + 1),
                ),
                if (_loadingPage)
                  const SliverToBoxAdapter(
                      child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  )),
                if (_pageFailed)
                  SliverToBoxAdapter(
                      child: _notice('Unable to load photos.',
                          action: 'Retry', onAction: _nextPage)),
                if (!_loadingPage && !_pageFailed && _photos.isEmpty)
                  SliverToBoxAdapter(
                      child: _notice('No photos in this album.')),
              ],
            ),
          ),
        ),
        // 크롭을 스크롤 제스처 밖에 두어 사진 이동이 목록 스크롤로 처리되지 않게 해요.
        AnimatedBuilder(
          animation: _scroll,
          child: crop,
          builder: (context, child) => Positioned(
            top: -(_scroll.hasClients ? _scroll.offset : 0.0),
            left: (constraints.maxWidth - side) / 2,
            width: side,
            height: side,
            child: child!,
          ),
        ),
      ]);
    });
  }
}

class _AlbumHeader extends SliverPersistentHeaderDelegate {
  _AlbumHeader({required this.height, required this.child});
  final double height;
  final Widget child;
  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;
  @override
  Widget build(
          BuildContext context, double shrinkOffset, bool overlapsContent) =>
      child;
  @override
  bool shouldRebuild(_AlbumHeader oldDelegate) => true;
}

class _PhotoTile extends StatefulWidget {
  const _PhotoTile(
      {super.key,
      required this.photo,
      required this.library,
      required this.selected,
      required this.onTap});
  final AssetEntity photo;
  final AvatarPhotoLibrary library;
  final bool selected;
  final ValueChanged<Uint8List?> onTap;
  @override
  State<_PhotoTile> createState() => _PhotoTileState();
}

class _PhotoTileState extends State<_PhotoTile> {
  late final Future<Uint8List?> _thumbnail =
      widget.library.thumbnail(widget.photo);

  @override
  Widget build(BuildContext context) => Semantics(
        label: tr(context, 'Photo'),
        selected: widget.selected,
        button: true,
        child: Material(
          color: AppColors.of(context).subtleBackground,
          child: FutureBuilder<Uint8List?>(
              future: _thumbnail,
              builder: (context, snapshot) => InkWell(
                  onTap: () => widget.onTap(snapshot.data),
                  child: Stack(fit: StackFit.expand, children: [
                    snapshot.hasData
                        ? Image.memory(snapshot.data!,
                            fit: BoxFit.cover, gaplessPlayback: true)
                        : const Icon(Icons.image_outlined, size: 24),
                    // 선택 표시는 테마와 관계없이 사진 전체에 흰색 60%를 덮어요.
                    if (widget.selected)
                      const IgnorePointer(
                        child: ColoredBox(
                          key: ValueKey('avatar-selected-overlay'),
                          color: Color(0x99FFFFFF),
                        ),
                      ),
                  ]))),
        ),
      );
}
