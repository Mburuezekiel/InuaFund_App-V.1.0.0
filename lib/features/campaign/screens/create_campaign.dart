import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'dart:convert';

import '../../home/screens/home_screen.dart' show AppColors;

// ═══════════════════════════════════════════════════════════════════════════════
// MODELS & DATA
// ═══════════════════════════════════════════════════════════════════════════════

class CampaignFormData {
  String title = '', description = '', currency = 'KES', category = 'community';
  String campaignType = 'personal', country = 'Kenya', location = '';
  String startDate = '', endDate = '', contactEmail = '', contactPhone = '';
  String creatorId = '', username = '', collaboratorName = '', collaboratorEmail = '';
  String charityName = '';
  double goal = 0;
  List<String> tags = [];
}

class _Item { final String code, name; const _Item(this.code, this.name); }
class _Cat  { final String value, label; final IconData icon; final Color color;
              const _Cat(this.value, this.label, this.icon, this.color); }
class _Type { final String value, label, desc; final IconData icon;
              const _Type(this.value, this.label, this.desc, this.icon); }

const kLocations = [
  _Item('047','Nairobi'),  _Item('001','Mombasa'),  _Item('003','Kilifi'),
  _Item('042','Kisumu'),   _Item('032','Nakuru'),   _Item('022','Kiambu'),
  _Item('016','Machakos'), _Item('019','Nyeri'),    _Item('012','Meru'),
  _Item('014','Embu'),     _Item('037','Kakamega'), _Item('027','Uasin Gishu'),
  _Item('045','Kisii'),    _Item('039','Bungoma'),  _Item('035','Kericho'),
  _Item('021','Muranga'),  _Item('020','Kirinyaga'),_Item('044','Migori'),
  _Item('043','Homa Bay'), _Item('031','Laikipia'), _Item('033','Narok'),
  _Item('034','Kajiado'),  _Item('023','Turkana'),  _Item('007','Garissa'),
  _Item('008','Wajir'),    _Item('002','Kwale'),    _Item('004','Tana River'),
  _Item('005','Lamu'),     _Item('006','Taita Taveta'), _Item('009','Mandera'),
  _Item('010','Marsabit'), _Item('011','Isiolo'),   _Item('013','Tharaka Nithi'),
  _Item('015','Kitui'),    _Item('017','Makueni'),  _Item('018','Nyandarua'),
  _Item('024','West Pokot'),_Item('025','Samburu'), _Item('026','Trans Nzoia'),
  _Item('028','Elgeyo Marakwet'),_Item('029','Nandi'),_Item('030','Baringo'),
  _Item('036','Bomet'),    _Item('038','Vihiga'),   _Item('040','Busia'),
  _Item('041','Siaya'),    _Item('046','Nyamira'),
];

const kCategories = [
  _Cat('medical','Healthcare',Icons.favorite_rounded,Color(0xFFD93025)),
  _Cat('education','Education',Icons.school_rounded,Color(0xFF1565C0)),
  _Cat('community','Community',Icons.people_rounded,Color(0xFF6A1B9A)),
  _Cat('emergencies','Emergencies',Icons.warning_amber_rounded,Color(0xFFB71C1C)),
  _Cat('water','Water',Icons.water_drop_rounded,Color(0xFF006064)),
  _Cat('environment','Environment',Icons.eco_rounded,Color(0xFF1B5E20)),
  _Cat('agriculture','Agriculture',Icons.grass_rounded,Color(0xFF33691E)),
  _Cat('animals','Animals',Icons.pets_rounded,Color(0xFFE65100)),
  _Cat('business','Business',Icons.business_center_rounded,Color(0xFFF9A825)),
  _Cat('creative','Creative',Icons.palette_rounded,Color(0xFFAD1457)),
  _Cat('technology','Technology',Icons.computer_rounded,Color(0xFF283593)),
  _Cat('nonprofit','Non-Profit',Icons.volunteer_activism_rounded,Color(0xFF2E7D32)),
  _Cat('events','Events',Icons.event_rounded,Color(0xFF00838F)),
  _Cat('faith','Faith',Icons.church_rounded,Color(0xFF455A64)),
  _Cat('family','Family',Icons.family_restroom_rounded,Color(0xFF6A1B9A)),
  _Cat('travel','Travel',Icons.flight_rounded,Color(0xFF0277BD)),
  _Cat('arts','Arts & Culture',Icons.museum_rounded,Color(0xFF880E4F)),
  _Cat('volunteer','Volunteer',Icons.handshake_rounded,Color(0xFF558B2F)),
  _Cat('memorial','Memorials',Icons.local_florist_rounded,Color(0xFF546E7A)),
  _Cat('wishes','Wishes',Icons.auto_awesome_rounded,Color(0xFFF57F17)),
];

const kTypes = [
  _Type('personal','Yourself','Funds go to your bank account',Icons.person_rounded),
  _Type('someone-else','Someone Else','Beneficiary receives the funds directly',Icons.people_rounded),
  _Type('charity','Charity','Funds go to your chosen non-profit',Icons.volunteer_activism_rounded),
];

const kCurrencies = ['KES','UGX','TZS','ETB','GHS','NGN','ZAR','RWF','XOF','MAD'];

// ═══════════════════════════════════════════════════════════════════════════════
// SERVICE
// ═══════════════════════════════════════════════════════════════════════════════

