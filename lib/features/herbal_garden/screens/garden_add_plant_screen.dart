// lib/features/herbal_garden/screens/garden_add_plant_screen.dart
//
// MÀN HÌNH 3 — THÊM CÂY VÀO VƯỜN
//
// Luồng gồm 4 bước (Stepper ngang trên 1 trang cuộn):
//   1. Chọn loài cây  — nhận diện bằng ảnh (POST /predict) HOẶC tìm trong
//      danh mục (GET /api/v1/plants/search)
//   2. Thông tin trồng — ngày gieo, giai đoạn, ghi chú
//   3. Đất & nơi trồng — chẩn đoán đất bằng 2 triệu chứng (GET /soil-options)
//      hoặc dùng gợi ý của hệ thống (GET /soil-suggestion)
//   4. Vị trí & xác nhận — GPS hiện tại rồi lưu (POST /api/v1/herbal-garden)

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:thunghiem1/features/herbal_garden/models/garden_models.dart';
import 'package:thunghiem1/features/herbal_garden/services/herbal_garden_api.dart';
import 'package:thunghiem1/features/herbal_garden/state/herbal_garden_state.dart';
import 'package:thunghiem1/features/herbal_garden/utils/garden_location.dart';
import 'package:thunghiem1/features/herbal_garden/widgets/garden_style.dart';
import 'package:thunghiem1/theme/app_colors.dart';

class GardenAddPlantScreen extends StatefulWidget {
  final String? initialTenLabel;
  final String? initialTenCay;

  const GardenAddPlantScreen({
    super.key,
    this.initialTenLabel,
    this.initialTenCay,
    this.api,
  });

  /// API client — để truyền client dùng chung từ [HerbalGardenController].
  ///
  /// Nếu `null`, màn hình sẽ lấy client từ Provider; nếu Provider cũng
  /// không có thì tạo client riêng (fallback).
  final HerbalGardenApi? api;

  @override
  State<GardenAddPlantScreen> createState() => _GardenAddPlantScreenState();
}

class _GardenAddPlantScreenState extends State<GardenAddPlantScreen> {
  /// Client dùng chung (từ controller) — được resolve lúc initState.
  late final HerbalGardenApi _api;

  /// true nếu client do chính màn hình tạo → màn hình phải dispose nó.
  bool _ownsApi = false;

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  // ── Bước 1: chọn loài ────────────────────────────────────────────────
  String? _tenLabel;
  String? _tenCay;
  String? _imageUrl;
  bool _searching = false;
  List<CatalogPlant> _searchResults = <CatalogPlant>[];

  // ── Bước 2: thông tin ───────────────────────────────────────────────
  DateTime _plantedAt = DateTime.now();
  String _stage = 'gieo_trong';

  // ── Bước 3: đất ──────────────────────────────────────────────────────
  SoilOptions? _soilOptions;
  bool _loadingSoil = false;
  SoilSuggestion? _suggestion;
  String? _soilType;
  String? _plantingMedium;
  String? _doAm;
  String? _mauDat;

  // ── Bước 4: vị trí & lưu ────────────────────────────────────────────
  double? _latitude;
  double? _longitude;
  String? _addressName;
  bool _locating = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();

    // Ưu tiên client được inject → client dùng chung của controller →
    // tạo client riêng (fallback khi dùng ngoài Provider).
    if (widget.api != null) {
      _api = widget.api!;
    } else {
      final shared = context.read<HerbalGardenController?>();
      if (shared != null) {
        _api = shared.api;
      } else {
        _api = HerbalGardenApi();
        _ownsApi = true;
      }
    }

