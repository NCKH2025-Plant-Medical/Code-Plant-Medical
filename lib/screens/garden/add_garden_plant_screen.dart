// lib/screens/garden/add_garden_plant_screen.dart
//
// MÀN HÌNH 2 & 3 — NHẬN DIỆN / TÌM KIẾM / THÊM CÂY VÀO VƯỜN
//
//   mode = recognize → chụp ảnh → POST /predict → chọn trong Top 3
//   mode = search    → GET /api/v1/plants/search?q= → chọn trong danh sách
//
// Sau khi chọn được cây → hiện form "Thêm cây vào vườn":
//   • Ngày gieo (bắt buộc)
//   • Giai đoạn hiện tại (bắt buộc)
//   • Loại đất (gợi ý theo loài + 2 câu hỏi triệu chứng)
//   • Nơi trồng
//   • Vị trí GPS
//   • Ghi chú

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:thunghiem1/controllers/garden_notifier.dart';
import 'package:thunghiem1/core/image_compress.dart';
import 'package:thunghiem1/models/herbal_garden.dart';
import 'package:thunghiem1/screens/garden/garden_constants.dart';
import 'package:thunghiem1/screens/garden/garden_plant_detail_screen.dart';
import 'package:thunghiem1/screens/garden/garden_widgets.dart';
import 'package:thunghiem1/services/herbal_garden_api.dart';
import 'package:thunghiem1/theme/app_colors.dart';

enum AddGardenPlantMode { recognize, search }

/// Cây được chọn (từ nhận diện hoặc tìm kiếm) — dùng để prefill form.
class _SelectedPlant {
  const _SelectedPlant({
    required this.tenLabel,
    required this.tenCay,
    this.tenQuocte,
    this.imageUrl,
  });

  final String tenLabel;
  final String tenCay;
  final String? tenQuocte;
  final String? imageUrl;
}

class AddGardenPlantScreen extends StatefulWidget {
  const AddGardenPlantScreen({
    super.key,
    this.mode = AddGardenPlantMode.search,
    this.initialTenLabel,
    this.initialTenCay,
    this.initialImageUrl,
  });

  final AddGardenPlantMode mode;

  /// Prefill khi đi từ màn hình nhận diện.
  final String? initialTenLabel;
  final String? initialTenCay;
  final String? initialImageUrl;

  @override
  State<AddGardenPlantScreen> createState() => _AddGardenPlantScreenState();
}

class _AddGardenPlantScreenState extends State<AddGardenPlantScreen> {
  final HerbalGardenApi _api = HerbalGardenApi();
  final ImagePicker _picker = ImagePicker();

  // ── Bước 1: chọn cây ──
  bool _recognizing = false;
  bool _searching = false;
  String _query = '';
  List<PlantSearchResult> _searchResults = const [];
  String? _predictMessage;
  bool _predictUncertain = false;
  List<_SelectedPlant> _predictions = const [];

  _SelectedPlant? _selected;

  // ── Bước 2: form ──
  final _formKey = GlobalKey<FormState>();
  DateTime _plantedAt = DateTime.now();
  String _stage = 'gieo_trong';
  final TextEditingController _notesCtrl = TextEditingController();
  final TextEditingController _addressCtrl = TextEditingController();

  double? _latitude;
  double? _longitude;
  bool _locating = false;

  // Loại đất
  SoilOptions? _soilOptions;
  SoilSuggestion? _soilSuggestion;
  String? _soilType;
  String? _plantingMedium;
  String? _doAm;
  String? _mauDat;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _api.dispose();
    _notesCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    // Nạp bộ lựa chọn loại đất (endpoint tĩnh — gọi 1 lần).
    try {
      final opts = await _api.soilOptions();
      if (!mounted) return;
      setState(() => _soilOptions = opts);
    } catch (_) {
      // Không bắt buộc — vẫn thêm cây được, chỉ mất phần gợi ý loại đất.
    }