class CampaignService {
  static Future<void> create({
    required CampaignFormData data, required File? featuredImage,
    required List<File> gallery, required String token,
  }) async {
    final req = http.MultipartRequest('POST', Uri.parse('https://api.inuafund.co.ke/api/campaigns'))
      ..headers.addAll({'Accept':'application/json', if (token.isNotEmpty) 'Authorization':'Bearer $token'})
      ..fields.addAll({
        'title': data.title, 'description': data.description, 'goal': data.goal.toString(),
        'currency': data.currency, 'category': data.category, 'campaignType': data.campaignType,
        'country': data.country, 'location': data.location, 'zipCode': data.location,
        'startDate': data.startDate, 'endDate': data.endDate, 'status': 'pending',
        'amountRaised': '0', 'contactEmail': data.contactEmail, 'contactPhone': data.contactPhone,
        'creator_Id': data.creatorId, 'username': data.username,
        if (data.campaignType == 'someone-else') ...{
          'collaboratorName': data.collaboratorName, 'collaboratorEmail': data.collaboratorEmail,
        },
        if (data.campaignType == 'charity') 'charityName': data.charityName,
      });

    for (var i = 0; i < data.tags.length; i++) req.fields['tags[$i]'] = data.tags[i];
    if (featuredImage != null) req.files.add(await http.MultipartFile.fromPath('featuredImage', featuredImage.path));
    for (final f in gallery) req.files.add(await http.MultipartFile.fromPath('galleryImages', f.path));

    final streamed = await req.send().timeout(const Duration(seconds: 30));
    final body = await streamed.stream.bytesToString();
    final decoded = json.decode(body) as Map<String, dynamic>;
    if (streamed.statusCode != 200 && streamed.statusCode != 201) {
      throw Exception(decoded['message'] ?? 'Failed to create campaign');
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SCREEN
// ═══════════════════════════════════════════════════════════════════════════════

enum _Step { details, media, type, location, category, funding, contact, preview }
enum _Status { idle, loading, success, error }

const _stepMeta = <_Step, Map<String,dynamic>>{
  _Step.details:  {'title':'Campaign Details',    'desc':'Give your campaign a name and story','icon':Icons.edit_note_rounded},
  _Step.media:    {'title':'Campaign Media',      'desc':'Add images to showcase your cause',  'icon':Icons.photo_library_rounded},
  _Step.type:     {'title':'Fundraising Focus',   'desc':'Who are you raising funds for?',     'icon':Icons.track_changes_rounded},
  _Step.location: {'title':'Campaign Location',   'desc':'Where will funds be withdrawn?',     'icon':Icons.location_on_rounded},
  _Step.category: {'title':'Campaign Purpose',    'desc':'What best describes your goal?',     'icon':Icons.category_rounded},
  _Step.funding:  {'title':'Funding Goal',        'desc':'Set your fundraising target',        'icon':Icons.attach_money_rounded},
  _Step.contact:  {'title':'Contact Information', 'desc':'How can donors reach you?',          'icon':Icons.contact_mail_rounded},
  _Step.preview:  {'title':'Campaign Preview',    'desc':'Review before submitting',           'icon':Icons.visibility_rounded},
};

class StartCampaignScreen extends StatefulWidget {
  final bool isDark;
  final String authToken, userId, username, userEmail, userPhone;
  const StartCampaignScreen({
    super.key, this.isDark = false, this.authToken = '',
    this.userId = '', this.username = '', this.userEmail = '', this.userPhone = '',
  });
  @override State<StartCampaignScreen> createState() => _State();
}

class _State extends State<StartCampaignScreen> with TickerProviderStateMixin {
  int _stepIdx = 0;
  final _form = CampaignFormData();
  final _errors = <String, String>{};
  bool _agreedToTerms = false;

  // ── FIX: Single source of truth for submission status ──────────────────────
  final _statusNotifier = ValueNotifier(_Status.idle);

  File? _featuredImage;
  final List<File> _gallery = [];

  final _tagCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _goalCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _collNameCtrl = TextEditingController();
  final _collEmailCtrl = TextEditingController();
  final _charityCtrl = TextEditingController();
  final _startDateCtrl = TextEditingController();
  final _endDateCtrl = TextEditingController();

  late final AnimationController _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 320))..value = 1;
  late final AnimationController _slideCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
  late final Animation<Offset> _slideAnim = Tween<Offset>(begin: const Offset(0.08,0), end: Offset.zero)
      .animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));

  final _steps = _Step.values;

  Color get bg      => widget.isDark ? AppColors.darkBg    : AppColors.snow;
  Color get surface => widget.isDark ? AppColors.darkCard  : AppColors.white;
  Color get border  => widget.isDark ? AppColors.darkBorder: AppColors.cloud;
  Color get txt1    => widget.isDark ? AppColors.white     : AppColors.ink;
  Color get txt2    => widget.isDark ? AppColors.mist      : const Color(0xFF6B7280);

  @override
  void initState() {
    super.initState();
    _form
      ..contactEmail = widget.userEmail
      ..contactPhone = widget.userPhone
      ..creatorId = widget.userId
      ..username = widget.username;
    _emailCtrl.text = widget.userEmail;
    _phoneCtrl.text = widget.userPhone;
    _slideCtrl.forward();
  }

  @override
  void dispose() {
    _statusNotifier.dispose();
    for (final c in [_fadeCtrl, _slideCtrl, _tagCtrl, _titleCtrl, _descCtrl,
        _goalCtrl, _emailCtrl, _phoneCtrl, _collNameCtrl, _collEmailCtrl,
        _charityCtrl, _startDateCtrl, _endDateCtrl]) { c.dispose(); }
    super.dispose();
  }

  // ── Navigation ─────────────────────────────────────────────────────────────
  Future<void> _next() async {
    if (!_validate()) return;
    if (_stepIdx == _steps.length - 1) { _submit(); return; }
    await _animateStep();
    setState(() => _stepIdx++);
  }

  Future<void> _back() async {
    if (_stepIdx == 0) { Navigator.pop(context); return; }
    await _animateStep();
    setState(() => _stepIdx--);
  }

  Future<void> _animateStep() async {
    _fadeCtrl.reverse(); _slideCtrl.reset();
    await Future.delayed(const Duration(milliseconds: 120));
    _fadeCtrl.forward(); _slideCtrl.forward();
  }

  // ── Validation ─────────────────────────────────────────────────────────────
  bool _validate() {
    final e = <String,String>{};
    switch (_steps[_stepIdx]) {
      case _Step.details:
        if (_form.title.trim().isEmpty) e['title'] = 'Campaign title is required';
        if (_form.description.trim().isEmpty) e['desc'] = 'Description is required';
      case _Step.media:
        if (_featuredImage == null) e['featured'] = 'Please add a featured image';
        if (_gallery.isEmpty) e['gallery'] = 'Add at least one gallery image';
      case _Step.type:
        if (_form.campaignType == 'someone-else') {
          if (_form.collaboratorName.trim().isEmpty) e['collName'] = 'Collaborator name required';
          if (_form.collaboratorEmail.trim().isEmpty) e['collEmail'] = 'Collaborator email required';
        } else if (_form.campaignType == 'charity') {
          if (_form.charityName.trim().isEmpty) e['charity'] = 'Charity name required';
        }
      case _Step.location:
        if (_form.location.isEmpty) e['location'] = 'Please select a county';
      case _Step.category:
        if (_form.category.isEmpty) e['category'] = 'Please select a category';
      case _Step.funding:
        if (_form.goal <= 0) e['goal'] = 'Please enter a valid funding goal';
        if (_form.startDate.isEmpty) e['startDate'] = 'Please set a start date';
      case _Step.contact:
        if (_form.contactEmail.trim().isEmpty) e['email'] = 'Contact email is required';
        if (_form.contactPhone.trim().isEmpty) e['phone'] = 'Contact phone is required';
      case _Step.preview:
        if (!_agreedToTerms) e['terms'] = 'Please accept the terms and conditions';
    }
    setState(() => _errors..clear()..addAll(e));
    return e.isEmpty;
  }

  // ── Submit — FIX: update the notifier, not a separate local field ──────────
  Future<void> _submit() async {
    _statusNotifier.value = _Status.loading;
    _showSubmissionDialog();
    try {
      await CampaignService.create(
        data: _form, featuredImage: _featuredImage,
        gallery: _gallery, token: widget.authToken,
      );
      _statusNotifier.value = _Status.success;
      await Future.delayed(const Duration(milliseconds: 2200));
      if (mounted) Navigator.pop(context);
    } catch (_) {
      _statusNotifier.value = _Status.error;
    }
  }

  void _showSubmissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _SubmitDialog(
        notifier: _statusNotifier,
        onClose: () { Navigator.pop(context); _statusNotifier.value = _Status.idle; },
      ),
    );
  }

  // ── Image picking ──────────────────────────────────────────────────────────
  Future<void> _pickFeatured() async {
    final p = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 1200);
    if (p != null) setState(() { _featuredImage = File(p.path); _errors.remove('featured'); });
  }

  Future<void> _pickGallery() async {
    final picked = await ImagePicker().pickMultiImage(imageQuality: 75, maxWidth: 800);
    if (picked.isNotEmpty) {
      final toAdd = picked.take(5 - _gallery.length).map((x) => File(x.path)).toList();
      setState(() { _gallery.addAll(toAdd); _errors.remove('gallery'); });
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final meta = _stepMeta[_steps[_stepIdx]]!;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      color: bg,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(child: Column(children: [
          _appBar(meta),
          _stepDots(),
          _progressRow(),
          Expanded(child: FadeTransition(opacity: _fadeCtrl,
            child: SlideTransition(position: _slideAnim, child: _stepContent()))),
          _footer(),
        ])),
      ),
    );
  }

  Widget _appBar(Map<String,dynamic> meta) => Padding(
    padding: const EdgeInsets.fromLTRB(16,12,16,0),
    child: Row(children: [
      GestureDetector(onTap: _back,
        child: _box(width: 42, height: 42, child: Icon(Icons.arrow_back_ios_new_rounded, color: txt1, size: 18))),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(meta['title'] as String, style: TextStyle(fontFamily:'Poppins', fontWeight:FontWeight.w800, fontSize:18, color:txt1, letterSpacing:-0.3)),
        Text(meta['desc'] as String, style: TextStyle(fontFamily:'Poppins', fontSize:12, color:txt2)),
      ])),
      Container(
        padding: const EdgeInsets.symmetric(horizontal:12, vertical:6),
        decoration: BoxDecoration(color: AppColors.midGreen.withOpacity(0.12), borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.midGreen.withOpacity(0.25))),
        child: Text('${_stepIdx+1} / ${_steps.length}',
          style: const TextStyle(fontFamily:'Poppins', fontWeight:FontWeight.w700, fontSize:12, color:AppColors.midGreen)),
      ),
    ]),
  );

  Widget _stepDots() => Padding(
    padding: const EdgeInsets.fromLTRB(16,14,16,0),
    child: Row(children: List.generate(_steps.length, (i) {
      final done = i < _stepIdx, cur = i == _stepIdx;
      return Expanded(child: GestureDetector(
        onTap: done ? () async { await _animateStep(); setState(() => _stepIdx = i); } : null,
        child: AnimatedContainer(duration: const Duration(milliseconds:250),
          margin: const EdgeInsets.symmetric(horizontal:2), height:6,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(4),
            color: done ? AppColors.midGreen : cur ? AppColors.limeGreen : border)),
      ));
    })),
  );

  Widget _progressRow() => Padding(
    padding: const EdgeInsets.fromLTRB(16,8,16,0),
    child: Row(children: [
      Text('${(_stepIdx / (_steps.length-1) * 100).round()}% complete',
        style: TextStyle(fontFamily:'Poppins', fontSize:11, color:txt2)),
      const Spacer(),
      Icon(_stepMeta[_steps[_stepIdx]]!['icon'] as IconData, color: AppColors.midGreen, size:16),
    ]),
  );

  Widget _stepContent() => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(16,16,16,8),
    physics: const BouncingScrollPhysics(),
    child: _buildStep(),
  );

  Widget _buildStep() {
    switch (_steps[_stepIdx]) {
      case _Step.details:  return _detailsStep();
      case _Step.media:    return _mediaStep();
      case _Step.type:     return _typeStep();
      case _Step.location: return _locationStep();
      case _Step.category: return _categoryStep();
      case _Step.funding:  return _fundingStep();
      case _Step.contact:  return _contactStep();
      case _Step.preview:  return _previewStep();
    }
  }

  // ── Steps ──────────────────────────────────────────────────────────────────

  Widget _detailsStep() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const _Label('Campaign Title', req: true),
    _Field(ctrl: _titleCtrl, hint: 'E.g. Help Mama Wanjiku with Cancer Treatment',
      error: _errors['title'], maxLength: 100,
      onChange: (v) { _form.title = v; _errors.remove('title'); setState((){}); }),
    const SizedBox(height:18),
    const _Label('Your Story', req: true),
    _TextArea(ctrl: _descCtrl, hint: 'Tell donors why this campaign matters...',
      error: _errors['desc'],
      onChange: (v) { _form.description = v; _errors.remove('desc'); setState((){}); }),
    const SizedBox(height:18),
    Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _Label('Start Date', req: true),
        _DatePick(ctrl: _startDateCtrl, hint: 'YYYY-MM-DD', error: _errors['startDate'], onPick: () => _pickDate(isStart: true)),
      ])),
      const SizedBox(width:12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _Label('End Date'),
        _DatePick(ctrl: _endDateCtrl, hint: 'YYYY-MM-DD', onPick: () => _pickDate(isStart: false)),
      ])),
    ]),
    const SizedBox(height:18),
    const _Label('Tags'),
    _TagsInput(tags: _form.tags, ctrl: _tagCtrl, surface: surface, border: border, txt1: txt1, txt2: txt2,
      onAdd: (v) => setState(() { if (!_form.tags.contains(v)) _form.tags.add(v); }),
      onRemove: (v) => setState(() => _form.tags.remove(v))),
  ]);

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: now.add(Duration(days: isStart ? 1 : 30)),
      firstDate: now.add(Duration(days: isStart ? 1 : 7)),
      lastDate: now.add(const Duration(days: 730)),
      builder: (ctx, child) => Theme(data: ThemeData.light().copyWith(
        colorScheme: const ColorScheme.light(primary: AppColors.midGreen, onPrimary: Colors.white, surface: Colors.white)), child: child!),
    );
    if (d != null) {
      final s = '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
      setState(() {
        if (isStart) { _form.startDate = s; _startDateCtrl.text = s; _errors.remove('startDate'); }
        else { _form.endDate = s; _endDateCtrl.text = s; }
      });
    }
  }

  Widget _mediaStep() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _Card(surface: surface, border: border, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _Label('Featured Image', req: true),
      const SizedBox(height:8),
      _featuredImage == null
          ? _PickerPlaceholder(icon: Icons.add_photo_alternate_rounded, label: 'Tap to add featured image',
              sub: 'Recommended: 1200×630 px', onTap: _pickFeatured, border: border, txt2: txt2)
          : _FeaturedPreview(file: _featuredImage!, onRemove: () => setState(() => _featuredImage = null)),
      if (_errors['featured'] != null) _Err(_errors['featured']!),
    ])),
    const SizedBox(height:16),
    _Card(surface: surface, border: border, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const _Label('Gallery Images'),
        const Spacer(),
        Text('${_gallery.length}/5', style: TextStyle(fontFamily:'Poppins', fontSize:12, color:txt2)),
      ]),
      const SizedBox(height:10),
      if (_gallery.isNotEmpty) _GalleryGrid(files: _gallery, onRemove: (i) => setState(() => _gallery.removeAt(i))),
      if (_gallery.length < 5) ...[
        const SizedBox(height:10),
        _PickerPlaceholder(icon: Icons.add_to_photos_rounded,
          label: _gallery.isEmpty ? 'Add gallery images' : 'Add more images',
          sub: '${5-_gallery.length} remaining • Max 5MB each',
          onTap: _pickGallery, border: border, txt2: txt2, compact: _gallery.isNotEmpty),
      ],
      if (_errors['gallery'] != null) _Err(_errors['gallery']!),
    ])),
  ]);

  Widget _typeStep() => Column(children: [
    ...kTypes.map((t) {
      final sel = _form.campaignType == t.value;
      return GestureDetector(
        onTap: () => setState(() { _form.campaignType = t.value; _errors.remove('type'); }),
        child: AnimatedContainer(duration: const Duration(milliseconds:200),
          margin: const EdgeInsets.only(bottom:12), padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: sel ? AppColors.midGreen.withOpacity(0.08) : surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: sel ? AppColors.midGreen : border, width: sel ? 2 : 1),
            boxShadow: sel ? [BoxShadow(color: AppColors.midGreen.withOpacity(0.15), blurRadius:12, offset: const Offset(0,4))] : [],
          ),
          child: Row(children: [
            AnimatedContainer(duration: const Duration(milliseconds:200),
              width:52, height:52,
              decoration: BoxDecoration(shape: BoxShape.circle,
                color: sel ? AppColors.midGreen : AppColors.midGreen.withOpacity(0.1)),
              child: Icon(t.icon, color: sel ? Colors.white : AppColors.midGreen, size:26)),
            const SizedBox(width:16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t.label, style: TextStyle(fontFamily:'Poppins', fontWeight:FontWeight.w800, fontSize:15, color: sel ? AppColors.midGreen : txt1)),
              const SizedBox(height:3),
              Text(t.desc, style: TextStyle(fontFamily:'Poppins', fontSize:12, color:txt2)),
            ])),
            if (sel) const Icon(Icons.check_circle_rounded, color:AppColors.midGreen, size:22),
          ]),
        ),
      );
    }),
    if (_form.campaignType == 'someone-else') ...[
      const SizedBox(height:8),
      _Card(surface: surface, border: border, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Collaborator Details', style: TextStyle(fontFamily:'Poppins', fontWeight:FontWeight.w700, fontSize:14, color:txt1)),
        const SizedBox(height:12),
        const _Label('Name'),
        _Field(ctrl: _collNameCtrl, hint: 'Full name', error: _errors['collName'],
          onChange: (v) { _form.collaboratorName = v; _errors.remove('collName'); setState((){}); }),
        const SizedBox(height:12),
        const _Label('Email'),
        _Field(ctrl: _collEmailCtrl, hint: 'email@example.com', error: _errors['collEmail'],
          kbType: TextInputType.emailAddress,
          onChange: (v) { _form.collaboratorEmail = v; _errors.remove('collEmail'); setState((){}); }),
      ])),
    ],
    if (_form.campaignType == 'charity') ...[
      const SizedBox(height:8),
      _Card(surface: surface, border: border, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Charity Details', style: TextStyle(fontFamily:'Poppins', fontWeight:FontWeight.w700, fontSize:14, color:txt1)),
        const SizedBox(height:12),
        const _Label('Charity / Organisation Name'),
        _Field(ctrl: _charityCtrl, hint: 'E.g. Red Cross Kenya', error: _errors['charity'],
          onChange: (v) { _form.charityName = v; _errors.remove('charity'); setState((){}); }),
      ])),
    ],
  ]);

  Widget _locationStep() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _Banner(icon: Icons.info_outline_rounded, text: 'Select the county where funds will be withdrawn.', txt2: txt2),
    const SizedBox(height:18),
    const _Label('County / Location', req: true),
    _Dropdown<String>(
      value: _form.location.isEmpty ? null : _form.location, hint: 'Select county',
      items: kLocations.map((l) => DropdownMenuItem(value: l.code,
        child: Text(l.name, style: const TextStyle(fontFamily:'Poppins', fontSize:14)))).toList(),
      surface: surface, border: border, txt1: txt1, error: _errors['location'],
      onChange: (v) => setState(() { _form.location = v ?? ''; _errors.remove('location'); }),
    ),
    const SizedBox(height:18),
    const _Label('Country'),
    Container(height:50, padding: const EdgeInsets.symmetric(horizontal:16),
      decoration: BoxDecoration(color: border.withOpacity(0.4), borderRadius: BorderRadius.circular(13), border: Border.all(color:border)),
      alignment: Alignment.centerLeft,
      child: Row(children: [
        const Text('🇰🇪', style: TextStyle(fontSize:20)),
        const SizedBox(width:10),
        Text('Kenya', style: TextStyle(fontFamily:'Poppins', fontWeight:FontWeight.w600, fontSize:14, color:txt1)),
      ])),
  ]);

  Widget _categoryStep() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Wrap(spacing:10, runSpacing:10, children: kCategories.map((cat) {
      final sel = _form.category == cat.value;
      return GestureDetector(
        onTap: () => setState(() { _form.category = cat.value; _errors.remove('category'); }),
        child: AnimatedContainer(duration: const Duration(milliseconds:180),
          padding: const EdgeInsets.symmetric(horizontal:14, vertical:10),
          decoration: BoxDecoration(
            color: sel ? cat.color : surface,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: sel ? cat.color : border, width: sel ? 0 : 1),
            boxShadow: sel ? [BoxShadow(color: cat.color.withOpacity(0.28), blurRadius:8, offset: const Offset(0,3))] : [],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(cat.icon, size:15, color: sel ? Colors.white : cat.color),
            const SizedBox(width:7),
            Text(cat.label, style: TextStyle(fontFamily:'Poppins', fontWeight:FontWeight.w600, fontSize:13, color: sel ? Colors.white : txt1)),
          ])),
      );
    }).toList()),
    if (_errors['category'] != null) ...[const SizedBox(height:10), _Err(_errors['category']!)],
  ]);

  Widget _fundingStep() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const _Label('Fundraising Goal', req: true),
    Row(children: [
      _Dropdown<String>(
        value: _form.currency, hint: 'KES', width: 90,
        items: kCurrencies.map((c) => DropdownMenuItem(value: c,
          child: Text(c, style: const TextStyle(fontFamily:'Poppins', fontSize:13, fontWeight:FontWeight.w600)))).toList(),
        surface: surface, border: border, txt1: txt1,
        onChange: (v) => setState(() => _form.currency = v ?? 'KES'),
      ),
      const SizedBox(width:10),
      Expanded(child: _Field(ctrl: _goalCtrl, hint: '0.00',
        kbType: const TextInputType.numberWithOptions(decimal:true),
        formatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
        error: _errors['goal'],
        onChange: (v) { _form.goal = double.tryParse(v) ?? 0; _errors.remove('goal'); setState((){}); })),
    ]),
    if (_form.goal > 0) ...[
      const SizedBox(height:20),
      Container(padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors:[AppColors.forestGreen, AppColors.midGreen], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: AppColors.midGreen.withOpacity(0.3), blurRadius:16, offset: const Offset(0,6))],
        ),
        child: Row(children: [
          const Icon(Icons.savings_rounded, color:Colors.white70, size:36),
          const SizedBox(width:14),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Fundraising Goal', style:TextStyle(fontFamily:'Poppins', fontSize:11, color:Colors.white70)),
            Text('${_form.currency} ${_fmtGoal(_form.goal)}',
              style: const TextStyle(fontFamily:'Poppins', fontWeight:FontWeight.w900, fontSize:26, color:Colors.white, letterSpacing:-0.5)),
          ]),
        ])),
    ],
    const SizedBox(height:20),
    _Banner(icon: Icons.tips_and_updates_rounded,
      text: 'Set a realistic goal. You can always raise more — over-funding is allowed!',
      txt2: txt2, color: AppColors.savanna.withOpacity(0.1), iconColor: AppColors.savanna),
  ]);

  Widget _contactStep() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _Card(surface: surface, border: border, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.account_circle_rounded, color:AppColors.midGreen, size:20),
        const SizedBox(width:8),
        Text('Campaign Creator', style: TextStyle(fontFamily:'Poppins', fontWeight:FontWeight.w700, fontSize:14, color:txt1)),
      ]),
      const SizedBox(height:12),
      Row(children: [
        _Chip(label:'Username', value: _form.username.isEmpty ? 'N/A' : _form.username, surface:border, txt1:txt1, txt2:txt2),
        const SizedBox(width:10),
        _Chip(label:'User ID',
          value: _form.creatorId.length > 8 ? '${_form.creatorId.substring(0,5)}…${_form.creatorId.substring(_form.creatorId.length-4)}' : _form.creatorId.isEmpty ? 'N/A' : _form.creatorId,
          surface:border, txt1:txt1, txt2:txt2),
      ]),
    ])),
    const SizedBox(height:16),
    const _Label('Contact Email', req: true),
    _Field(ctrl: _emailCtrl, hint: 'your@email.com', kbType: TextInputType.emailAddress,
      prefix: Icons.mail_outline_rounded, error: _errors['email'],
      onChange: (v) { _form.contactEmail = v; _errors.remove('email'); setState((){}); }),
    const SizedBox(height:14),
    const _Label('Contact Phone', req: true),
    _Field(ctrl: _phoneCtrl, hint: '+254 7XX XXX XXX', kbType: TextInputType.phone,
      prefix: Icons.phone_outlined, error: _errors['phone'],
      onChange: (v) { _form.contactPhone = v; _errors.remove('phone'); setState((){}); }),
  ]);

  Widget _previewStep() {
    final cat = kCategories.firstWhere((c) => c.value == _form.category, orElse: () => kCategories[0]);
    final loc = kLocations.firstWhere((l) => l.code == _form.location, orElse: () => const _Item('','N/A'));
    final type = kTypes.firstWhere((t) => t.value == _form.campaignType);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (_featuredImage != null) ClipRRect(borderRadius: BorderRadius.circular(18),
        child: AspectRatio(aspectRatio:16/9, child: Stack(children: [
          Image.file(_featuredImage!, fit:BoxFit.cover, width:double.infinity),
          Positioned.fill(child: Container(decoration: BoxDecoration(gradient: LinearGradient(
            colors:[Colors.transparent, Colors.black.withOpacity(0.4)],
            begin: Alignment.topCenter, end: Alignment.bottomCenter)))),
          Positioned(bottom:14, left:14, child: Row(children: [
            _Badge(cat.label, cat.color), const SizedBox(width:8), _Badge(type.label, AppColors.forestGreen),
          ])),
        ]))),
      const SizedBox(height:16),
      if (_gallery.isNotEmpty) SizedBox(height:70, child: ListView.separated(
        scrollDirection: Axis.horizontal, itemCount: _gallery.length,
        separatorBuilder: (_,__) => const SizedBox(width:8),
        itemBuilder: (_, i) => ClipRRect(borderRadius: BorderRadius.circular(10),
          child: Image.file(_gallery[i], width:70, height:70, fit:BoxFit.cover)),
      )),
      const SizedBox(height:16),
      _Card(surface: surface, border: border, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_form.title.isEmpty ? 'Untitled Campaign' : _form.title,
          style: TextStyle(fontFamily:'Poppins', fontWeight:FontWeight.w900, fontSize:18, color:txt1, letterSpacing:-0.3)),
        const SizedBox(height:8),
        if (_form.description.isNotEmpty) Text(_form.description, maxLines:3, overflow:TextOverflow.ellipsis,
          style: TextStyle(fontFamily:'Poppins', fontSize:13, color:txt2, height:1.5)),
        const SizedBox(height:16),
        _PreviewRow('Goal','${_form.currency} ${_form.goal > 0 ? _fmtGoal(_form.goal) : "Not set"}',Icons.attach_money_rounded,txt1,txt2),
        _PreviewRow('Location','${loc.name}, Kenya',Icons.location_on_rounded,txt1,txt2),
        _PreviewRow('Category',cat.label,cat.icon,txt1,txt2),
        _PreviewRow('Type',type.label,type.icon,txt1,txt2),
        _PreviewRow('Contact',_form.contactEmail,Icons.mail_outline_rounded,txt1,txt2),
        if (_form.tags.isNotEmpty) ...[
          const SizedBox(height:10),
          Wrap(spacing:6, runSpacing:6, children: _form.tags.map((t) => Container(
            padding: const EdgeInsets.symmetric(horizontal:10, vertical:4),
            decoration: BoxDecoration(color: AppColors.midGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
            child: Text(t, style: const TextStyle(fontFamily:'Poppins', fontSize:11, fontWeight:FontWeight.w600, color:AppColors.midGreen)),
          )).toList()),
        ],
      ])),
      const SizedBox(height:16),
      GestureDetector(
        onTap: () => setState(() => _agreedToTerms = !_agreedToTerms),
        child: AnimatedContainer(duration: const Duration(milliseconds:200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _agreedToTerms ? AppColors.midGreen.withOpacity(0.08) : surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _agreedToTerms ? AppColors.midGreen : border, width: _agreedToTerms ? 1.5 : 1),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            AnimatedContainer(duration: const Duration(milliseconds:200),
              width:24, height:24,
              decoration: BoxDecoration(shape: BoxShape.circle,
                color: _agreedToTerms ? AppColors.midGreen : Colors.transparent,
                border: Border.all(color: _agreedToTerms ? AppColors.midGreen : border, width:2)),
              child: _agreedToTerms ? const Icon(Icons.check_rounded, color:Colors.white, size:14) : null),
            const SizedBox(width:12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Accept terms and conditions', style: TextStyle(fontFamily:'Poppins', fontWeight:FontWeight.w700, fontSize:13, color:txt1)),
              const SizedBox(height:3),
              Text('I agree to the terms of service and privacy policy. My campaign will be reviewed before going live.',
                style: TextStyle(fontFamily:'Poppins', fontSize:12, color:txt2, height:1.4)),
            ])),
          ])),
      ),
      if (_errors['terms'] != null) ...[const SizedBox(height:6), _Err(_errors['terms']!)],
    ]);
  }

  String _fmtGoal(double v) {
    if (v >= 1000000) return '${(v/1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v/1000).toStringAsFixed(0)}K';
    return v.toStringAsFixed(0);
  }

  Widget _footer() {
    final isLast = _stepIdx == _steps.length - 1;
    return Container(
      padding: const EdgeInsets.fromLTRB(16,12,16,20),
      decoration: BoxDecoration(color: surface, border: Border(top: BorderSide(color:border, width:0.8)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius:16, offset: const Offset(0,-4))]),
      child: Row(children: [
        if (_stepIdx > 0) ...[
          GestureDetector(onTap: _back,
            child: Container(height:52, padding: const EdgeInsets.symmetric(horizontal:18),
              decoration: BoxDecoration(color:surface, borderRadius: BorderRadius.circular(14), border: Border.all(color:border)),
              child: Row(children: [
                Icon(Icons.arrow_back_ios_new_rounded, size:16, color:txt1),
                const SizedBox(width:6),
                Text('Back', style: TextStyle(fontFamily:'Poppins', fontWeight:FontWeight.w700, fontSize:13, color:txt1)),
              ]))),
          const SizedBox(width:12),
        ],
        Expanded(child: _GradientBtn(
          label: isLast ? 'Create Campaign 🚀' : 'Continue',
          icon: isLast ? Icons.check_circle_rounded : Icons.arrow_forward_ios_rounded,
          onTap: _next,
          disabled: isLast && !_agreedToTerms,
        )),
      ]),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  Widget _box({required double width, required double height, required Widget child}) => Container(
    width: width, height: height,
    decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(12), border: Border.all(color:border)),
    child: Center(child: child),
  );
}

