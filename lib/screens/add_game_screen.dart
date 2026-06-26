// lib/screens/add_game_screen.dart
// This is the heart of ChessDiary — upload a photo, PDF, or paste text,
// and Gemini AI reads and saves your game automatically.

import 'dart:convert' show utf8;
import 'dart:typed_data' show Uint8List;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart' hide Badge;
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import '../models/game_model.dart';
import '../services/badge_service.dart';
import '../services/gemini_service.dart';
import '../services/game_service.dart';
import '../services/auth_service.dart';
import '../services/pgn_parser.dart';
import '../utils/theme.dart';
import '../utils/web_theme.dart';
import 'chess_com_import_screen.dart';
import 'lichess_import_screen.dart';

class AddGameScreen extends StatefulWidget {
  const AddGameScreen({super.key});

  @override
  State<AddGameScreen> createState() => _AddGameScreenState();
}

class _AddGameScreenState extends State<AddGameScreen> {
  // ── State ──────────────────────────────────────
  Uint8List? _selectedBytes;
  String? _selectedMimeType;
  String _fileName = '';
  String _inputType = ''; // 'image', 'pdf', 'text', 'pgn'

  final _textCtrl     = TextEditingController();
  final _playerCtrl   = TextEditingController();
  final _opponentCtrl = TextEditingController();
  final _eventCtrl    = TextEditingController();
  final _notesCtrl    = TextEditingController();
  final _tagCtrl      = TextEditingController();
  final List<String> _tags = [];

  String _source = 'paper';
  String _playerColor = 'white';
  String? _timeControl;
  DateTime _datePlayed = DateTime.now();

  bool _parsing = false;
  bool _saving = false;
  String _statusMessage = '';

  Map<String, dynamic>? _parsedData;