    if (widget.initialTenLabel != null) {
      _selectPlant(
        _SelectedPlant(
          tenLabel: widget.initialTenLabel!,
          tenCay: widget.initialTenCay ?? widget.initialTenLabel!,
          imageUrl: widget.initialImageUrl,
        ),
      );
    } else if (widget.mode == AddGardenPlantMode.recognize) {
      _pickFromCamera();
    }
  }

  void _selectPlant(_SelectedPlant plant) {
    setState(() {
      _selected = plant;
      _soilType = null;
      _soilSuggestion = null;
    });
    _loadSoilSuggestion(plant.tenLabel);
  }

  Future<void> _loadSoilSuggestion(String tenLabel) async {
    try {
      final s = await _api.soilSuggestion(tenLabel);
      if (!mounted) return;
      setState(() {
        _soilSuggestion = s;
        // Chỉ prefill khi người dùng chưa tự chọn.
        if (_soilType == null && s != null && s.hasSuggestion) {
          _soilType = s.soilType;
        }
      });
    } catch (_) {
      // Ẩn phần gợi ý — server trả null cho 32/371 loài.
    }
  }

  // ── Nhận diện ───────────────────────────────────────────────────────────

  Future<void> _pickFromCamera() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 82,
      );
      if (picked == null) return;
      await _runPredict(picked.path);
    } catch (e) {
      _showMessage('Không mở được camera: $e', isError: true);
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final picked = await _picker.pickImage(source: ImageSource.gallery);
      if (picked == null) return;
      await _runPredict(picked.path);
    } catch (e) {
      _showMessage('Không mở được thư viện ảnh: $e', isError: true);
    }
  }

  Future<void> _runPredict(String imagePath) async {
    setState(() {
      _recognizing = true;
      _predictMessage = null;
      _predictUncertain = false;
    });

    try {
      final compressed = await compressImageForUpload(imagePath);
      final result = await _api.predict(File(compressed));
      if (!mounted) return;

      setState(() {
        _recognizing = false;
        _predictMessage = result.message;
        _predictUncertain = result.status == 'uncertain';
        _predictions = result.predictions
            .map((p) => _SelectedPlant(
                  tenLabel: p.plantId,
                  tenCay: p.commonName,
                  tenQuocte: p.scientificName,
                  imageUrl: p.imageUrl,
                ))
            .toList();
        if (result.status == 'unknown') {
          _predictMessage =
              result.message ?? 'Ảnh không rõ, hãy chụp lại gần hơn / rõ hơn.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _recognizing = false);
      _showMessage(
        e.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    }
  }

  // ── Tìm kiếm ────────────────────────────────────────────────────────────

  Future<void> _search(String q) async {
    if (q.trim().isEmpty) {
      setState(() {
        _searchResults = const [];
        _query = '';
      });
      return;
    }
    setState(() {
      _searching = true;
      _query = q.trim();
    });
    try {
      final results = await _api.searchPlants(q.trim());
      if (!mounted) return;
      setState(() {
        _searchResults = results;
        _searching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _searching = false);
      _showMessage(
        e.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    }
  }

  // ── GPS ─────────────────────────────────────────────────────────────────

  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        _showMessage('GPS đang tắt. Bật GPS để lấy vị trí.', isError: true);
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showMessage('Cần cấp quyền vị trí.', isError: true);
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 12),
        ),
      );
      if (!mounted) return;
      setState(() {
        _latitude = pos.latitude;
        _longitude = pos.longitude;
        if (_addressCtrl.text.trim().isEmpty) {
          _addressCtrl.text =
              'Vị trí ${pos.latitude.toStringAsFixed(4)}, '
              '${pos.longitude.toStringAsFixed(4)}';
        }
      });
    } catch (e) {
      _showMessage('Không lấy được vị trí: $e', isError: true);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  // ── Lưu ─────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    final plant = _selected;
    if (plant == null) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);
    final garden = context.read<GardenNotifier>();

    try {
      final result = await _api.addPlant(
        tenLabel: plant.tenLabel,
        plantedAt: _plantedAt,
        stage: _stage,
        notes: _notesCtrl.text,
        imageUrl: plant.imageUrl,
        latitude: _latitude,
        longitude: _longitude,
        addressName: _addressCtrl.text,
        soilType: _soilType,
        plantingMedium: _plantingMedium,
        doAm: _doAm,
        mauDat: _mauDat,
        uid: garden.uid,
      );

      if (!mounted) return;

      if (result.duplicate) {
        // 409 — đã có cây này trong vườn → dialog + nút "Xem cây đó".
        await _showDuplicateDialog(result);
      } else {
        _showMessage(result.message);
        await garden.refresh();
        if (!mounted) return;
        Navigator.of(context).pop();
        // Điều hướng thẳng tới màn hình chi tiết cây vừa tạo.
        if (result.id != null && result.id!.isNotEmpty) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => GardenPlantDetailScreen(plantId: result.id!),
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      _showMessage(
        e.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _showDuplicateDialog(AddPlantResult result) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.info_outline_rounded, color: Color(0xFFD97706)),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Đã có trong vườn',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
              ),
            ),
          ],
        ),
        content: Text(
          result.message,
          style: const TextStyle(fontSize: 13.5, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Để sau'),
          ),
          if (result.id != null && result.id!.isNotEmpty)
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        GardenPlantDetailScreen(plantId: result.id!),
                  ),
                );
              },
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('Xem cây đó'),
            ),
        ],
      ),
    );
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? const Color(0xFFDC2626) : null,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final plant = _selected;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          plant == null
              ? (widget.mode == AddGardenPlantMode.recognize
                  ? 'Chụp ảnh cây'
                  : 'Tìm trong danh mục')
              : 'Thêm cây vào vườn',
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: plant == null ? _buildPicker() : _buildForm(plant),
    );
  }

  // ── Bước 1: chọn cây ───────────────────────────────────────────────────

  Widget _buildPicker() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.mode == AddGardenPlantMode.recognize) ...[
            _sectionTitle('📷 Chụp ảnh cây'),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFF7FAF8),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFDDE5E1)),
              ),
              child: Column(
                children: [
                  if (_recognizing)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 22),
                      child: CircularProgressIndicator(),
                    )
                  else ...[
                    const Icon(
                      Icons.photo_camera_rounded,
                      size: 42,
                      color: AppColors.primary,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Chụp cận cảnh lá và hoa, ánh sáng đủ, một loại cây trong khung hình.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12.5, height: 1.45),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _pickFromCamera,
                            icon: const Icon(Icons.camera_alt_rounded, size: 18),
                            label: const Text('Chụp ảnh'),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickFromGallery,
                            icon: const Icon(Icons.photo_library_rounded, size: 18),
                            label: const Text('Thư viện'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),
          ],

          // Kết quả nhận diện
          if (_predictMessage != null)
            GardenBanner(
              text: _predictMessage!,
              kind: _predictUncertain ? GardenBannerKind.warning : GardenBannerKind.info,
              icon: Icons.info_outline_rounded,
            ),
          if (_predictUncertain && _predictions.isNotEmpty) ...[
            const SizedBox(height: 10),
            const GardenBanner(
              text: 'Kết quả chỉ là gợi ý, chưa được kiểm chứng. '
                  'Hãy kiểm tra lại tên cây trước khi lưu vào vườn.',
              kind: GardenBannerKind.danger,
            ),
          ],
          if (_predictions.isNotEmpty) ...[
            const SizedBox(height: 16),
            _sectionTitle('🎯 Kết quả nhận diện — chọn đúng tên cây'),
            const SizedBox(height: 10),
            ..._predictions.map(
              (p) => _PlantResultTile(
                title: p.tenCay,
                subtitle: p.tenQuocte,
                imageUrl: p.imageUrl,
                onTap: () => _selectPlant(p),
              ),
            ),
          ],

          const SizedBox(height: 22),
          _sectionTitle('🔍 Tìm trong danh mục'),
          const SizedBox(height: 10),
          TextField(
            onChanged: _search,
            textInputAction: TextInputAction.search,
            onSubmitted: _search,
            decoration: InputDecoration(
              hintText: 'Nhập tên cây (VD: rau má, hạ khô thảo)',
              prefixIcon: const Icon(Icons.search_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          if (_searching)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_searchResults.isEmpty && _query.trim().isNotEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: Text(
                  'Không tìm thấy loài cây nào.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF6C757D)),
                ),
              ),
            )
          else
            ..._searchResults.map(
              (r) => _PlantResultTile(
                title: r.commonName,
                subtitle: r.scientificName,
                imageUrl: r.imageUrl,
                onTap: () => _selectPlant(
                  _SelectedPlant(
                    tenLabel: r.plantId,
                    tenCay: r.commonName,
                    tenQuocte: r.scientificName,
                    imageUrl: r.imageUrl,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
      );

  // ── Bước 2: form thêm cây ──────────────────────────────────────────────

  Widget _buildForm(_SelectedPlant plant) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // Thẻ cây đã chọn
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: const Color(0xFFF7FAF8),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 62,
                    height: 62,
                    child: plant.imageUrl != null && plant.imageUrl!.isNotEmpty
                        ? Image.network(
                            plant.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.eco_rounded,
                              color: AppColors.primary,
                            ),
                          )
                        : const Icon(Icons.eco_rounded, color: AppColors.primary),
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plant.tenCay,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (plant.tenQuocte != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          plant.tenQuocte!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: Color(0xFF6C757D),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Ngày gieo (bắt buộc)
          _sectionTitle('📅 Ngày gieo *'),
          const SizedBox(height: 8),
          InkWell(
            onTap: _pickPlantedDate,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFDDE5E1)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.event_rounded, size: 19, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Text(
                    formatVnDate(_plantedAt),
                    style: const TextStyle(fontSize: 14.5),
                  ),
                  const Spacer(),
                  const Text(
                    'Đổi',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Chọn ngày bạn gieo hạt/cắm cây — thông tin này quyết định cây có '
            '"đến kỳ thu hoạch" hay chưa.',
            style: TextStyle(fontSize: 11.5, color: Color(0xFF6C757D), height: 1.4),
          ),
          const SizedBox(height: 18),

          // Giai đoạn (bắt buộc)
          _sectionTitle('🌱 Giai đoạn hiện tại *'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: kGardenStages.map((s) {
              final selected = _stage == s;
              return InkWell(
                onTap: () => setState(() => _stage = s),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: selected
                        ? stageColor(s).withValues(alpha: 0.14)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected ? stageColor(s) : const Color(0xFFDDE5E1),
                      width: selected ? 1.6 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        stageIcon(s),
                        size: 15,
                        color: stageColor(s),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        kStageLabels[s] ?? s,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                          color: selected ? stageColor(s) : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // ── Loại đất ──
          _sectionTitle('🪴 Loại đất'),
          const SizedBox(height: 8),
          _buildSoilSection(),
          const SizedBox(height: 20),

          // ── Nơi trồng ──
          _sectionTitle('🏡 Nơi trồng'),
          const SizedBox(height: 8),
          if (_soilOptions != null)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _soilOptions!.plantingMedia.map((m) {
                final selected = _plantingMedium == m.code;
                return InkWell(
                  onTap: () => setState(
                    () => _plantingMedium = selected ? null : m.code,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primary.withValues(alpha: 0.11)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color:
                            selected ? AppColors.primary : const Color(0xFFDDE5E1),
                      ),
                    ),
                    child: Text(
                      m.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected ? AppColors.primary : Colors.black87,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 20),

          // ── Vị trí ──
          _sectionTitle('📍 Vị trí'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _addressCtrl,
            decoration: InputDecoration(
              hintText: 'VD: Vườn nhà tôi, Sân thượng tầng 3',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _locating ? null : _useCurrentLocation,
            icon: _locating
                ? const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location_rounded, size: 18),
            label: Text(
              _latitude != null
                  ? 'Đã lấy vị trí (${_latitude!.toStringAsFixed(4)}, '
                      '${_longitude!.toStringAsFixed(4)})'
                  : 'Dùng vị trí hiện tại',
            ),
          ),
          const SizedBox(height: 20),

          // ── Ghi chú ──
          _sectionTitle('📝 Ghi chú (không bắt buộc)'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _notesCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'VD: Trồng chậu trên bệ cửa sổ, đất hơi chua',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 26),

          // ── Lưu ──
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_rounded, size: 19),
              label: Text(
                _saving ? 'Đang lưu…' : 'Lưu vào vườn',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  // ── Phần loại đất ──────────────────────────────────────────────────────

  Widget _buildSoilSection() {
    final opts = _soilOptions;

    // Gợi ý theo loài (nếu server có).
    final sug = _soilSuggestion;
    if (sug != null && sug.hasSuggestion) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GardenBanner(
            text: sug.reason ?? 'Gợi ý: ${sug.soilLabel}',
            kind: GardenBannerKind.info,
            icon: Icons.lightbulb_rounded,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _soilType = sug.soilType),
                  child: const Text('Dùng loại đất này'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextButton(
                  onPressed: () => setState(() {
                    _soilType = null;
                    _doAm = null;
                    _mauDat = null;
                  }),
                  child: const Text('Tôi muốn chọn khác'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      );
    }

    // 2 câu hỏi triệu chứng (radio).
    if (opts != null && _soilType == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Bạn không cần biết loại đất — chỉ cần nhìn bằng mắt:',
            style: TextStyle(fontSize: 12.5, height: 1.45),
          ),
          const SizedBox(height: 10),
          ...opts.symptomQuestions.map((q) {
            final current = q.key == 'do_am' ? _doAm : _mauDat;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    q.question,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (q.hint != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      q.hint!,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF6C757D),
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  ...q.options.map((o) {
                    return RadioListTile<String>(
                      value: o.code,
                      groupValue: current,
                      onChanged: (v) {
                        setState(() {
                          if (q.key == 'do_am') {
                            _doAm = v;
                          } else {
                            _mauDat = v;
                          }
                          _soilType = opts.symptomToSoil['$_doAm|$_mauDat'];
                        });
                      },
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      activeColor: AppColors.primary,
                      title: Text(
                        o.label,
                        style: const TextStyle(fontSize: 12.5),
                      ),
                      subtitle: o.hint == null
                          ? null
                          : Text(
                              o.hint!,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF6C757D),
                              ),
                            ),
                    );
                  }),
                ],
              ),
            );
          }),
          const SizedBox(height: 6),
          const Divider(),
          const SizedBox(height: 10),
        ],
      );
    }

    // Danh sách 5 loại đất.
    if (opts == null) {
      return const SizedBox(
        child: Text(
          'Đang tải lựa chọn loại đất…',
          style: TextStyle(fontSize: 12.5, color: Color(0xFF6C757D)),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Chọn loại đất:',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        ...opts.soilTypes.map((s) {
          final selected = _soilType == s.code;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: () => setState(() => _soilType = s.code),
              borderRadius: BorderRadius.circular(11),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFFE8F4EF)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(
                    color: selected
                        ? AppColors.primary
                        : const Color(0xFFDDE5E1),
                    width: selected ? 1.6 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            s.label,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              color: selected
                                  ? AppColors.primary
                                  : Colors.black87,
                            ),
                          ),
                        ),
                        if (selected)
                          const Icon(
                            Icons.check_circle_rounded,
                            size: 18,
                            color: AppColors.primary,
                          ),
                      ],
                    ),
                    if (s.description != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        s.description!,
                        style: const TextStyle(fontSize: 11.5, height: 1.4),
                      ),
                    ],
                    if (s.waterHint != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '💧 ${s.waterHint}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          height: 1.4,
                          color: Color(0xFF1D4ED8),
                        ),
                      ),
                    ],
                    if (s.phAdvice != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        '🌱 ${s.phAdvice}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          height: 1.4,
                          color: Color(0xFF2D6A4F),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Future<void> _pickPlantedDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _plantedAt,
      firstDate: DateTime.now().subtract(const Duration(days: 3650)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('vi', 'VN'),
    );
    if (picked != null) {
      setState(() => _plantedAt = picked);
    }
  }
}

/// Ô kết quả cây (nhận diện hoặc tìm kiếm).
class _PlantResultTile extends StatelessWidget {
  const _PlantResultTile({
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.onTap,
  });

  final String title;
  final String? subtitle;
  final String? imageUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFDDE5E1)),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: SizedBox(
                  width: 50,
                  height: 50,
                  child: imageUrl != null && imageUrl!.isNotEmpty
                      ? Image.network(
                          imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.eco_rounded,
                            color: AppColors.primary,
                          ),
                        )
                      : const Icon(Icons.eco_rounded, color: AppColors.primary),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontStyle: FontStyle.italic,
                          color: Color(0xFF6C757D),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(
                Icons.add_circle_rounded,
                color: AppColors.primary,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