extension on Listenable {
  void dispose() {}
}

// ═══════════════════════════════════════════════════════════════════════════════
// SUBMISSION DIALOG — FIX: ValueListenableBuilder drives rebuilds correctly
// ═══════════════════════════════════════════════════════════════════════════════

class _SubmitDialog extends StatefulWidget {
  final ValueNotifier<_Status> notifier;
  final VoidCallback onClose;
  const _SubmitDialog({required this.notifier, required this.onClose});
  @override State<_SubmitDialog> createState() => _SubmitDialogState();
}

class _SubmitDialogState extends State<_SubmitDialog> with TickerProviderStateMixin {
  late final AnimationController _ripple = AnimationController(vsync: this, duration: const Duration(milliseconds:1200))..repeat();
  late final AnimationController _scale = AnimationController(vsync: this, duration: const Duration(milliseconds:400), value: 0)..forward();
  @override void dispose() { _ripple.dispose(); _scale.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.transparent,
    child: ScaleTransition(scale: CurvedAnimation(parent: _scale, curve: Curves.elasticOut),
      child: Container(padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius:40, offset: const Offset(0,12))]),
        // ── FIX: ValueListenableBuilder ensures dialog rebuilds when status changes
        child: ValueListenableBuilder<_Status>(
          valueListenable: widget.notifier,
          builder: (_, status, __) => Column(mainAxisSize: MainAxisSize.min, children: [
            if (status == _Status.loading) _loadingWidget()
            else if (status == _Status.success) _successWidget()
            else _errorWidget(),
          ]),
        ),
      )),
  );

  Widget _loadingWidget() => Column(children: [
    SizedBox(width:90, height:90, child: AnimatedBuilder(animation: _ripple,
      builder: (_, __) => Stack(alignment: Alignment.center, children: [
        ...List.generate(3, (i) {
          final val = (_ripple.value - i*0.33).clamp(0.0, 1.0);
          return Opacity(opacity: (1-val)*0.4, child: Transform.scale(scale: 0.3+val*0.7,
            child: Container(decoration: BoxDecoration(shape:BoxShape.circle, color:AppColors.midGreen.withOpacity(0.15)))));
        }),
        Container(width:64, height:64,
          decoration: const BoxDecoration(shape:BoxShape.circle, gradient:LinearGradient(colors:[AppColors.forestGreen, AppColors.limeGreen])),
          child: const Icon(Icons.upload_rounded, color:Colors.white, size:30)),
      ]))),
    const SizedBox(height:20),
    const Text('Launching your campaign', style:TextStyle(fontFamily:'Poppins', fontWeight:FontWeight.w800, fontSize:18, color:AppColors.ink)),
    const SizedBox(height:8),
    const Text('This may take a moment…', style:TextStyle(fontFamily:'Poppins', fontSize:13, color:Color(0xFF6B7280))),
  ]);

  Widget _successWidget() => Column(children: [
    TweenAnimationBuilder<double>(tween: Tween(begin:0.0, end:1.0),
      duration: const Duration(milliseconds:600), curve: Curves.elasticOut,
      builder: (_, v, __) => Transform.scale(scale:v,
        child: Container(width:80, height:80,
          decoration: const BoxDecoration(shape:BoxShape.circle, gradient:LinearGradient(colors:[AppColors.midGreen, AppColors.limeGreen])),
          child: const Icon(Icons.check_rounded, color:Colors.white, size:42)))),
    const SizedBox(height:20),
    const Text('Campaign Created! 🎉', style:TextStyle(fontFamily:'Poppins', fontWeight:FontWeight.w800, fontSize:20, color:AppColors.ink)),
    const SizedBox(height:8),
    const Text('Your campaign is under review and will go live shortly.',
      textAlign:TextAlign.center,
      style:TextStyle(fontFamily:'Poppins', fontSize:13, color:Color(0xFF6B7280), height:1.4)),
  ]);

  Widget _errorWidget() => Column(children: [
    Container(width:80, height:80,
      decoration: BoxDecoration(shape:BoxShape.circle, color:AppColors.crimson.withOpacity(0.1)),
      child: const Icon(Icons.error_outline_rounded, color:AppColors.crimson, size:44)),
    const SizedBox(height:20),
    const Text('Something went wrong', style:TextStyle(fontFamily:'Poppins', fontWeight:FontWeight.w800, fontSize:18, color:AppColors.ink)),
    const SizedBox(height:8),
    const Text('Check your connection and try again. Ensure all images are valid.',
      textAlign:TextAlign.center,
      style:TextStyle(fontFamily:'Poppins', fontSize:13, color:Color(0xFF6B7280), height:1.4)),
    const SizedBox(height:20),
    GestureDetector(onTap: widget.onClose,
      child: Container(padding: const EdgeInsets.symmetric(horizontal:28, vertical:12),
        decoration: BoxDecoration(color:AppColors.crimson.withOpacity(0.1), borderRadius:BorderRadius.circular(30)),
        child: const Text('Close', style:TextStyle(fontFamily:'Poppins', fontWeight:FontWeight.w700, color:AppColors.crimson)))),
  ]);
}