  // ── UI ────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final web = kIsWeb;
    return Scaffold(
      backgroundColor: web ? WT.scaffoldBg : null,
      appBar: web
          ? webAppBar(context, title: 'Add Game')
          : AppBar(title: const Text('Add Game')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(web ? 28 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('How are you adding this game?'),
            const SizedBox(height: 12),
            _inputMethodRow(),

            const SizedBox(height: 24),

            if (_inputType == 'image' || _inputType == 'pdf' || _inputType == 'pgn') _filePreview(),
            if (_inputType == 'text') _textInput(),

            const SizedBox(height: 24),
            _sectionTitle('Game Details'),
            const SizedBox(height: 12),
            _gameDetailsForm(),

            const SizedBox(height: 24),
            if (_statusMessage.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: web ? WT.cream : AppTheme.surfaceAlt,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    if (_parsing || _saving)
                      SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: web ? WT.greenLt : AppTheme.primary),
                      )
                    else
                      Icon(Icons.check_circle_rounded,
                          color: web ? WT.greenLt : AppTheme.primary, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(_statusMessage,
                          style: web
                              ? WT.lora(13, color: WT.textColor)
                              : const TextStyle(
                                  color: AppTheme.textPrimary, fontSize: 13)),
                    ),
                  ],
                ),
              ),

            if (_parsedData != null) _parsedPreview(),

            const SizedBox(height: 24),
            _actionButton(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ── Widgets ───────────────────────────────────

  Widget _sectionTitle(String t) {
    final web = kIsWeb;
    return Text(
      t,
      style: web
          ? WT.lora(12, color: WT.mutedColor, weight: FontWeight.w700, style: FontStyle.italic)
          : const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
    );
  }

  Widget _inputMethodRow() {
    return Column(
      children: [
        Row(
          children: [
            _methodCard('📸', 'Photo\nScoresheet', 'image'),
            const SizedBox(width: 8),
            _methodCard('📄', 'PDF /\nImage', 'pdf'),
            const SizedBox(width: 8),
            _methodCard('⌨️', 'Paste\nMoves', 'text'),
            const SizedBox(width: 8),
            _methodCard('♟', 'PGN\nFile', 'pgn'),
          ],
        ),
        const SizedBox(height: 10),
        _chessComButton(),
        const SizedBox(height: 8),
        _lichessButton(),
      ],
    );
  }

  Widget _lichessButton() {
    final web = kIsWeb;
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LichessImportScreen()),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: web ? WT.white : AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFBAAAAA), width: 1.5),
          boxShadow: web
              ? const [BoxShadow(color: Color(0x06000000), blurRadius: 5, offset: Offset(0, 2))]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFF3C3C3C),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(child: Text('🦁', style: TextStyle(fontSize: 18))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Import from Lichess',
                      style: web
                          ? WT.lora(13, color: WT.textColor, weight: FontWeight.w600)
                          : const TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14)),
                  Text('Fetch all your games by username',
                      style: web
                          ? WT.bodySm(12)
                          : const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                color: web ? WT.muted : AppTheme.textSecondary, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _chessComButton() {
    final web = kIsWeb;
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ChessComImportScreen()),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: web ? WT.white : AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF7FA650), width: 1.5),
          boxShadow: web
              ? const [BoxShadow(color: Color(0x06000000), blurRadius: 5, offset: Offset(0, 2))]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFF7FA650),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Text('♟', style: TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Import from Chess.com',
                    style: web
                        ? WT.lora(13, color: WT.textColor, weight: FontWeight.w600)
                        : const TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                  ),
                  Text(
                    'Fetch all your games by username',
                    style: web
                        ? WT.bodySm(12)
                        : const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                color: web ? WT.muted : AppTheme.textSecondary, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _methodCard(String emoji, String label, String type) {
    final web = kIsWeb;
    final selected = _inputType == type;
    final accentC = web ? WT.greenLt : AppTheme.primary;
    return Expanded(
      child: GestureDetector(
        onTap: () => _selectInputType(type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: web
              ? (selected ? WT.cardDeco(accentBorder: WT.greenLt) : WT.cardDeco())
              : BoxDecoration(
                  color: selected
                      ? AppTheme.primary.withValues(alpha: 0.15)
                      : AppTheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected ? AppTheme.primary : AppTheme.surfaceAlt,
                    width: selected ? 2 : 1,
                  ),
                ),
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected ? accentC : (web ? WT.muted : AppTheme.textSecondary),
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filePreview() {
    final web = kIsWeb;
    final accentC = web ? WT.greenLt : AppTheme.primary;
    return GestureDetector(
      onTap: _pickFile,
      child: Container(
        width: double.infinity,
        height: 160,
        decoration: BoxDecoration(
          color: web ? WT.white : AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _selectedBytes != null
                ? accentC
                : (web ? WT.border : AppTheme.surfaceAlt),
            width: 2,
          ),
          boxShadow: web
              ? const [BoxShadow(color: Color(0x06000000), blurRadius: 5, offset: Offset(0, 2))]
              : null,
        ),
        child: _selectedBytes != null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_inputType == 'image' && kIsWeb && _isHeicFile) ...[
                    Icon(Icons.image_rounded, color: accentC, size: 48),
                    const SizedBox(height: 8),
                    Text(_fileName,
                        style: TextStyle(
                            color: accentC, fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text('HEIC ready for AI parsing',
                        style: WT.bodySm(11)),
                  ] else if (_inputType == 'image')
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.memory(_selectedBytes!, fit: BoxFit.cover, width: double.infinity),
                      ),
                    )
                  else if (_inputType == 'pgn') ...[
                    const Text('♟', style: TextStyle(fontSize: 40)),
                    const SizedBox(height: 8),
                    Text(_fileName,
                        style: TextStyle(
                            color: accentC, fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text('PGN file ready',
                        style: web
                            ? WT.bodySm(11)
                            : const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                  ] else ...[
                    Icon(Icons.picture_as_pdf_rounded, color: accentC, size: 48),
                    const SizedBox(height: 8),
                    Text(_fileName,
                        style: web
                            ? WT.bodySm(12)
                            : const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  ],
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _inputType == 'image'
                        ? Icons.add_a_photo_rounded
                        : Icons.upload_file_rounded,
                    color: web ? WT.muted : AppTheme.textSecondary,
                    size: 40,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _inputType == 'image'
                        ? (kIsWeb
                            ? 'Tap to select image (JPG, PNG, WEBP, HEIC)'
                            : 'Tap to take photo or choose from gallery')
                        : _inputType == 'pgn'
                            ? 'Tap to select a .pgn file'
                            : 'Tap to select PDF or screenshot',
                    style: web
                        ? WT.bodySm(13)
                        : const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
      ),
    );
  }

  Widget _textInput() {
    return TextField(
      controller: _textCtrl,
      maxLines: 10,
      decoration: const InputDecoration(
        hintText: 'Paste PGN, move list, or any chess notation here...\n\nExample:\n1. e4 e5 2. Nf3 Nc6 3. Bb5 a6',
        alignLabelWithHint: true,
      ),
    );
  }

  Widget _gameDetailsForm() {
    final web = kIsWeb;
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _dropdown('Source', _source, ['paper', 'chess.com', 'lichess', 'other'],
                (v) => setState(() => _source = v!))),
            const SizedBox(width: 12),
            Expanded(child: _dropdown('Playing as', _playerColor, ['white', 'black'],
                (v) => setState(() => _playerColor = v!))),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _opponentCtrl,
          decoration: InputDecoration(
            labelText: 'Opponent Name (optional)',
            prefixIcon: Icon(Icons.person_outline_rounded,
                color: web ? WT.muted : AppTheme.textSecondary),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _nullableDropdown(
              'Time Control',
              _timeControl,
              ['bullet', 'blitz', 'rapid', 'classical', 'correspondence'],
              (v) => setState(() => _timeControl = v),
            )),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _eventCtrl,
          decoration: InputDecoration(
            labelText: 'Event / Tournament (optional)',
            prefixIcon: Icon(Icons.emoji_events_rounded,
                color: web ? WT.muted : AppTheme.textSecondary),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _notesCtrl,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: 'Notes (optional)',
            hintText: 'e.g. nervous in time pressure, played too fast...',
            prefixIcon: Icon(Icons.notes_rounded,
                color: web ? WT.muted : AppTheme.textSecondary),
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 12),
        _tagsInput(),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _pickDate,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: web ? WT.cream : AppTheme.surfaceAlt,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today_rounded,
                    color: web ? WT.muted : AppTheme.textSecondary, size: 18),
                const SizedBox(width: 12),
                Text(
                  '${_datePlayed.day}/${_datePlayed.month}/${_datePlayed.year}',
                  style: TextStyle(color: web ? WT.ink : AppTheme.textPrimary),
                ),
                const Spacer(),
                Icon(Icons.arrow_drop_down_rounded,
                    color: web ? WT.muted : AppTheme.textSecondary),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _tagsInput() {
    final web = kIsWeb;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _tagCtrl,
                decoration: InputDecoration(
                  labelText: 'Add tag (optional)',
                  prefixIcon: Icon(Icons.label_outline_rounded,
                      color: web ? WT.muted : AppTheme.textSecondary),
                ),
                onSubmitted: (v) {
                  final tag = v.trim();
                  if (tag.isNotEmpty && !_tags.contains(tag)) {
                    setState(() { _tags.add(tag); _tagCtrl.clear(); });
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(Icons.add_circle_rounded,
                  color: web ? WT.greenLt : AppTheme.primary),
              onPressed: () {
                final tag = _tagCtrl.text.trim();
                if (tag.isNotEmpty && !_tags.contains(tag)) {
                  setState(() { _tags.add(tag); _tagCtrl.clear(); });
                }
              },
            ),
          ],
        ),
        if (_tags.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _tags.map((tag) => Chip(
              label: Text(tag,
                  style: TextStyle(
                      fontSize: 12,
                      color: web ? WT.ink : AppTheme.textPrimary)),
              backgroundColor: web ? WT.cream : AppTheme.surfaceAlt,
              deleteIcon: Icon(Icons.close, size: 14,
                  color: web ? WT.muted : AppTheme.textSecondary),
              onDeleted: () => setState(() => _tags.remove(tag)),
            )).toList(),
          ),
        ],
      ],
    );
  }

  Widget _dropdown(String label, String value, List<String> items, Function(String?) onChange) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(labelText: label),
      dropdownColor: kIsWeb ? WT.white : AppTheme.surfaceAlt,
      style: TextStyle(color: kIsWeb ? WT.ink : AppTheme.textPrimary),
      items: items.map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(),
      onChanged: onChange,
    );
  }

  Widget _nullableDropdown(String label, String? value, List<String> items, Function(String?) onChange) {
    final web = kIsWeb;
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(labelText: label, hintText: 'Optional'),
      dropdownColor: web ? WT.white : AppTheme.surfaceAlt,
      style: TextStyle(color: web ? WT.ink : AppTheme.textPrimary),
      items: [
        DropdownMenuItem<String>(
          value: null,
          child: Text('— not set —',
              style: TextStyle(color: web ? WT.muted : AppTheme.textSecondary))),
        ...items.map((i) => DropdownMenuItem(value: i, child: Text(_tcLabel(i)))),
      ],
      onChanged: onChange,
    );
  }

  String _tcLabel(String tc) {
    switch (tc) {
      case 'bullet':         return '⚡ Bullet';
      case 'blitz':          return '🔥 Blitz';
      case 'rapid':          return '⏱ Rapid';
      case 'classical':      return '🏛 Classical';
      case 'correspondence': return '📅 Correspondence';
      default:               return tc;
    }
  }

  Widget _parsedPreview() {
    final web = kIsWeb;
    final data = _parsedData!;
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: web
          ? BoxDecoration(
              color: WT.white,
              border: Border(left: BorderSide(color: WT.greenLt, width: 3)),
              boxShadow: const [
                BoxShadow(color: Color(0x06000000), blurRadius: 5, offset: Offset(0, 2))
              ],
            )
          : BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.primary.withValues(alpha: 0.4)),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded,
                  color: web ? WT.greenLt : AppTheme.primary, size: 18),
              const SizedBox(width: 8),
              Text('AI Parsed Successfully',
                  style: web
                      ? WT.lora(13, color: WT.greenLt, weight: FontWeight.w600)
                      : const TextStyle(
                          color: AppTheme.primary, fontWeight: FontWeight.w600)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (web ? WT.greenLt : AppTheme.primary).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  data['parseConfidence'] ?? 'medium',
                  style: TextStyle(
                      color: web ? WT.greenLt : AppTheme.primary, fontSize: 11),
                ),
              ),
            ],
          ),
          Divider(color: web ? WT.border : AppTheme.surfaceAlt, height: 20),
          _previewRow('White', data['playerWhite'] ?? 'Unknown'),
          _previewRow('Black', data['playerBlack'] ?? 'Unknown'),
          _previewRow('Result', data['result'] ?? '*'),
          _previewRow('Moves', '${(data['moves'] as List?)?.length ?? 0} moves extracted'),
          if (data['opening'] != null) _previewRow('Opening', data['opening']),
          if (data['event'] != null)   _previewRow('Event', data['event']),
          if (data['notes'] != null && data['notes'].toString().isNotEmpty)
            _previewRow('Notes', data['notes'], isWarning: true),
        ],
      ),
    );
  }

  Widget _previewRow(String label, String value, {bool isWarning = false}) {
    final web = kIsWeb;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(label,
                style: web
                    ? WT.bodySm(12)
                    : const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: isWarning
                    ? (web ? WT.inaccuracy : AppTheme.inaccuracy)
                    : (web ? WT.ink : AppTheme.textPrimary),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton() {
    final web = kIsWeb;
    if (_parsedData == null) {
      return ElevatedButton.icon(
        onPressed: (_inputType.isEmpty || _parsing) ? null : _parseGame,
        style: web
            ? ElevatedButton.styleFrom(
                backgroundColor: WT.greenLt,
                foregroundColor: WT.white,
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              )
            : null,
        icon: _parsing
            ? const SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.auto_awesome_rounded),
        label: Text(_parsing ? 'AI is reading...' : 'Parse with AI'),
      );
    } else {
      return Column(
        children: [
          ElevatedButton.icon(
            onPressed: _saving ? null : _saveGame,
            style: web
                ? ElevatedButton.styleFrom(
                    backgroundColor: WT.greenLt,
                    foregroundColor: WT.white,
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                  )
                : null,
            icon: _saving
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save_rounded),
            label: Text(_saving ? 'Saving...' : 'Save to Library'),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => setState(() {
              _parsedData = null;
              _statusMessage = '';
            }),
            child: Text('Re-parse',
                style: TextStyle(color: web ? WT.muted : AppTheme.textSecondary)),
          ),
        ],
      );
    }
  }

  // ── Actions ───────────────────────────────────

  void _selectInputType(String type) async {
    setState(() {
      _inputType = type;
      _selectedBytes = null;
      _selectedMimeType = null;
      _fileName = '';
      _parsedData = null;
      _statusMessage = '';
    });
    if (type != 'text') await _pickFile();
  }

  bool get _isHeicFile {
    final ext = _fileName.toLowerCase().split('.').last;
    return ext == 'heic' || ext == 'heif';
  }

  Future<void> _pickFile() async {
    try {
      if (_inputType == 'image') {
        if (kIsWeb) {
          // Desktop browsers don't support camera access — use FilePicker directly
          final result = await FilePicker.pickFiles(
            type: FileType.custom,
            allowedExtensions: ['png', 'jpg', 'jpeg', 'webp', 'heic', 'heif'],
            withData: true,
          );
          if (result != null && result.files.single.bytes != null) {
            setState(() {
              _selectedBytes = result.files.single.bytes;
              _selectedMimeType = _mimeTypeOf(result.files.single.name);
              _fileName = result.files.single.name;
            });
          }
        } else {
          final picker = ImagePicker();
          final source = await showModalBottomSheet<ImageSource>(
            context: context,
            backgroundColor: AppTheme.surface,
            builder: (_) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.camera_alt_rounded, color: AppTheme.primary),
                  title: const Text('Take Photo',
                      style: TextStyle(color: AppTheme.textPrimary)),
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_rounded, color: AppTheme.primary),
                  title: const Text('Choose from Gallery',
                      style: TextStyle(color: AppTheme.textPrimary)),
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
              ],
            ),
          );
          if (source == null) return;
          final xFile = await picker.pickImage(source: source, imageQuality: 85);
          if (xFile != null) {
            final bytes = await xFile.readAsBytes();
            setState(() {
              _selectedBytes = bytes;
              _selectedMimeType = _mimeTypeOf(xFile.name);
              _fileName = xFile.name;
            });
          }
        }
      } else if (_inputType == 'pgn') {
        final result = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pgn'],
          withData: true,
        );
        if (result != null && result.files.single.bytes != null) {
          setState(() {
            _selectedBytes = result.files.single.bytes;
            _selectedMimeType = 'text/plain';
            _fileName = result.files.single.name;
          });
        }
      } else {
        final result = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'webp', 'heic', 'heif'],
          withData: true,
        );
        if (result != null && result.files.single.bytes != null) {
          setState(() {
            _selectedBytes = result.files.single.bytes;
            _selectedMimeType = _mimeTypeOf(result.files.single.name);
            _fileName = result.files.single.name;
          });
        }
      }
    } catch (e) {
      _showError('Could not select file: $e');
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _datePlayed,
      firstDate: DateTime(1990),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: kIsWeb
              ? ColorScheme.light(primary: WT.greenLt)
              : const ColorScheme.dark(primary: AppTheme.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _datePlayed = picked);
  }

  Future<void> _parseGame() async {
    setState(() {
      _parsing = true;
      _statusMessage = 'Sending to Gemini AI...';
      _parsedData = null;
    });

    try {
      Map<String, dynamic> result;

      if (_inputType == 'text') {
        if (_textCtrl.text.trim().isEmpty) {
          _showError('Please paste your game moves first.');
          return;
        }
        setState(() => _statusMessage = 'AI is reading your moves...');
        result = await GeminiService.parseTextGame(_textCtrl.text.trim());
      } else if (_inputType == 'pgn') {
        if (_selectedBytes == null) {
          _showError('Please select a PGN file first.');
          return;
        }
        setState(() => _statusMessage = 'Parsing PGN file...');
        final content = utf8.decode(_selectedBytes!);
        result = PgnParser.parse(content);
      } else {
        if (_selectedBytes == null) {
          _showError('Please select a file first.');
          return;
        }
        setState(() => _statusMessage = 'AI is reading your scoresheet...');
        result = await GeminiService.parseScoreSheetImage(
          _selectedBytes!, _selectedMimeType ?? 'image/jpeg');
      }

      setState(() {
        _parsedData = result;
        _statusMessage = 'Parsed! Review and save.';
        _parsing = false;

        if (_opponentCtrl.text.isEmpty) {
          final opp = _playerColor == 'white'
              ? result['playerBlack']
              : result['playerWhite'];
          if (opp != null && opp != 'Unknown') {
            _opponentCtrl.text = opp;
          }
        }
        if (_eventCtrl.text.isEmpty && result['event'] != null) {
          _eventCtrl.text = result['event'];
        }
      });
    } catch (e) {
      setState(() {
        _parsing = false;
        _statusMessage = '';
      });
      _showError(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _saveGame() async {
    if (_parsedData == null) return;
    setState(() {
      _saving = true;
      _statusMessage = 'Saving to your library...';
    });

    try {
      final moves = List<String>.from(_parsedData!['moves'] ?? []);
      final pgn = _parsedData!['pgn'] ?? moves.join(' ');

      final game = ChessGame(
        id: const Uuid().v4(),
        playerName: AuthService.currentUser?.displayName ?? 'Me',
        opponentName: _opponentCtrl.text.trim().isEmpty
            ? (_playerColor == 'white'
                ? _parsedData!['playerBlack'] ?? 'Unknown'
                : _parsedData!['playerWhite'] ?? 'Unknown')
            : _opponentCtrl.text.trim(),
        result: _parsedData!['result'] ?? '*',
        playerColor: _playerColor,
        moves: moves,
        pgn: pgn,
        datePlayed: _datePlayed,
        source: _source,
        event: _eventCtrl.text.trim().isNotEmpty ? _eventCtrl.text.trim() : _parsedData!['event'],
        opening: _parsedData!['opening'],
        playerRating: _parsedData!['ratingWhite'],
        opponentRating: _parsedData!['ratingBlack'],
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        tags: List<String>.from(_tags),
        timeControl: _timeControl,
      );

      await GameService.saveGame(game);

      final allGames = await GameService.getAllGames();
      final newBadges = await BadgeService.checkAndAward(allGames);
      if (mounted && newBadges.isNotEmpty) {
        _showBadgePopup(List<Badge>.from(newBadges));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Game saved! 🎉'),
            backgroundColor: kIsWeb ? WT.greenLt : AppTheme.primary,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _saving = false);
      _showError('Failed to save — please try again.');
    }
  }

  void _showBadgePopup(List<Badge> badges) {
    final web = kIsWeb;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: web ? WT.white : AppTheme.surface,
        title: Row(
          children: [
            const Text('🏅', style: TextStyle(fontSize: 24)),
            const SizedBox(width: 8),
            Text('Badge Earned!',
                style: web
                    ? WT.lora(15, color: WT.greenLt, weight: FontWeight.w700)
                    : const TextStyle(color: AppTheme.primary)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: badges.map((b) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Text(b.emoji, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(b.title,
                          style: web
                              ? WT.lora(13, color: WT.textColor, weight: FontWeight.w600)
                              : const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.w600)),
                      Text(b.description,
                          style: web
                              ? WT.bodySm(12)
                              : const TextStyle(
                                  color: AppTheme.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          )).toList(),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: web
                ? ElevatedButton.styleFrom(
                    backgroundColor: WT.greenLt,
                    foregroundColor: WT.white,
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                  )
                : null,
            child: const Text('Awesome!'),
          ),
        ],
      ),
    );
  }

  void _showError(String msg) {
    setState(() {
      _statusMessage = '';
      _parsing = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: kIsWeb ? WT.loss : AppTheme.loss,
      ),
    );
  }

  static String _mimeTypeOf(String filename) {
    final ext = filename.toLowerCase().split('.').last;
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      case 'heif':
        return 'image/heif';
      case 'pdf':
        return 'application/pdf';
      case 'pgn':
        return 'text/plain';
      default:
        return 'image/jpeg';
    }
  }
}