    _tenLabel = widget.initialTenLabel;
    _tenCay = widget.initialTenCay;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSoilOptions());
    if (_tenLabel != null) _loadSuggestion();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _notesController.dispose();
    // Chỉ dispose client do chính màn hình tạo — client dùng chung thì do
    // controller quản lý.
    if (_ownsApi) _api.dispose();
    super.dispose();
  }

  // ── Tải dữ liệu đất ───────────────────────────────────────────────────

  Future<void> _loadSoilOptions() async {
    setState(() => _loadingSoil = true);
    try {
      final options = await _api.soilOptions();
      if (!mounted) return;
      setState(() {
        _soilOptions = options;
        _loadingSoil = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingSoil = false);
    }
  }

  Future<void> _loadSuggestion() async {
    final label = _tenLabel;
    if (label == null || label.isEmpty) return;
    try {
      final suggestion = await _api.soilSuggestion(label);
      if (!mounted) return;
      setState(() => _suggestion = suggestion);
    } catch (_) {
      // Không có gợi ý → người dùng tự chẩn đoán.
    }
  }

  // ── Bước 1 ────────────────────────────────────────────────────────────

  Future<void> _search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    setState(() => _searching = true);
    try {
      final results = await _api.searchCatalog(q);
      if (!mounted) return;
      setState(() {
        _searchResults = results;
        _searching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _searching = false);
      _toast('Không tìm được. Thử từ khoá khác.', ok: false);
    }
  }

  /// Chọn loài cây từ kết quả tìm kiếm trong danh mục.
  void _selectPlant(CatalogPlant plant) {
    setState(() {
      _tenLabel = plant.plantId;
      _tenCay = plant.commonName;
      _imageUrl = plant.imageUrl;
      _searchResults = const <CatalogPlant>[];
      _searchController.clear();
    });
    _loadSuggestion();
  }

  // ── Bước 3: chẩn đoán đất ────────────────────────────────────────────

  /// Suy ra loại đất từ 2 triệu chứng người dùng chọn.
  void _applySymptomDiagnosis() {
    final options = _soilOptions;
    if (options == null || _doAm == null || _mauDat == null) return;

    final soilType = options.soilTypeForSymptoms(
      doAm: _doAm!,
      mauDat: _mauDat!,
    );
    if (soilType == null) {
      _toast('Không suy ra được loại đất từ các lựa chọn này.', ok: false);
      return;
    }
    setState(() {
      _soilType = soilType;
      _suggestion = null;
    });
  }

  // ── Bước 4: GPS ───────────────────────────────────────────────────────

  Future<void> _captureLocation() async {
    setState(() => _locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (!mounted) return;
        setState(() => _locating = false);
        _toast('Thiết bị đang tắt định vị.', ok: false);
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() => _locating = false);
        _toast('Cần quyền vị trí để lưu GPS cây.', ok: false);
        return;
      }
      // Dùng helper có timeout: nếu plugin bị treo thì coi như thất bại,
      // không chặn vĩnh viễn luồng thêm cây.
      final position = await resolveGardenPosition(
        timeout: const Duration(seconds: 10),
      );
      if (position == null) {
        if (!mounted) return;
        setState(() => _locating = false);
        _toast('Không lấy được vị trí. Vẫn thêm cây được.', ok: false);
        return;
      }
      if (!mounted) return;
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _addressName =
            'Vị trí ${position.latitude.toStringAsFixed(4)}, '
            '${position.longitude.toStringAsFixed(4)}';
        _locating = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _locating = false);
      _toast('Không lấy được vị trí.', ok: false);
    }
  }

  // ── Lưu ───────────────────────────────────────────────────────────────

  Future<void> _save() async {
    final label = _tenLabel;
    if (label == null || label.isEmpty) {
      _toast('Hãy chọn loài cây trước.', ok: false);
      return;
    }

    setState(() => _saving = true);
    try {
      final result = await context.read<HerbalGardenController>().addPlant(
        tenLabel: label,
        plantedAt: _plantedAt,
        stage: _stage,
        notes: _notesController.text.trim(),
        latitude: _latitude,
        longitude: _longitude,
        addressName: _addressName,
        soilType: _soilType,
        plantingMedium: _plantingMedium,
        doAm: _doAm,
        mauDat: _mauDat,
      );

      if (!mounted) return;

      if (result.isDuplicate) {
        setState(() => _saving = false);
        _showDuplicateDialog(result);
        return;
      }

      _toast(result.message, ok: true);
      Navigator.of(context).pop(true);
    } on GardenApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _toast(e.message, ok: false);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      _toast('Lưu thất bại. Thử lại nhé.', ok: false);
    }
  }

  void _showDuplicateDialog(AddPlantResult result) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Loài này đã có trong vườn',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16.5),
        ),
        content: Text(
          result.message,
          style: const TextStyle(fontSize: 13.5, height: 1.5),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Để sau'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Về vườn'),
          ),
        ],
      ),
    );
  }

  void _toast(String message, {required bool ok}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(fontSize: 13, height: 1.35),
          ),
          // ⚠️ Lỗi thường → CAM, không phải đỏ. Đỏ chỉ dành cho lỗi nghiêm
          // trọng; dùng đỏ cho mọi lỗi khiến app trông như đang "lỗi lớn".
          backgroundColor: ok ? AppColors.primary : const Color(0xFFB0621A),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: ok ? 2 : 3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
  }

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Thêm cây vào vườn',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: <Widget>[
          _buildStep1(),
          const SizedBox(height: 18),
          _buildStep2(),
          const SizedBox(height: 18),
          _buildStep3(),
          const SizedBox(height: 18),
          _buildStep4(),
          const SizedBox(height: 22),
          // ── NÚT XÁC NHẬN TO Ở CUỐI MÀN HÌNH ──────────────────────────
          //
          // Sau khi người dùng chọn xong 4 bước, bấm nút này để lưu cây
          // vào vườn. Nút to, nền đậm, chữ trắng in đậm → không thể bỏ sót.
          _buildConfirmSection(),
        ],
      ),
    );
  }

  /// Khu vực xác nhận cuối màn hình — tóm tắt lựa chọn + nút lưu to.
  Widget _buildConfirmSection() {
    final ready = _tenLabel != null;

    return GardenCard(
      borderColor: ready ? AppColors.primary : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                ready ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                size: 19,
                color: ready ? AppColors.success : Colors.black38,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Xác nhận thêm cây',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _ConfirmRow(
            label: 'Loài cây',
            value: _tenCay ?? _tenLabel ?? 'Chưa chọn',
            done: _tenLabel != null,
          ),
          _ConfirmRow(
            label: 'Ngày gieo',
            value: gardenFormatDate(_plantedAt),
            done: true,
          ),
          _ConfirmRow(
            label: 'Giai đoạn',
            value: kGardenStageLabels[_stage] ?? _stage,
            done: true,
          ),
          _ConfirmRow(
            label: 'Loại đất',
            value:
                _soilOptions?.soilTypeByCode(_soilType)?.label ??
                (_soilType == null ? 'Chưa chọn (không bắt buộc)' : _soilType!),
            done: _soilType != null,
          ),
          _ConfirmRow(
            label: 'Nơi trồng',
            value: _plantingMedium == null
                ? 'Chưa chọn (không bắt buộc)'
                : (_soilOptions?.plantingMedia
                          .where((m) => m.code == _plantingMedium)
                          .firstOrNull
                          ?.label ??
                      _plantingMedium!),
            done: _plantingMedium != null,
          ),
          const SizedBox(height: 6),
          GardenBigConfirmButton(
            label: 'Xác nhận thêm cây vào vườn',
            icon: Icons.check_rounded,
            loading: _saving,
            onPressed: ready && !_saving ? _save : null,
            hint: ready
                ? 'Cây sẽ được lưu vào vườn dược liệu của bạn.'
                : 'Hãy chọn loài cây ở bước 1 trước khi xác nhận.',
          ),
        ],
      ),
    );
  }

  // ── Bước 1 ────────────────────────────────────────────────────────────

  Widget _buildStep1() {
    return GardenCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _StepTitle(
            index: 1,
            title: 'Chọn loài cây',
            subtitle: _tenLabel == null
                ? 'Chụp ảnh để nhận diện hoặc tìm theo tên'
                : 'Đã chọn: ${_tenCay ?? _tenLabel}',
          ),
          const SizedBox(height: 14),
          if (_tenLabel != null) ...<Widget>[
            _SelectedPlantRow(
              tenCay: _tenCay ?? _tenLabel!,
              tenLabel: _tenLabel!,
              imageUrl: _imageUrl,
              onClear: () => setState(() {
                _tenLabel = null;
                _tenCay = null;
                _imageUrl = null;
                _suggestion = null;
              }),
            ),
            const SizedBox(height: 12),
          ] else ...<Widget>[
            // ⚠️ KHÔNG có nút chụp ảnh ở đây nữa.
            //
            // Nhận diện ảnh thuộc chức năng "Nhận diện" (Camera → Kết quả).
            // Ở đó người dùng chọn 1 trong 3 kết quả → app hỏi "Bạn có muốn
            // đưa cây này vào vườn dược liệu không?" → mở đúng màn này với
            // loài cây đã chọn. Nhờ vậy không có 2 luồng nhận diện song song.
            const GardenInfoBanner(
              message:
                  'Chưa chọn loài cây. Bạn có thể tìm theo tên bên dưới, '
                  'hoặc dùng chức năng "Nhận diện" (chụp ảnh) rồi chọn '
                  '"Thêm vào vườn dược liệu".',
              icon: Icons.info_outline_rounded,
            ),
            const SizedBox(height: 14),
            const Row(
              children: <Widget>[
                Expanded(child: Divider(color: Color(0xFFE5E5E5))),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    'TÌM THEO TÊN',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.black38,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Expanded(child: Divider(color: Color(0xFFE5E5E5))),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: _search,
              decoration: InputDecoration(
                hintText: 'VD: rau má, bạch hoa xà...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: IconButton(
                  onPressed: () => _search(_searchController.text),
                  icon: const Icon(Icons.arrow_forward_rounded),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            if (_searching) ...<Widget>[
              const SizedBox(height: 12),
              const Center(child: CircularProgressIndicator(strokeWidth: 2.2)),
            ] else if (_searchResults.isNotEmpty) ...<Widget>[
              const SizedBox(height: 10),
              ..._searchResults
                  .take(8)
                  .map(
                    (p) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: GardenNetworkImage(
                        url: p.imageUrl,
                        width: 42,
                        height: 42,
                      ),
                      title: Text(
                        p.commonName,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        p.scientificName ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      onTap: () => _selectPlant(p),
                    ),
                  ),
            ],
          ],
        ],
      ),
    );
  }

  // ── Bước 2 ────────────────────────────────────────────────────────────

  Widget _buildStep2() {
    return GardenCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const _StepTitle(
            index: 2,
            title: 'Thông tin trồng',
            subtitle: 'Ngày gieo, giai đoạn hiện tại và ghi chú của bạn',
          ),
          const SizedBox(height: 14),
          InkWell(
            onTap: _pickPlantedAt,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.event_rounded,
                    size: 19,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text(
                          'Ngày gieo',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          gardenFormatDate(_plantedAt),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.edit_rounded,
                    size: 16,
                    color: Colors.black38,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Giai đoạn hiện tại',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: kGardenStages.map((stage) {
              final selected = _stage == stage;
              final color = GardenStageStyle.color(stage);
              return GardenSelectChip(
                label: kGardenStageLabels[stage] ?? stage,
                icon: GardenStageStyle.icon(stage),
                color: color,
                selected: selected,
                onTap: () => setState(() => _stage = stage),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _notesController,
            maxLines: 3,
            maxLength: 500,
            decoration: const InputDecoration(
              labelText: 'Ghi chú (tuỳ chọn)',
              hintText: 'VD: Trồng chậu nhỏ, tưới 2 lần/ngày...',
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickPlantedAt() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _plantedAt,
      firstDate: DateTime.now().subtract(const Duration(days: 3650)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null || !mounted) return;
    setState(() => _plantedAt = picked);
  }

  // ── Bước 3 ────────────────────────────────────────────────────────────

  Widget _buildStep3() {
    final options = _soilOptions;

    return GardenCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const _StepTitle(
            index: 3,
            title: 'Đất & nơi trồng',
            subtitle: 'Giúp hệ thống tính đúng chu kỳ tưới cho cây',
          ),
          const SizedBox(height: 14),
          if (_loadingSoil)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(strokeWidth: 2.2),
              ),
            )
          else if (options == null)
            GardenErrorBanner(
              message:
                  'Không tải được danh mục đất. Bạn vẫn có thể bỏ qua bước này.',
              onRetry: _loadSoilOptions,
            )
          else ...<Widget>[
            // Gợi ý của hệ thống.
            if (_suggestion != null && _suggestion!.hasSuggestion) ...<Widget>[
              GardenInfoBanner(
                message:
                    'Gợi ý cho ${_suggestion!.tenCay ?? _tenLabel}: '
                    '${_suggestion!.soilLabel}'
                    '${(_suggestion!.reason ?? '').isNotEmpty ? ' — ${_suggestion!.reason}' : ''}',
                icon: Icons.auto_awesome_rounded,
              ),
              const SizedBox(height: 10),
              GardenOutlineButton(
                label: 'Dùng gợi ý này',
                icon: Icons.check_rounded,
                onPressed: () => setState(() {
                  _soilType = _suggestion!.soilType;
                  _suggestion = null;
                }),
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 14),
            ],

            // Chẩn đoán bằng triệu chứng.
            const Text(
              'Tự chẩn đoán đất',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'Trả lời 2 câu, hệ thống sẽ đoán loại đất của bạn.',
              style: TextStyle(
                fontSize: 11.5,
                color: Colors.black.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 12),
            ...options.symptomQuestions.map(
              (q) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      q.question,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if ((q.hint ?? '').isNotEmpty) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        q.hint!,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.black.withValues(alpha: 0.45),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    ...q.options.map((o) {
                      final selected = (q.key == 'do_am'
                          ? _doAm == o.code
                          : _mauDat == o.code);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 7),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              if (q.key == 'do_am') {
                                _doAm = o.code;
                              } else {
                                _mauDat = o.code;
                              }
                            });
                            _applySymptomDiagnosis();
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 11,
                            ),
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppColors.primary.withValues(alpha: 0.08)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: selected
                                    ? AppColors.primary
                                    : Colors.black.withValues(alpha: 0.08),
                                width: selected ? 1.4 : 1,
                              ),
                            ),
                            child: Row(
                              children: <Widget>[
                                Icon(
                                  selected
                                      ? Icons.radio_button_checked_rounded
                                      : Icons.radio_button_unchecked_rounded,
                                  size: 18,
                                  color: selected
                                      ? AppColors.primary
                                      : Colors.black26,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        o.label,
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if ((o.hint ?? '')
                                          .isNotEmpty) ...<Widget>[
                                        const SizedBox(height: 2),
                                        Text(
                                          o.hint!,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.black.withValues(
                                              alpha: 0.45,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),

            if (_soilType != null) ...<Widget>[
              const SizedBox(height: 4),
              GardenInfoBanner(
                message:
                    'Đã xác định loại đất: '
                    '${options.soilTypeByCode(_soilType)?.label ?? _soilType}',
                icon: Icons.check_circle_rounded,
              ),
              const SizedBox(height: 12),
            ],

            // Chọn thủ công.
            const Text(
              'Hoặc chọn thủ công',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: options.soilTypes.map((s) {
                final selected = _soilType == s.code;
                return GardenSelectChip(
                  label: s.shortLabel ?? s.label,
                  icon: Icons.landscape_rounded,
                  color: const Color(0xFF8A6D3B),
                  selected: selected,
                  onTap: () => setState(() {
                    _soilType = s.code;
                    _suggestion = null;
                  }),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            const Text(
              'Nơi trồng',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: options.plantingMedia.map((m) {
                final selected = _plantingMedium == m.code;
                return GardenSelectChip(
                  label: m.label,
                  icon: Icons.local_florist_outlined,
                  color: AppColors.accent,
                  selected: selected,
                  onTap: () => setState(
                    () => _plantingMedium = selected ? null : m.code,
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  // ── Bước 4 ────────────────────────────────────────────────────────────

  Widget _buildStep4() {
    return GardenCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const _StepTitle(
            index: 4,
            title: 'Vị trí trồng',
            subtitle: 'Dùng để tính thời tiết và gợi ý tưới chính xác',
          ),
          const SizedBox(height: 14),
          if (_latitude != null) ...<Widget>[
            GardenInfoBanner(
              message:
                  'Đã lưu GPS: ${_latitude!.toStringAsFixed(5)}, '
                  '${_longitude!.toStringAsFixed(5)}',
              icon: Icons.check_circle_rounded,
            ),
            const SizedBox(height: 10),
          ] else
            GardenInfoBanner(
              message:
                  'Bạn có thể bỏ qua nếu không muốn ghi vị trí. '
                  'Server sẽ dùng vùng mặc định (Hà Nội) để tính thời tiết.',
              icon: Icons.info_outline_rounded,
            ),
          const SizedBox(height: 12),
          GardenOutlineButton(
            label: _locating ? 'Đang lấy vị trí...' : 'Lấy vị trí hiện tại',
            icon: Icons.my_location_rounded,
            onPressed: _locating ? null : _captureLocation,
          ),
        ],
      ),
    );
  }

  // ── Thanh lưu ──────────────────────────────────────────────────────────

  // ⚠️ ĐÃ BỎ thanh lưu cố định ở đáy — nút xác nhận to nằm ở CUỐI nội
  // dung (xem [_buildConfirmSection]) đúng như yêu cầu: chọn xong 4 bước
  // rồi mới bấm xác nhận.
}

/// Dòng tóm tắt trong khối xác nhận.
class _ConfirmRow extends StatelessWidget {
  final String label;
  final String value;
  final bool done;

  const _ConfirmRow({
    required this.label,
    required this.value,
    required this.done,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            done ? Icons.check_rounded : Icons.remove_rounded,
            size: 15,
            color: done ? AppColors.success : Colors.black26,
          ),
          const SizedBox(width: 7),
          SizedBox(
            width: 78,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.black.withValues(alpha: 0.5),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: done ? FontWeight.w700 : FontWeight.w500,
                color: done
                    ? Colors.black.withValues(alpha: 0.85)
                    : Colors.black.withValues(alpha: 0.4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Widget phụ ────────────────────────────────────────────────────────────

class _StepTitle extends StatelessWidget {
  final int index;
  final String title;
  final String subtitle;

  const _StepTitle({
    required this.index,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 26,
          height: 26,
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            '$index',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.35,
                  color: Colors.black.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SelectedPlantRow extends StatelessWidget {
  final String tenCay;
  final String tenLabel;
  final String? imageUrl;
  final VoidCallback onClear;

  const _SelectedPlantRow({
    required this.tenCay,
    required this.tenLabel,
    this.imageUrl,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: <Widget>[
          GardenNetworkImage(url: imageUrl, width: 46, height: 46),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  tenCay,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  tenLabel,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.black.withValues(alpha: 0.45),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onClear,
            icon: const Icon(Icons.close_rounded, size: 18),
            color: Colors.black45,
            tooltip: 'Chọn lại',
          ),
        ],
      ),
    );
  }
}