// ═══════════════════════════════════════════════════════════════════════════════
// REUSABLE WIDGETS (consolidated & minimised)
// ═══════════════════════════════════════════════════════════════════════════════

class _Label extends StatelessWidget {
  final String text; final bool req;
  const _Label(this.text, {this.req = false});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom:8),
    child: Row(children: [
      Text(text, style: const TextStyle(fontFamily:'Poppins', fontWeight:FontWeight.w700, fontSize:13, color:Color(0xFF374151))),
      if (req) const Text(' *', style:TextStyle(color:AppColors.crimson, fontWeight:FontWeight.w700)),
    ]));
}

class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  final String? error;
  final TextInputType kbType;
  final List<TextInputFormatter>? formatters;
  final IconData? prefix;
  final int? maxLength;
  final void Function(String) onChange;
  const _Field({required this.ctrl, required this.hint, this.error, this.kbType = TextInputType.text,
    this.formatters, this.prefix, this.maxLength, required this.onChange});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    TextField(controller: ctrl, keyboardType: kbType, inputFormatters: formatters,
      maxLength: maxLength, onChanged: onChange,
      style: const TextStyle(fontFamily:'Poppins', fontSize:14, color:AppColors.ink),
      decoration: _deco(hint, error, prefix)),
    if (error != null) _Err(error!),
  ]);

  static InputDecoration _deco(String hint, String? error, IconData? prefix) => InputDecoration(
    hintText: hint, hintStyle: const TextStyle(fontFamily:'Poppins', color:Color(0xFFB0BEC5)),
    prefixIcon: prefix != null ? Icon(prefix, size:18, color: const Color(0xFF9E9E9E)) : null,
    counterText: '', filled: true, fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal:16, vertical:14),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color:Color(0xFFE0E0E0))),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: BorderSide(color: error != null ? AppColors.crimson : const Color(0xFFE0E0E0))),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color:AppColors.midGreen, width:1.5)),
  );
}

class _TextArea extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint; final String? error;
  final void Function(String) onChange;
  const _TextArea({required this.ctrl, required this.hint, this.error, required this.onChange});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    TextField(controller: ctrl, minLines:5, maxLines:12, onChanged: onChange,
      style: const TextStyle(fontFamily:'Poppins', fontSize:13, color:AppColors.ink, height:1.55),
      decoration: InputDecoration(hintText: hint, hintStyle: const TextStyle(fontFamily:'Poppins', fontSize:13, color:Color(0xFFB0BEC5)),
        filled:true, fillColor:Colors.white, contentPadding: const EdgeInsets.all(16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color:Color(0xFFE0E0E0))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: BorderSide(color: error != null ? AppColors.crimson : const Color(0xFFE0E0E0))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color:AppColors.midGreen, width:1.5)))),
    if (error != null) _Err(error!),
  ]);
}

class _DatePick extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint; final String? error; final VoidCallback onPick;
  const _DatePick({required this.ctrl, required this.hint, this.error, required this.onPick});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    GestureDetector(onTap: onPick, child: AbsorbPointer(child: TextField(controller: ctrl,
      decoration: InputDecoration(hintText: hint, hintStyle: const TextStyle(fontFamily:'Poppins', fontSize:13, color:Color(0xFFB0BEC5)),
        suffixIcon: const Icon(Icons.calendar_today_rounded, size:16, color:AppColors.midGreen),
        filled:true, fillColor:Colors.white, contentPadding: const EdgeInsets.symmetric(horizontal:14, vertical:13),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color:Color(0xFFE0E0E0))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: BorderSide(color: error != null ? AppColors.crimson : const Color(0xFFE0E0E0))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color:AppColors.midGreen, width:1.5))),
      style: const TextStyle(fontFamily:'Poppins', fontSize:13)))),
    if (error != null) _Err(error!),
  ]);
}

class _Dropdown<T> extends StatelessWidget {
  final T? value; final String hint; final List<DropdownMenuItem<T>> items;
  final Color surface, border, txt1; final void Function(T?) onChange;
  final String? error; final double? width;
  const _Dropdown({required this.value, required this.hint, required this.items, required this.surface,
    required this.border, required this.txt1, required this.onChange, this.error, this.width});
  @override
  Widget build(BuildContext context) {
    final child = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(height:50,
        decoration: BoxDecoration(color:Colors.white, borderRadius: BorderRadius.circular(13),
          border: Border.all(color: error != null ? AppColors.crimson : border)),
        padding: const EdgeInsets.symmetric(horizontal:12),
        child: DropdownButtonHideUnderline(child: DropdownButton<T>(
          value: value, hint: Text(hint, style: const TextStyle(fontFamily:'Poppins', fontSize:13, color:Color(0xFFB0BEC5))),
          items: items, onChanged: onChange, isExpanded: width == null,
          icon: const Icon(Icons.expand_more_rounded, color:AppColors.midGreen, size:20),
          style: TextStyle(fontFamily:'Poppins', fontSize:14, color:txt1)))),
      if (error != null) _Err(error!),
    ]);
    return width != null ? SizedBox(width: width, child: child) : child;
  }
}

class _TagsInput extends StatelessWidget {
  final List<String> tags; final TextEditingController ctrl;
  final Color surface, border, txt1, txt2;
  final void Function(String) onAdd; final void Function(String) onRemove;
  const _TagsInput({required this.tags, required this.ctrl, required this.surface,
    required this.border, required this.txt1, required this.txt2, required this.onAdd, required this.onRemove});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    if (tags.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom:10),
      child: Wrap(spacing:8, runSpacing:8, children: tags.map((t) => Container(
        padding: const EdgeInsets.symmetric(horizontal:12, vertical:6),
        decoration: BoxDecoration(color: AppColors.midGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.midGreen.withOpacity(0.3))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(t, style: const TextStyle(fontFamily:'Poppins', fontWeight:FontWeight.w600, fontSize:12, color:AppColors.midGreen)),
          const SizedBox(width:6),
          GestureDetector(onTap: () => onRemove(t), child: const Icon(Icons.close_rounded, size:14, color:AppColors.midGreen)),
        ]))).toList())),
    Row(children: [
      Expanded(child: TextField(controller: ctrl,
        onSubmitted: (v) { if (v.trim().isNotEmpty) { onAdd(v.trim().startsWith('#') ? v.trim() : '#${v.trim()}'); ctrl.clear(); }},
        style: const TextStyle(fontFamily:'Poppins', fontSize:13),
        decoration: InputDecoration(hintText: 'Add tag and press Enter',
          hintStyle: const TextStyle(fontFamily:'Poppins', fontSize:12, color:Color(0xFFB0BEC5)),
          prefixIcon: const Icon(Icons.tag_rounded, size:16, color:AppColors.midGreen),
          filled:true, fillColor:Colors.white, contentPadding: const EdgeInsets.symmetric(horizontal:12, vertical:12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: BorderSide(color:border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: BorderSide(color:border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color:AppColors.midGreen))))),
      const SizedBox(width:8),
      GestureDetector(onTap: () { final v = ctrl.text.trim(); if (v.isNotEmpty) { onAdd(v.startsWith('#') ? v : '#$v'); ctrl.clear(); }},
        child: Container(height:48, padding: const EdgeInsets.symmetric(horizontal:16),
          decoration: BoxDecoration(color:AppColors.midGreen, borderRadius: BorderRadius.circular(13)),
          child: const Center(child: Text('Add', style:TextStyle(fontFamily:'Poppins', fontWeight:FontWeight.w700, fontSize:13, color:Colors.white))))),
    ]),
  ]);
}

class _PickerPlaceholder extends StatelessWidget {
  final IconData icon; final String label, sub; final VoidCallback onTap;
  final Color border, txt2; final bool compact;
  const _PickerPlaceholder({required this.icon, required this.label, required this.sub,
    required this.onTap, required this.border, required this.txt2, this.compact = false});
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap,
    child: Container(padding: EdgeInsets.all(compact ? 14 : 28),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: AppColors.midGreen.withOpacity(0.04)),
      child: Row(mainAxisAlignment: compact ? MainAxisAlignment.start : MainAxisAlignment.center, children: [
        Icon(icon, size: compact ? 22 : 36, color: AppColors.midGreen.withOpacity(0.7)),
        const SizedBox(width:12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontFamily:'Poppins', fontWeight:FontWeight.w700, fontSize:13, color:AppColors.midGreen)),
          Text(sub, style: TextStyle(fontFamily:'Poppins', fontSize:11, color:txt2)),
        ]),
      ])));
}

class _FeaturedPreview extends StatelessWidget {
  final File file; final VoidCallback onRemove;
  const _FeaturedPreview({required this.file, required this.onRemove});
  @override
  Widget build(BuildContext context) => Stack(children: [
    ClipRRect(borderRadius: BorderRadius.circular(14),
      child: AspectRatio(aspectRatio:16/9, child: Image.file(file, fit:BoxFit.cover, width:double.infinity))),
    Positioned(top:8, right:8, child: GestureDetector(onTap: onRemove,
      child: Container(width:32, height:32,
        decoration: BoxDecoration(color:AppColors.crimson, shape:BoxShape.circle,
          boxShadow: [BoxShadow(color:Colors.black.withOpacity(0.2), blurRadius:6)]),
        child: const Icon(Icons.close_rounded, color:Colors.white, size:18)))),
  ]);
}

class _GalleryGrid extends StatelessWidget {
  final List<File> files; final void Function(int) onRemove;
  const _GalleryGrid({required this.files, required this.onRemove});
  @override
  Widget build(BuildContext context) => GridView.builder(
    shrinkWrap:true, physics: const NeverScrollableScrollPhysics(),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:3, crossAxisSpacing:8, mainAxisSpacing:8),
    itemCount: files.length,
    itemBuilder: (_, i) => Stack(clipBehavior:Clip.none, children: [
      ClipRRect(borderRadius: BorderRadius.circular(10),
        child: Image.file(files[i], fit:BoxFit.cover, width:double.infinity, height:double.infinity)),
      Positioned(top:-4, right:-4, child: GestureDetector(onTap: () => onRemove(i),
        child: Container(width:24, height:24,
          decoration: const BoxDecoration(color:AppColors.crimson, shape:BoxShape.circle),
          child: const Icon(Icons.close_rounded, color:Colors.white, size:14)))),
    ]));
}

class _Card extends StatelessWidget {
  final Widget child; final Color surface, border;
  const _Card({required this.child, required this.surface, required this.border});
  @override
  Widget build(BuildContext context) => Container(width:double.infinity, padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color:surface, borderRadius: BorderRadius.circular(16), border: Border.all(color:border),
      boxShadow: [BoxShadow(color:Colors.black.withOpacity(0.04), blurRadius:10, offset: const Offset(0,3))]),
    child: child);
}

class _Banner extends StatelessWidget {
  final IconData icon; final String text; final Color txt2;
  final Color? color, iconColor;
  const _Banner({required this.icon, required this.text, required this.txt2, this.color, this.iconColor});
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: color ?? AppColors.midGreen.withOpacity(0.08), borderRadius: BorderRadius.circular(12),
      border: Border.all(color: (iconColor ?? AppColors.midGreen).withOpacity(0.2))),
    child: Row(children: [
      Icon(icon, size:18, color: iconColor ?? AppColors.midGreen),
      const SizedBox(width:10),
      Expanded(child: Text(text, style: TextStyle(fontFamily:'Poppins', fontSize:12, color:txt2, height:1.4))),
    ]));
}

class _Err extends StatelessWidget {
  final String text;
  const _Err(this.text);
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(top:6),
    child: Row(children: [
      const Icon(Icons.error_outline_rounded, size:13, color:AppColors.crimson),
      const SizedBox(width:5),
      Expanded(child: Text(text, style: const TextStyle(fontFamily:'Poppins', fontSize:11, color:AppColors.crimson))),
    ]));
}

class _Chip extends StatelessWidget {
  final String label, value; final Color surface, txt1, txt2;
  const _Chip({required this.label, required this.value, required this.surface, required this.txt1, required this.txt2});
  @override
  Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(vertical:10, horizontal:12),
    decoration: BoxDecoration(color: surface.withOpacity(0.5), borderRadius: BorderRadius.circular(10)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontFamily:'Poppins', fontSize:10, color:txt2)),
      const SizedBox(height:2),
      Text(value, style: TextStyle(fontFamily:'Poppins', fontWeight:FontWeight.w700, fontSize:13, color:txt1), overflow:TextOverflow.ellipsis),
    ])));
}

class _PreviewRow extends StatelessWidget {
  final String label, value; final IconData icon; final Color txt1, txt2;
  const _PreviewRow(this.label, this.value, this.icon, this.txt1, this.txt2);
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical:7),
    child: Row(children: [
      Icon(icon, size:16, color:AppColors.midGreen),
      const SizedBox(width:10),
      Text('$label: ', style: TextStyle(fontFamily:'Poppins', fontSize:12, color:txt2)),
      Expanded(child: Text(value, style: TextStyle(fontFamily:'Poppins', fontWeight:FontWeight.w600, fontSize:13, color:txt1), overflow:TextOverflow.ellipsis)),
    ]));
}

class _Badge extends StatelessWidget {
  final String label; final Color color;
  const _Badge(this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal:10, vertical:5),
    decoration: BoxDecoration(color: color.withOpacity(0.9), borderRadius: BorderRadius.circular(20)),
    child: Text(label, style: const TextStyle(fontFamily:'Poppins', fontWeight:FontWeight.w700, fontSize:11, color:Colors.white)));
}

class _GradientBtn extends StatefulWidget {
  final String label; final IconData icon; final VoidCallback? onTap; final bool disabled;
  const _GradientBtn({required this.label, required this.icon, this.onTap, this.disabled = false});
  @override State<_GradientBtn> createState() => _GradientBtnState();
}

class _GradientBtnState extends State<_GradientBtn> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds:140));
  late final _s = Tween(begin:1.0, end:0.96).animate(CurvedAnimation(parent:_c, curve:Curves.easeInOut));
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final active = widget.onTap != null && !widget.disabled;
    return GestureDetector(
      onTapDown: active ? (_) => _c.forward() : null,
      onTapUp: active ? (_) async { await _c.reverse(); widget.onTap?.call(); } : null,
      onTapCancel: () => _c.reverse(),
      child: ScaleTransition(scale: _s,
        child: AnimatedContainer(duration: const Duration(milliseconds:200), height:52,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: active ? [AppColors.forestGreen, AppColors.limeGreen] : [const Color(0xFFB0B0B0), const Color(0xFFCCCCCC)],
              begin: Alignment.centerLeft, end: Alignment.centerRight),
            borderRadius: BorderRadius.circular(14),
            boxShadow: active ? [BoxShadow(color: AppColors.midGreen.withOpacity(0.4), blurRadius:14, offset: const Offset(0,5))] : []),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(widget.label, style: const TextStyle(fontFamily:'Poppins', fontWeight:FontWeight.w800, fontSize:14, color:Colors.white)),
            const SizedBox(width:8),
            Icon(widget.icon, color:Colors.white, size:17),
          ]))));
  }
}