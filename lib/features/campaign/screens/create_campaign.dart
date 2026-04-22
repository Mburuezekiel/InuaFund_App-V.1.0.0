import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'dart:convert';


 import '../../home/screens/home_screen.dart' show AppColors;
// ─────────────────────────────────────────────────────────────────────────────

// ═══════════════════════════════════════════════════════════════════════════════
// MODELS
// ═══════════════════════════════════════════════════════════════════════════════

class CampaignFormData {
  String title = '';
  String description = '';
  double goal = 0;
  String currency = 'KES';
  String category = 'community';
  String campaignType = 'personal';
  String country = 'Kenya';
  String location = '';
  String startDate = '';
  String endDate = '';
  String contactEmail = '';
  String contactPhone = '';
  String creatorId = '';
  String username = '';
  String collaboratorName = '';
  String collaboratorEmail = '';
  String charityName = '';
  List<String> tags = [];
}

class LocationItem {
  final String code, name;
  const LocationItem(this.code, this.name);
}

class CategoryItem {
  final String value, label;
  final IconData icon;
  final Color color;
  const CategoryItem(this.value, this.label, this.icon, this.color);
}

class FundraisingType {
  final String value, label, description;
  final IconData icon;
  const FundraisingType(this.value, this.label, this.description, this.icon);
}

// ═══════════════════════════════════════════════════════════════════════════════
// DATA
// ═══════════════════════════════════════════════════════════════════════════════

const kLocations = [
  LocationItem('047', 'Nairobi'),
  LocationItem('001', 'Mombasa'),
  LocationItem('003', 'Kilifi'),
  LocationItem('042', 'Kisumu'),
  LocationItem('032', 'Nakuru'),
  LocationItem('022', 'Kiambu'),
  LocationItem('016', 'Machakos'),
  LocationItem('019', 'Nyeri'),
  LocationItem('012', 'Meru'),
  LocationItem('014', 'Embu'),
  LocationItem('037', 'Kakamega'),
  LocationItem('027', 'Uasin Gishu'),
  LocationItem('045', 'Kisii'),
  LocationItem('039', 'Bungoma'),
  LocationItem('035', 'Kericho'),
  LocationItem('021', 'Muranga'),
  LocationItem('020', 'Kirinyaga'),
  LocationItem('044', 'Migori'),
  LocationItem('043', 'Homa Bay'),
  LocationItem('031', 'Laikipia'),
  LocationItem('033', 'Narok'),
  LocationItem('034', 'Kajiado'),
  LocationItem('023', 'Turkana'),
  LocationItem('007', 'Garissa'),
  LocationItem('008', 'Wajir'),
  LocationItem('002', 'Kwale'),
  LocationItem('004', 'Tana River'),
  LocationItem('005', 'Lamu'),
  LocationItem('006', 'Taita Taveta'),
  LocationItem('009', 'Mandera'),
  LocationItem('010', 'Marsabit'),
  LocationItem('011', 'Isiolo'),
  LocationItem('013', 'Tharaka Nithi'),
  LocationItem('015', 'Kitui'),
  LocationItem('017', 'Makueni'),
  LocationItem('018', 'Nyandarua'),
  LocationItem('024', 'West Pokot'),
  LocationItem('025', 'Samburu'),
  LocationItem('026', 'Trans Nzoia'),
  LocationItem('028', 'Elgeyo Marakwet'),
  LocationItem('029', 'Nandi'),
  LocationItem('030', 'Baringo'),
  LocationItem('036', 'Bomet'),
  LocationItem('038', 'Vihiga'),
  LocationItem('040', 'Busia'),
  LocationItem('041', 'Siaya'),
  LocationItem('046', 'Nyamira'),
];

const kCategories = [
  CategoryItem('medical',      'Healthcare',    Icons.favorite_rounded,         Color(0xFFD93025)),
  CategoryItem('education',    'Education',     Icons.school_rounded,           Color(0xFF1565C0)),
  CategoryItem('community',    'Community',     Icons.people_rounded,           Color(0xFF6A1B9A)),
  CategoryItem('emergencies',  'Emergencies',   Icons.warning_amber_rounded,    Color(0xFFB71C1C)),
  CategoryItem('water',        'Water',         Icons.water_drop_rounded,       Color(0xFF006064)),
  CategoryItem('environment',  'Environment',   Icons.eco_rounded,              Color(0xFF1B5E20)),
  CategoryItem('agriculture',  'Agriculture',   Icons.grass_rounded,            Color(0xFF33691E)),
  CategoryItem('animals',      'Animals',       Icons.pets_rounded,             Color(0xFFE65100)),
  CategoryItem('business',     'Business',      Icons.business_center_rounded,  Color(0xFFF9A825)),
  CategoryItem('creative',     'Creative',      Icons.palette_rounded,          Color(0xFFAD1457)),
  CategoryItem('technology',   'Technology',    Icons.computer_rounded,         Color(0xFF283593)),
  CategoryItem('nonprofit',    'Non-Profit',    Icons.volunteer_activism_rounded,Color(0xFF2E7D32)),
  CategoryItem('events',       'Events',        Icons.event_rounded,            Color(0xFF00838F)),
  CategoryItem('faith',        'Faith',         Icons.church_rounded,           Color(0xFF455A64)),
  CategoryItem('family',       'Family',        Icons.family_restroom_rounded,  Color(0xFF6A1B9A)),
  CategoryItem('travel',       'Travel',        Icons.flight_rounded,           Color(0xFF0277BD)),
  CategoryItem('arts',         'Arts & Culture',Icons.museum_rounded,           Color(0xFF880E4F)),
  CategoryItem('volunteer',    'Volunteer',     Icons.handshake_rounded,        Color(0xFF558B2F)),
  CategoryItem('memorial',     'Memorials',     Icons.local_florist_rounded,    Color(0xFF546E7A)),
  CategoryItem('wishes',       'Wishes',        Icons.auto_awesome_rounded,     Color(0xFFF57F17)),
];

const kFundraisingTypes = [
  FundraisingType('personal',      'Yourself',      'Funds go to your bank account',                    Icons.person_rounded),
  FundraisingType('someone-else',  'Someone Else',  'Beneficiary receives the funds directly',           Icons.people_rounded),
  FundraisingType('charity',       'Charity',       'Funds go to your chosen non-profit organisation',  Icons.volunteer_activism_rounded),
];

const kCurrencies = ['KES', 'UGX', 'TZS', 'ETB', 'GHS', 'NGN', 'ZAR', 'RWF', 'XOF', 'MAD'];

// ═══════════════════════════════════════════════════════════════════════════════
// SERVICE
// ═══════════════════════════════════════════════════════════════════════════════

class CampaignCreationService {
  static const _base = 'https://api.inuafund.co.ke/api';

  static Future<Map<String, dynamic>> createCampaign({
    required CampaignFormData data,
    required File? featuredImage,
    required List<File> gallery,
    required String token,
  }) async {
    final uri = Uri.parse('$_base/campaigns');
    final request = http.MultipartRequest('POST', uri);

    request.headers.addAll({
      'Accept': 'application/json',
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
    });

    // Text fields
    request.fields['title']        = data.title;
    request.fields['description']  = data.description;
    request.fields['goal']         = data.goal.toString();
    request.fields['currency']     = data.currency;
    request.fields['category']     = data.category;
    request.fields['campaignType'] = data.campaignType;
    request.fields['country']      = data.country;
    request.fields['location']     = data.location;
    request.fields['zipCode']      = data.location;
    request.fields['startDate']    = data.startDate;
    request.fields['endDate']      = data.endDate;
    request.fields['status']       = 'pending';
    request.fields['amountRaised'] = '0';
    request.fields['contactEmail'] = data.contactEmail;
    request.fields['contactPhone'] = data.contactPhone;
    request.fields['creator_Id']   = data.creatorId;
    request.fields['username']     = data.username;

    if (data.campaignType == 'someone-else') {
      request.fields['collaboratorName']  = data.collaboratorName;
      request.fields['collaboratorEmail'] = data.collaboratorEmail;
    } else if (data.campaignType == 'charity') {
      request.fields['charityName'] = data.charityName;
    }

    for (var i = 0; i < data.tags.length; i++) {
      request.fields['tags[$i]'] = data.tags[i];
    }

    if (featuredImage != null) {
      request.files.add(await http.MultipartFile.fromPath('featuredImage', featuredImage.path));
    }
    for (final f in gallery) {
      request.files.add(await http.MultipartFile.fromPath('galleryImages', f.path));
    }

    final streamed = await request.send().timeout(const Duration(seconds: 30));
    final body     = await streamed.stream.bytesToString();
    final decoded  = json.decode(body) as Map<String, dynamic>;

    if (streamed.statusCode == 200 || streamed.statusCode == 201) return decoded;
    throw Exception(decoded['message'] ?? 'Failed to create campaign');
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// STEP DEFINITIONS
// ═══════════════════════════════════════════════════════════════════════════════

enum CampaignStep { details, media, type, location, category, funding, contact, preview }

const kStepMeta = <CampaignStep, Map<String, dynamic>>{
  CampaignStep.details:  {'title': 'Campaign Details',     'desc': 'Give your campaign a name and story', 'icon': Icons.edit_note_rounded},
  CampaignStep.media:    {'title': 'Campaign Media',       'desc': 'Add images to showcase your cause',   'icon': Icons.photo_library_rounded},
  CampaignStep.type:     {'title': 'Fundraising Focus',    'desc': 'Who are you raising funds for?',      'icon': Icons.track_changes_rounded},
  CampaignStep.location: {'title': 'Campaign Location',    'desc': 'Where will funds be withdrawn?',      'icon': Icons.location_on_rounded},
  CampaignStep.category: {'title': 'Campaign Purpose',     'desc': 'What best describes your goal?',      'icon': Icons.category_rounded},
  CampaignStep.funding:  {'title': 'Funding Goal',         'desc': 'Set your fundraising target',         'icon': Icons.attach_money_rounded},
  CampaignStep.contact:  {'title': 'Contact Information',  'desc': 'How can donors reach you?',           'icon': Icons.contact_mail_rounded},
  CampaignStep.preview:  {'title': 'Campaign Preview',     'desc': 'Review before submitting',            'icon': Icons.visibility_rounded},
};

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN SCREEN
// ═══════════════════════════════════════════════════════════════════════════════

class StartCampaignScreen extends StatefulWidget {
  final bool isDark;
  final String authToken;
  final String userId;
  final String username;
  final String userEmail;
  final String userPhone;

  const StartCampaignScreen({
    super.key,
    this.isDark = false,
    this.authToken = '',
    this.userId = '',
    this.username = '',
    this.userEmail = '',
    this.userPhone = '',
  });

  @override
  State<StartCampaignScreen> createState() => _StartCampaignScreenState();
}

class _StartCampaignScreenState extends State<StartCampaignScreen>
    with TickerProviderStateMixin {
  // ── State ─────────────────────────────────────────────────────────────────
  int _stepIndex = 0;
  final CampaignFormData _form = CampaignFormData();
  final Map<String, String> _errors = {};
  bool _agreedToTerms = false;
  bool _isSubmitting = false;
  SubmitStatus _submitStatus = SubmitStatus.idle;

  File? _featuredImage;
  List<File> _gallery = [];

  final _tagCtrl     = TextEditingController();
  final _titleCtrl   = TextEditingController();
  final _descCtrl    = TextEditingController();
  final _goalCtrl    = TextEditingController();
  final _emailCtrl   = TextEditingController();
  final _phoneCtrl   = TextEditingController();
  final _collNameCtrl  = TextEditingController();
  final _collEmailCtrl = TextEditingController();
  final _charityCtrl   = TextEditingController();
  final _startDateCtrl = TextEditingController();
  final _endDateCtrl   = TextEditingController();

  final PageController _pageCtrl = PageController();
  late final AnimationController _slideCtrl;
  late final Animation<Offset> _slideAnim;
  late final AnimationController _fadeCtrl;

  final steps = CampaignStep.values;

  // ── Theme helpers ──────────────────────────────────────────────────────────
  Color get bg      => widget.isDark ? AppColors.darkBg    : AppColors.snow;
  Color get surface => widget.isDark ? AppColors.darkCard  : AppColors.white;
  Color get border  => widget.isDark ? AppColors.darkBorder: AppColors.cloud;
  Color get txt1    => widget.isDark ? AppColors.white     : AppColors.ink;
  Color get txt2    => widget.isDark ? AppColors.mist      : const Color(0xFF6B7280);

  double get progress => _stepIndex / (steps.length - 1);

  @override
  void initState() {
    super.initState();
    _form.contactEmail = widget.userEmail;
    _form.contactPhone = widget.userPhone;
    _form.creatorId    = widget.userId;
    _form.username     = widget.username;
    _emailCtrl.text    = widget.userEmail;
    _phoneCtrl.text    = widget.userPhone;

    _slideCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
    _slideAnim = Tween<Offset>(begin: const Offset(0.08, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 320))
      ..value = 1;
    _slideCtrl.forward();
  }

  @override
  void dispose() {
    _pageCtrl.dispose(); _slideCtrl.dispose(); _fadeCtrl.dispose();
    _tagCtrl.dispose(); _titleCtrl.dispose(); _descCtrl.dispose();
    _goalCtrl.dispose(); _emailCtrl.dispose(); _phoneCtrl.dispose();
    _collNameCtrl.dispose(); _collEmailCtrl.dispose(); _charityCtrl.dispose();
    _startDateCtrl.dispose(); _endDateCtrl.dispose();
    super.dispose();
  }

  // ── Navigation ─────────────────────────────────────────────────────────────
  Future<void> _next() async {
    if (!_validate()) return;
    if (_stepIndex == steps.length - 1) { _submit(); return; }
    await _animateStep(forward: true);
    setState(() => _stepIndex++);
  }

  Future<void> _back() async {
    if (_stepIndex == 0) { Navigator.pop(context); return; }
    await _animateStep(forward: false);
    setState(() => _stepIndex--);
  }

  Future<void> _animateStep({required bool forward}) async {
    _fadeCtrl.reverse();
    _slideCtrl.reset();
    await Future.delayed(const Duration(milliseconds: 120));
    _fadeCtrl.forward();
    _slideCtrl.forward();
  }

  // ── Validation ─────────────────────────────────────────────────────────────
  bool _validate() {
    final e = <String, String>{};
    final step = steps[_stepIndex];
    switch (step) {
      case CampaignStep.details:
        if (_form.title.trim().isEmpty) e['title'] = 'Campaign title is required';
        if (_form.description.trim().isEmpty) e['desc'] = 'Tell your story — description is required';
        break;
      case CampaignStep.media:
        if (_featuredImage == null) e['featured'] = 'Please add a featured image for your campaign';
        if (_gallery.isEmpty) e['gallery'] = 'Add at least one gallery image';
        break;
      case CampaignStep.type:
        if (_form.campaignType == 'someone-else') {
          if (_form.collaboratorName.trim().isEmpty) e['collName'] = 'Collaborator name required';
          if (_form.collaboratorEmail.trim().isEmpty) e['collEmail'] = 'Collaborator email required';
        } else if (_form.campaignType == 'charity') {
          if (_form.charityName.trim().isEmpty) e['charity'] = 'Charity name required';
        }
        break;
      case CampaignStep.location:
        if (_form.location.isEmpty) e['location'] = 'Please select a county';
        break;
      case CampaignStep.category:
        if (_form.category.isEmpty) e['category'] = 'Please select a category';
        break;
      case CampaignStep.funding:
        if (_form.goal <= 0) e['goal'] = 'Please enter a valid funding goal';
        if (_form.startDate.isEmpty) e['startDate'] = 'Please set a start date';
        break;
      case CampaignStep.contact:
        if (_form.contactEmail.trim().isEmpty) e['email'] = 'Contact email is required';
        if (_form.contactPhone.trim().isEmpty) e['phone'] = 'Contact phone is required';
        break;
      case CampaignStep.preview:
        if (!_agreedToTerms) e['terms'] = 'Please accept the terms and conditions';
        break;
    }
    setState(() => _errors
      ..clear()
      ..addAll(e));
    return e.isEmpty;
  }

  // ── Submit ─────────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    setState(() { _isSubmitting = true; _submitStatus = SubmitStatus.loading; });
    _showDialog();
    try {
      await CampaignCreationService.createCampaign(
        data: _form,
        featuredImage: _featuredImage,
        gallery: _gallery,
        token: widget.authToken,
      );
      setState(() => _submitStatus = SubmitStatus.success);
      await Future.delayed(const Duration(milliseconds: 2200));
      if (mounted) Navigator.pop(context);
    } catch (err) {
      setState(() => _submitStatus = SubmitStatus.error);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _SubmissionDialog(
        statusNotifier: ValueNotifier(_submitStatus),
        parent: this,
        onClose: () => Navigator.pop(context),
      ),
    );
  }

  // ── Image picking ──────────────────────────────────────────────────────────
  Future<void> _pickFeaturedImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 1200);
    if (picked != null) setState(() { _featuredImage = File(picked.path); _errors.remove('featured'); });
  }

  Future<void> _pickGalleryImages() async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(imageQuality: 75, maxWidth: 800);
    if (picked.isNotEmpty) {
      final remaining = 5 - _gallery.length;
      final toAdd = picked.take(remaining).map((x) => File(x.path)).toList();
      setState(() { _gallery.addAll(toAdd); _errors.remove('gallery'); });
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final meta = kStepMeta[steps[_stepIndex]]!;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      color: bg,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(children: [
            _buildAppBar(meta),
            _buildStepIndicator(),
            _buildProgressBar(),
            Expanded(
              child: FadeTransition(
                opacity: _fadeCtrl,
                child: SlideTransition(
                  position: _slideAnim,
                  child: _buildStepContent(),
                ),
              ),
            ),
            _buildFooter(),
          ]),
        ),
      ),
    );
  }

  Widget _buildAppBar(Map<String, dynamic> meta) => Container(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
    child: Row(children: [
      GestureDetector(
        onTap: _back,
        child: Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: surface, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border),
          ),
          child: Icon(Icons.arrow_back_ios_new_rounded, color: txt1, size: 18),
        ),
      ),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(meta['title'] as String,
          style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w800, fontSize: 18, color: txt1, letterSpacing: -0.3)),
        Text(meta['desc'] as String,
          style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: txt2)),
      ])),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.midGreen.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.midGreen.withOpacity(0.25)),
        ),
        child: Text('${_stepIndex + 1} / ${steps.length}',
          style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.midGreen)),
      ),
    ]),
  );

  Widget _buildStepIndicator() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
    child: Row(children: List.generate(steps.length, (i) {
      final done    = i < _stepIndex;
      final current = i == _stepIndex;
      return Expanded(
        child: GestureDetector(
          onTap: done ? () async { await _animateStep(forward: false); setState(() => _stepIndex = i); } : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.symmetric(horizontal: 2),
            height: 6,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: done    ? AppColors.midGreen
                   : current ? AppColors.limeGreen
                   : border,
            ),
          ),
        ),
      );
    })),
  );

  Widget _buildProgressBar() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
    child: Row(children: [
      Text('${(progress * 100).round()}% complete',
        style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: txt2)),
      const Spacer(),
      Icon(kStepMeta[steps[_stepIndex]]!['icon'] as IconData, color: AppColors.midGreen, size: 16),
    ]),
  );

  Widget _buildStepContent() => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
    physics: const BouncingScrollPhysics(),
    child: _stepWidget(),
  );

  Widget _stepWidget() {
    switch (steps[_stepIndex]) {
      case CampaignStep.details:   return _buildDetailsStep();
      case CampaignStep.media:     return _buildMediaStep();
      case CampaignStep.type:      return _buildTypeStep();
      case CampaignStep.location:  return _buildLocationStep();
      case CampaignStep.category:  return _buildCategoryStep();
      case CampaignStep.funding:   return _buildFundingStep();
      case CampaignStep.contact:   return _buildContactStep();
      case CampaignStep.preview:   return _buildPreviewStep();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // STEP 1 — DETAILS
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildDetailsStep() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _FieldLabel('Campaign Title', required: true),
    _FieldBox(
      controller: _titleCtrl,
      hint: 'E.g. Help Mama Wanjiku with Cancer Treatment',
      error: _errors['title'],
      maxLength: 100,
      onChanged: (v) { _form.title = v; _errors.remove('title'); },
    ),
    const SizedBox(height: 18),
    _FieldLabel('Your Story', required: true),
    _StyledTextArea(
      controller: _descCtrl,
      hint: 'Tell donors why this campaign matters, how funds will be used, and who it helps...',
      minLines: 5,
      error: _errors['desc'],
      onChanged: (v) { _form.description = v; _errors.remove('desc'); },
    ),
    const SizedBox(height: 18),
    Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _FieldLabel('Start Date', required: true),
        _DateField(
          controller: _startDateCtrl,
          hint: 'YYYY-MM-DD',
          error: _errors['startDate'],
          onPick: () async {
            final d = await showDatePicker(
              context: context,
              initialDate: DateTime.now().add(const Duration(days: 1)),
              firstDate: DateTime.now().add(const Duration(days: 1)),
              lastDate: DateTime.now().add(const Duration(days: 730)),
              builder: _datePickerTheme,
            );
            if (d != null) {
              final s = '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
              setState(() { _form.startDate = s; _startDateCtrl.text = s; _errors.remove('startDate'); });
            }
          },
        ),
      ])),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _FieldLabel('End Date'),
        _DateField(
          controller: _endDateCtrl,
          hint: 'YYYY-MM-DD',
          onPick: () async {
            final d = await showDatePicker(
              context: context,
              initialDate: DateTime.now().add(const Duration(days: 30)),
              firstDate: DateTime.now().add(const Duration(days: 7)),
              lastDate: DateTime.now().add(const Duration(days: 730)),
              builder: _datePickerTheme,
            );
            if (d != null) {
              final s = '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
              setState(() { _form.endDate = s; _endDateCtrl.text = s; });
            }
          },
        ),
      ])),
    ]),
    const SizedBox(height: 18),
    _FieldLabel('Tags'),
    _TagsField(
      tags: _form.tags,
      controller: _tagCtrl,
      surface: surface, border: border, txt1: txt1, txt2: txt2,
      onAdd: (v) => setState(() { if (!_form.tags.contains(v)) _form.tags.add(v); }),
      onRemove: (v) => setState(() => _form.tags.remove(v)),
    ),
  ]);

  Widget Function(BuildContext, Widget?) get _datePickerTheme => (ctx, child) => Theme(
    data: ThemeData.light().copyWith(
      colorScheme: const ColorScheme.light(primary: AppColors.midGreen, onPrimary: Colors.white, surface: Colors.white),
    ),
    child: child!,
  );

  // ─────────────────────────────────────────────────────────────────────────────
  // STEP 2 — MEDIA
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildMediaStep() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _SectionCard(
      surface: surface, border: border,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _FieldLabel('Featured Image', required: true),
        const SizedBox(height: 8),
        _featuredImage == null
            ? _ImagePickerPlaceholder(
                icon: Icons.add_photo_alternate_rounded,
                label: 'Tap to add featured image',
                sub: 'Recommended: 1200×630 px',
                onTap: _pickFeaturedImage,
                border: border, txt2: txt2,
              )
            : _FeaturedImagePreview(
                file: _featuredImage!,
                onRemove: () => setState(() => _featuredImage = null),
              ),
        if (_errors['featured'] != null) _ErrorText(_errors['featured']!),
      ]),
    ),
    const SizedBox(height: 16),
    _SectionCard(
      surface: surface, border: border,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _FieldLabel('Gallery Images'),
          const Spacer(),
          Text('${_gallery.length}/5', style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: txt2)),
        ]),
        const SizedBox(height: 10),
        if (_gallery.isNotEmpty) _GalleryGrid(
          files: _gallery,
          onRemove: (i) => setState(() => _gallery.removeAt(i)),
        ),
        if (_gallery.length < 5) ...[
          const SizedBox(height: 10),
          _ImagePickerPlaceholder(
            icon: Icons.add_to_photos_rounded,
            label: _gallery.isEmpty ? 'Add gallery images' : 'Add more images',
            sub: '${5 - _gallery.length} remaining • Max 5MB each',
            onTap: _pickGalleryImages,
            border: border, txt2: txt2, compact: _gallery.isNotEmpty,
          ),
        ],
        if (_errors['gallery'] != null) _ErrorText(_errors['gallery']!),
      ]),
    ),
  ]);

  // ─────────────────────────────────────────────────────────────────────────────
  // STEP 3 — TYPE
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildTypeStep() => Column(children: [
    ...kFundraisingTypes.map((t) {
      final sel = _form.campaignType == t.value;
      return GestureDetector(
        onTap: () => setState(() { _form.campaignType = t.value; _errors.remove('type'); }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: sel ? AppColors.midGreen.withOpacity(0.08) : surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: sel ? AppColors.midGreen : border, width: sel ? 2 : 1),
            boxShadow: sel ? [BoxShadow(color: AppColors.midGreen.withOpacity(0.15), blurRadius: 12, offset: const Offset(0, 4))] : [],
          ),
          child: Row(children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 52, height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: sel ? AppColors.midGreen : AppColors.midGreen.withOpacity(0.1),
              ),
              child: Icon(t.icon, color: sel ? Colors.white : AppColors.midGreen, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t.label, style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w800, fontSize: 15, color: sel ? AppColors.midGreen : txt1)),
              const SizedBox(height: 3),
              Text(t.description, style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: txt2)),
            ])),
            if (sel) const Icon(Icons.check_circle_rounded, color: AppColors.midGreen, size: 22),
          ]),
        ),
      );
    }),
    // Collaborator fields
    if (_form.campaignType == 'someone-else') ...[
      const SizedBox(height: 8),
      _SectionCard(surface: surface, border: border, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Collaborator Details', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 14, color: txt1)),
        const SizedBox(height: 4),
        Text('Who will receive the funds?', style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: txt2)),
        const SizedBox(height: 14),
        _FieldLabel('Name'),
        _FieldBox(controller: _collNameCtrl, hint: 'Full name', error: _errors['collName'], onChanged: (v) { _form.collaboratorName = v; _errors.remove('collName'); }),
        const SizedBox(height: 12),
        _FieldLabel('Email'),
        _FieldBox(controller: _collEmailCtrl, hint: 'email@example.com', error: _errors['collEmail'], keyboardType: TextInputType.emailAddress, onChanged: (v) { _form.collaboratorEmail = v; _errors.remove('collEmail'); }),
      ])),
    ],
    if (_form.campaignType == 'charity') ...[
      const SizedBox(height: 8),
      _SectionCard(surface: surface, border: border, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Charity Details', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 14, color: txt1)),
        const SizedBox(height: 12),
        _FieldLabel('Charity / Organisation Name'),
        _FieldBox(controller: _charityCtrl, hint: 'E.g. Red Cross Kenya', error: _errors['charity'], onChanged: (v) { _form.charityName = v; _errors.remove('charity'); }),
      ])),
    ],
  ]);

  // ─────────────────────────────────────────────────────────────────────────────
  // STEP 4 — LOCATION
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildLocationStep() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _InfoBanner(icon: Icons.info_outline_rounded, text: 'Select the county where funds will be withdrawn.', txt2: txt2),
    const SizedBox(height: 18),
    _FieldLabel('County / Location', required: true),
    _DropdownField<String>(
      value: _form.location.isEmpty ? null : _form.location,
      hint: 'Select county',
      items: kLocations.map((l) => DropdownMenuItem(value: l.code, child: Text(l.name, style: const TextStyle(fontFamily: 'Poppins', fontSize: 14)))).toList(),
      surface: surface, border: border, txt1: txt1,
      onChanged: (v) => setState(() { _form.location = v ?? ''; _errors.remove('location'); }),
      error: _errors['location'],
    ),
    const SizedBox(height: 18),
    _FieldLabel('Country'),
    Container(
      height: 50, padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: border.withOpacity(0.4), borderRadius: BorderRadius.circular(13), border: Border.all(color: border)),
      alignment: Alignment.centerLeft,
      child: Row(children: [
        const Text('🇰🇪', style: TextStyle(fontSize: 20)),
        const SizedBox(width: 10),
        Text('Kenya', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 14, color: txt1)),
      ]),
    ),
  ]);

  // ─────────────────────────────────────────────────────────────────────────────
  // STEP 5 — CATEGORY
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildCategoryStep() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Wrap(spacing: 10, runSpacing: 10, children: kCategories.map((cat) {
      final sel = _form.category == cat.value;
      return GestureDetector(
        onTap: () => setState(() { _form.category = cat.value; _errors.remove('category'); }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: sel ? cat.color : surface,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: sel ? cat.color : border, width: sel ? 0 : 1),
            boxShadow: sel ? [BoxShadow(color: cat.color.withOpacity(0.28), blurRadius: 8, offset: const Offset(0, 3))] : [],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(cat.icon, size: 15, color: sel ? Colors.white : cat.color),
            const SizedBox(width: 7),
            Text(cat.label, style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 13, color: sel ? Colors.white : txt1)),
          ]),
        ),
      );
    }).toList()),
    if (_errors['category'] != null) ...[const SizedBox(height: 10), _ErrorText(_errors['category']!)],
  ]);

  // ─────────────────────────────────────────────────────────────────────────────
  // STEP 6 — FUNDING
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildFundingStep() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _FieldLabel('Fundraising Goal', required: true),
    Row(children: [
      _DropdownField<String>(
        value: _form.currency,
        hint: 'KES',
        items: kCurrencies.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600)))).toList(),
        surface: surface, border: border, txt1: txt1,
        onChanged: (v) => setState(() => _form.currency = v ?? 'KES'),
        width: 90,
      ),
      const SizedBox(width: 10),
      Expanded(child: _FieldBox(
        controller: _goalCtrl,
        hint: '0.00',
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
        error: _errors['goal'],
        onChanged: (v) { _form.goal = double.tryParse(v) ?? 0; _errors.remove('goal'); },
      )),
    ]),
    if (_form.goal > 0) ...[
      const SizedBox(height: 20),
      _GoalPreviewCard(goal: _form.goal, currency: _form.currency, surface: surface, border: border, txt1: txt1, txt2: txt2),
    ],
    const SizedBox(height: 20),
    _InfoBanner(
      icon: Icons.tips_and_updates_rounded,
      text: 'Set a realistic goal. You can always raise more — over-funding is allowed!',
      txt2: txt2,
      color: AppColors.savanna.withOpacity(0.1),
      iconColor: AppColors.savanna,
    ),
  ]);

  // ─────────────────────────────────────────────────────────────────────────────
  // STEP 7 — CONTACT
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildContactStep() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _SectionCard(surface: surface, border: border, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.account_circle_rounded, color: AppColors.midGreen, size: 20),
        const SizedBox(width: 8),
        Text('Campaign Creator', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 14, color: txt1)),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        _InfoChip(label: 'Username', value: _form.username.isEmpty ? 'N/A' : _form.username, surface: border, txt1: txt1, txt2: txt2),
        const SizedBox(width: 10),
        _InfoChip(
          label: 'User ID',
          value: _form.creatorId.length > 8 ? '${_form.creatorId.substring(0,5)}…${_form.creatorId.substring(_form.creatorId.length-4)}' : _form.creatorId.isEmpty ? 'N/A' : _form.creatorId,
          surface: border, txt1: txt1, txt2: txt2,
        ),
      ]),
    ])),
    const SizedBox(height: 16),
    _FieldLabel('Contact Email', required: true),
    _FieldBox(
      controller: _emailCtrl,
      hint: 'your@email.com',
      keyboardType: TextInputType.emailAddress,
      prefixIcon: Icons.mail_outline_rounded,
      error: _errors['email'],
      onChanged: (v) { _form.contactEmail = v; _errors.remove('email'); },
    ),
    const SizedBox(height: 14),
    _FieldLabel('Contact Phone', required: true),
    _FieldBox(
      controller: _phoneCtrl,
      hint: '+254 7XX XXX XXX',
      keyboardType: TextInputType.phone,
      prefixIcon: Icons.phone_outlined,
      error: _errors['phone'],
      onChanged: (v) { _form.contactPhone = v; _errors.remove('phone'); },
    ),
  ]);

  // ─────────────────────────────────────────────────────────────────────────────
  // STEP 8 — PREVIEW
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildPreviewStep() {
    final cat = kCategories.firstWhere((c) => c.value == _form.category, orElse: () => kCategories[0]);
    final loc = kLocations.firstWhere((l) => l.code == _form.location, orElse: () => const LocationItem('', 'N/A'));
    final type = kFundraisingTypes.firstWhere((t) => t.value == _form.campaignType);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Featured image preview
      if (_featuredImage != null)
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: AspectRatio(
            aspectRatio: 16/9,
            child: Stack(children: [
              Image.file(_featuredImage!, fit: BoxFit.cover, width: double.infinity),
              Positioned.fill(child: Container(decoration: BoxDecoration(
                gradient: LinearGradient(colors: [Colors.transparent, Colors.black.withOpacity(0.4)], begin: Alignment.topCenter, end: Alignment.bottomCenter)))),
              Positioned(bottom: 14, left: 14, child: Row(children: [
                _PreviewBadge(cat.label, cat.color),
                const SizedBox(width: 8),
                _PreviewBadge(type.label, AppColors.forestGreen),
              ])),
            ]),
          ),
        ),
      const SizedBox(height: 16),
      // Gallery row
      if (_gallery.isNotEmpty) SizedBox(
        height: 70,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _gallery.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) => ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.file(_gallery[i], width: 70, height: 70, fit: BoxFit.cover),
          ),
        ),
      ),
      const SizedBox(height: 16),
      // Info card
      _SectionCard(surface: surface, border: border, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_form.title.isEmpty ? 'Untitled Campaign' : _form.title,
          style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w900, fontSize: 18, color: txt1, letterSpacing: -0.3)),
        const SizedBox(height: 8),
        if (_form.description.isNotEmpty)
          Text(_form.description, maxLines: 3, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: txt2, height: 1.5)),
        const SizedBox(height: 16),
        _PreviewRow('Goal', '${_form.currency} ${_form.goal > 0 ? _formatGoal(_form.goal) : 'Not set'}', Icons.attach_money_rounded, txt1, txt2),
        _PreviewRow('Location', '${loc.name}, Kenya', Icons.location_on_rounded, txt1, txt2),
        _PreviewRow('Category', cat.label, cat.icon, txt1, txt2),
        _PreviewRow('Type', type.label, type.icon, txt1, txt2),
        _PreviewRow('Contact', _form.contactEmail, Icons.mail_outline_rounded, txt1, txt2),
        if (_form.tags.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: _form.tags.map((t) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: AppColors.midGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
            child: Text(t, style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.midGreen)),
          )).toList()),
        ],
      ])),
      const SizedBox(height: 16),
      // Terms
      GestureDetector(
        onTap: () => setState(() => _agreedToTerms = !_agreedToTerms),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _agreedToTerms ? AppColors.midGreen.withOpacity(0.08) : surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _agreedToTerms ? AppColors.midGreen : border, width: _agreedToTerms ? 1.5 : 1),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24, height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _agreedToTerms ? AppColors.midGreen : Colors.transparent,
                border: Border.all(color: _agreedToTerms ? AppColors.midGreen : border, width: 2),
              ),
              child: _agreedToTerms ? const Icon(Icons.check_rounded, color: Colors.white, size: 14) : null,
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Accept terms and conditions', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 13, color: txt1)),
              const SizedBox(height: 3),
              Text('I agree to the terms of service and privacy policy. My campaign will be reviewed before going live.', style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: txt2, height: 1.4)),
            ])),
          ]),
        ),
      ),
      if (_errors['terms'] != null) ...[const SizedBox(height: 6), _ErrorText(_errors['terms']!)],
    ]);
  }

  String _formatGoal(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
    return v.toStringAsFixed(0);
  }

  // ── FOOTER ────────────────────────────────────────────────────────────────
  Widget _buildFooter() {
    final isLast = _stepIndex == steps.length - 1;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: BoxDecoration(
        color: surface,
        border: Border(top: BorderSide(color: border, width: 0.8)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, -4))],
      ),
      child: Row(children: [
        if (_stepIndex > 0) ...[
          _FooterBtn(
            label: 'Back',
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: _back,
            surface: surface, border: border, txt1: txt1, isBack: true,
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: _GradientBtn(
            label: isLast ? 'Create Campaign 🚀' : 'Continue',
            icon: isLast ? Icons.check_circle_rounded : Icons.arrow_forward_ios_rounded,
            onTap: _isSubmitting ? null : _next,
            disabled: isLast && !_agreedToTerms,
          ),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SUBMISSION DIALOG
// ═══════════════════════════════════════════════════════════════════════════════

enum SubmitStatus { idle, loading, success, error }

class _SubmissionDialog extends StatefulWidget {
  final ValueNotifier<SubmitStatus> statusNotifier;
  final _StartCampaignScreenState parent;
  final VoidCallback onClose;
  const _SubmissionDialog({required this.statusNotifier, required this.parent, required this.onClose});
  @override State<_SubmissionDialog> createState() => _SubmissionDialogState();
}

class _SubmissionDialogState extends State<_SubmissionDialog> with TickerProviderStateMixin {
  late final AnimationController _ripple = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
  late final AnimationController _scale  = AnimationController(vsync: this, duration: const Duration(milliseconds: 400), value: 0);

  @override
  void initState() {
    super.initState();
    _scale.forward();
    widget.statusNotifier.addListener(() { if (mounted) setState(() {}); });
  }

  @override
  void dispose() { _ripple.dispose(); _scale.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final status = widget.statusNotifier.value;
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ScaleTransition(
        scale: CurvedAnimation(parent: _scale, curve: Curves.elasticOut),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 40, offset: const Offset(0, 12))]),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (status == SubmitStatus.loading) _loadingWidget()
            else if (status == SubmitStatus.success) _successWidget()
            else _errorWidget(),
          ]),
        ),
      ),
    );
  }

  Widget _loadingWidget() => Column(children: [
    SizedBox(width: 90, height: 90, child: AnimatedBuilder(
      animation: _ripple,
      builder: (_, child) => Stack(alignment: Alignment.center, children: [
        ...List.generate(3, (i) {
          final delay = i * 0.33;
          final val   = (_ripple.value - delay).clamp(0.0, 1.0);
          return Opacity(
            opacity: (1 - val) * 0.4,
            child: Transform.scale(scale: 0.3 + val * 0.7,
              child: Container(decoration: BoxDecoration(shape: BoxShape.circle,
                color: AppColors.midGreen.withOpacity(0.15)))),
          );
        }),
        Container(width: 64, height: 64, decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [AppColors.forestGreen, AppColors.limeGreen])),
          child: const Icon(Icons.upload_rounded, color: Colors.white, size: 30)),
      ]),
    )),
    const SizedBox(height: 20),
    const Text('Launching your campaign', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.ink)),
    const SizedBox(height: 8),
    const Text('This may take a moment…', style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: Color(0xFF6B7280))),
  ]);

  Widget _successWidget() => Column(children: [
    TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.elasticOut,
      builder: (_, v, __) => Transform.scale(scale: v,
        child: Container(width: 80, height: 80, decoration: const BoxDecoration(shape: BoxShape.circle,
          gradient: LinearGradient(colors: [AppColors.midGreen, AppColors.limeGreen])),
          child: const Icon(Icons.check_rounded, color: Colors.white, size: 42))),
    ),
    const SizedBox(height: 20),
    const Text('Campaign Created! 🎉', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w800, fontSize: 20, color: AppColors.ink)),
    const SizedBox(height: 8),
    const Text('Your campaign is under review and will go live shortly.', textAlign: TextAlign.center,
      style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: Color(0xFF6B7280), height: 1.4)),
  ]);

  Widget _errorWidget() => Column(children: [
    Container(width: 80, height: 80, decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.crimson.withOpacity(0.1)),
      child: const Icon(Icons.error_outline_rounded, color: AppColors.crimson, size: 44)),
    const SizedBox(height: 20),
    const Text('Something went wrong', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.ink)),
    const SizedBox(height: 8),
    const Text('Check your connection and try again. Ensure all images are valid.', textAlign: TextAlign.center,
      style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: Color(0xFF6B7280), height: 1.4)),
    const SizedBox(height: 20),
    GestureDetector(
      onTap: () { Navigator.pop(context); widget.onClose(); },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
        decoration: BoxDecoration(color: AppColors.crimson.withOpacity(0.1), borderRadius: BorderRadius.circular(30)),
        child: const Text('Close', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, color: AppColors.crimson)),
      ),
    ),
  ]);
}

// ═══════════════════════════════════════════════════════════════════════════════
// REUSABLE WIDGETS
// ═══════════════════════════════════════════════════════════════════════════════

class _FieldLabel extends StatelessWidget {
  final String text;
  final bool required;
  const _FieldLabel(this.text, {this.required = false});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      Text(text, style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF374151))),
      if (required) const Text(' *', style: TextStyle(color: AppColors.crimson, fontWeight: FontWeight.w700)),
    ]),
  );
}

class _FieldBox extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final String? error;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final IconData? prefixIcon;
  final int? maxLength;
  final void Function(String) onChanged;

  const _FieldBox({
    required this.controller, required this.hint, this.error,
    this.keyboardType = TextInputType.text, this.inputFormatters,
    this.prefixIcon, this.maxLength, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      maxLength: maxLength,
      onChanged: onChanged,
      style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, color: AppColors.ink),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontFamily: 'Poppins', color: Color(0xFFB0BEC5)),
        prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 18, color: const Color(0xFF9E9E9E)) : null,
        counterText: '',
        filled: true, fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: Color(0xFFE0E0E0))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: BorderSide(color: error != null ? AppColors.crimson : const Color(0xFFE0E0E0))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: AppColors.midGreen, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: AppColors.crimson)),
      ),
    ),
    if (error != null) _ErrorText(error!),
  ]);
}

class _StyledTextArea extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final String? error;
  final int minLines;
  final void Function(String) onChanged;
  const _StyledTextArea({required this.controller, required this.hint, this.error, this.minLines = 4, required this.onChanged});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    TextField(
      controller: controller,
      minLines: minLines, maxLines: 12,
      onChanged: onChanged,
      style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.ink, height: 1.55),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: Color(0xFFB0BEC5)),
        filled: true, fillColor: Colors.white,
        contentPadding: const EdgeInsets.all(16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: Color(0xFFE0E0E0))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: BorderSide(color: error != null ? AppColors.crimson : const Color(0xFFE0E0E0))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: AppColors.midGreen, width: 1.5)),
      ),
    ),
    if (error != null) _ErrorText(error!),
  ]);
}

class _DateField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final String? error;
  final VoidCallback onPick;
  const _DateField({required this.controller, required this.hint, this.error, required this.onPick});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    GestureDetector(
      onTap: onPick,
      child: AbsorbPointer(
        child: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: Color(0xFFB0BEC5)),
            suffixIcon: const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.midGreen),
            filled: true, fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: Color(0xFFE0E0E0))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: BorderSide(color: error != null ? AppColors.crimson : const Color(0xFFE0E0E0))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: AppColors.midGreen, width: 1.5)),
          ),
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 13),
        ),
      ),
    ),
    if (error != null) _ErrorText(error!),
  ]);
}

class _DropdownField<T> extends StatelessWidget {
  final T? value;
  final String hint;
  final List<DropdownMenuItem<T>> items;
  final Color surface, border, txt1;
  final void Function(T?) onChanged;
  final String? error;
  final double? width;
  const _DropdownField({required this.value, required this.hint, required this.items, required this.surface, required this.border, required this.txt1, required this.onChanged, this.error, this.width});

  @override
  Widget build(BuildContext context) {
    final child = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        height: 50,
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(13),
          border: Border.all(color: error != null ? AppColors.crimson : border),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: value, hint: Text(hint, style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: Color(0xFFB0BEC5))),
            items: items, onChanged: onChanged,
            isExpanded: width == null, icon: const Icon(Icons.expand_more_rounded, color: AppColors.midGreen, size: 20),
            style: TextStyle(fontFamily: 'Poppins', fontSize: 14, color: txt1),
          ),
        ),
      ),
      if (error != null) _ErrorText(error!),
    ]);
    return width != null ? SizedBox(width: width, child: child) : child;
  }
}

class _TagsField extends StatelessWidget {
  final List<String> tags;
  final TextEditingController controller;
  final Color surface, border, txt1, txt2;
  final void Function(String) onAdd;
  final void Function(String) onRemove;
  const _TagsField({required this.tags, required this.controller, required this.surface, required this.border, required this.txt1, required this.txt2, required this.onAdd, required this.onRemove});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    if (tags.isNotEmpty) Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Wrap(spacing: 8, runSpacing: 8, children: tags.map((t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: AppColors.midGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.midGreen.withOpacity(0.3))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(t, style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.midGreen)),
          const SizedBox(width: 6),
          GestureDetector(onTap: () => onRemove(t), child: const Icon(Icons.close_rounded, size: 14, color: AppColors.midGreen)),
        ]),
      )).toList()),
    ),
    Row(children: [
      Expanded(child: TextField(
        controller: controller,
        onSubmitted: (v) { if (v.trim().isNotEmpty) { onAdd(v.trim().startsWith('#') ? v.trim() : '#${v.trim()}'); controller.clear(); }},
        style: const TextStyle(fontFamily: 'Poppins', fontSize: 13),
        decoration: InputDecoration(
          hintText: 'Add tag and press Enter',
          hintStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: Color(0xFFB0BEC5)),
          prefixIcon: const Icon(Icons.tag_rounded, size: 16, color: AppColors.midGreen),
          filled: true, fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: BorderSide(color: border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: BorderSide(color: border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: AppColors.midGreen)),
        ),
      )),
      const SizedBox(width: 8),
      GestureDetector(
        onTap: () {
          final v = controller.text.trim();
          if (v.isNotEmpty) { onAdd(v.startsWith('#') ? v : '#$v'); controller.clear(); }
        },
        child: Container(
          height: 48, padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(color: AppColors.midGreen, borderRadius: BorderRadius.circular(13)),
          child: const Center(child: Text('Add', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 13, color: Colors.white))),
        ),
      ),
    ]),
  ]);
}

class _ImagePickerPlaceholder extends StatelessWidget {
  final IconData icon;
  final String label, sub;
  final VoidCallback onTap;
  final Color border, txt2;
  final bool compact;
  const _ImagePickerPlaceholder({required this.icon, required this.label, required this.sub, required this.onTap, required this.border, required this.txt2, this.compact = false});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: EdgeInsets.all(compact ? 14 : 28),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.midGreen.withOpacity(0.35), width: 2, style: BorderStyle.none),
        borderRadius: BorderRadius.circular(14),
        color: AppColors.midGreen.withOpacity(0.04),
      ),
      child: Row(mainAxisAlignment: compact ? MainAxisAlignment.start : MainAxisAlignment.center, children: [
        Icon(icon, size: compact ? 22 : 36, color: AppColors.midGreen.withOpacity(0.7)),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.midGreen)),
          Text(sub, style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: txt2)),
        ]),
      ]),
    ),
  );
}

class _FeaturedImagePreview extends StatelessWidget {
  final File file;
  final VoidCallback onRemove;
  const _FeaturedImagePreview({required this.file, required this.onRemove});
  @override
  Widget build(BuildContext context) => Stack(children: [
    ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: AspectRatio(aspectRatio: 16/9, child: Image.file(file, fit: BoxFit.cover, width: double.infinity)),
    ),
    Positioned(top: 8, right: 8, child: GestureDetector(
      onTap: onRemove,
      child: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(color: AppColors.crimson, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 6)]),
        child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
      ),
    )),
  ]);
}

class _GalleryGrid extends StatelessWidget {
  final List<File> files;
  final void Function(int) onRemove;
  const _GalleryGrid({required this.files, required this.onRemove});
  @override
  Widget build(BuildContext context) => GridView.builder(
    shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8),
    itemCount: files.length,
    itemBuilder: (_, i) => Stack(clipBehavior: Clip.none, children: [
      ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.file(files[i], fit: BoxFit.cover, width: double.infinity, height: double.infinity)),
      Positioned(top: -4, right: -4, child: GestureDetector(
        onTap: () => onRemove(i),
        child: Container(width: 24, height: 24, decoration: const BoxDecoration(color: AppColors.crimson, shape: BoxShape.circle),
          child: const Icon(Icons.close_rounded, color: Colors.white, size: 14)),
      )),
    ]),
  );
}

class _SectionCard extends StatelessWidget {
  final Widget child;
  final Color surface, border;
  const _SectionCard({required this.child, required this.surface, required this.border});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: border),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3))]),
    child: child,
  );
}

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color txt2;
  final Color? color;
  final Color? iconColor;
  const _InfoBanner({required this.icon, required this.text, required this.txt2, this.color, this.iconColor});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: color ?? AppColors.midGreen.withOpacity(0.08), borderRadius: BorderRadius.circular(12),
      border: Border.all(color: (iconColor ?? AppColors.midGreen).withOpacity(0.2))),
    child: Row(children: [
      Icon(icon, size: 18, color: iconColor ?? AppColors.midGreen),
      const SizedBox(width: 10),
      Expanded(child: Text(text, style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: txt2, height: 1.4))),
    ]),
  );
}

class _ErrorText extends StatelessWidget {
  final String text;
  const _ErrorText(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Row(children: [
      const Icon(Icons.error_outline_rounded, size: 13, color: AppColors.crimson),
      const SizedBox(width: 5),
      Expanded(child: Text(text, style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.crimson))),
    ]),
  );
}

class _GoalPreviewCard extends StatelessWidget {
  final double goal;
  final String currency;
  final Color surface, border, txt1, txt2;
  const _GoalPreviewCard({required this.goal, required this.currency, required this.surface, required this.border, required this.txt1, required this.txt2});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [AppColors.forestGreen, AppColors.midGreen], begin: Alignment.topLeft, end: Alignment.bottomRight),
      borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(color: AppColors.midGreen.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6))],
    ),
    child: Row(children: [
      const Icon(Icons.savings_rounded, color: Colors.white70, size: 36),
      const SizedBox(width: 14),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Fundraising Goal', style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: Colors.white70)),
        Text('$currency ${_fmt(goal)}', style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w900, fontSize: 26, color: Colors.white, letterSpacing: -0.5)),
      ]),
    ]),
  );
  String _fmt(double v) {
    if (v >= 1000000) return '${(v/1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v/1000).toStringAsFixed(0)}K';
    return v.toStringAsFixed(0);
  }
}

class _InfoChip extends StatelessWidget {
  final String label, value;
  final Color surface, txt1, txt2;
  const _InfoChip({required this.label, required this.value, required this.surface, required this.txt1, required this.txt2});
  @override
  Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
    decoration: BoxDecoration(color: surface.withOpacity(0.5), borderRadius: BorderRadius.circular(10)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontFamily: 'Poppins', fontSize: 10, color: txt2)),
      const SizedBox(height: 2),
      Text(value, style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 13, color: txt1), overflow: TextOverflow.ellipsis),
    ]),
  ));
}

class _PreviewRow extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color txt1, txt2;
  const _PreviewRow(this.label, this.value, this.icon, this.txt1, this.txt2);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(children: [
      Icon(icon, size: 16, color: AppColors.midGreen),
      const SizedBox(width: 10),
      Text('$label: ', style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: txt2)),
      Expanded(child: Text(value, style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 13, color: txt1), overflow: TextOverflow.ellipsis)),
    ]),
  );
}

class _PreviewBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _PreviewBadge(this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: color.withOpacity(0.9), borderRadius: BorderRadius.circular(20)),
    child: Text(label, style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 11, color: Colors.white)),
  );
}

class _FooterBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color surface, border, txt1;
  final bool isBack;
  const _FooterBtn({required this.label, required this.icon, required this.onTap, required this.surface, required this.border, required this.txt1, required this.isBack});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 52, padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: border)),
      child: Row(children: [
        Icon(icon, size: 16, color: txt1),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 13, color: txt1)),
      ]),
    ),
  );
}

class _GradientBtn extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool disabled;
  const _GradientBtn({required this.label, required this.icon, this.onTap, this.disabled = false});
  @override State<_GradientBtn> createState() => _GradientBtnState();
}

class _GradientBtnState extends State<_GradientBtn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 140));
  late final Animation<double> _s = Tween(begin: 1.0, end: 0.96).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));
  @override void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final active = widget.onTap != null && !widget.disabled;
    return GestureDetector(
      onTapDown: active ? (_) => _c.forward() : null,
      onTapUp: active ? (_) async { await _c.reverse(); widget.onTap?.call(); } : null,
      onTapCancel: () => _c.reverse(),
      child: ScaleTransition(
        scale: _s,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 52,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: active ? [AppColors.forestGreen, AppColors.limeGreen] : [const Color(0xFFB0B0B0), const Color(0xFFCCCCCC)],
              begin: Alignment.centerLeft, end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: active ? [BoxShadow(color: AppColors.midGreen.withOpacity(0.4), blurRadius: 14, offset: const Offset(0, 5))] : [],
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(widget.label, style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w800, fontSize: 14, color: Colors.white)),
            const SizedBox(width: 8),
            Icon(widget.icon, color: Colors.white, size: 17),
          ]),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// UPDATED HOME SCREEN NAV — navigate to StartCampaignScreen on FAB tap
// (Drop-in replacement for the _HomeScreenState's _buildNav)
// ═══════════════════════════════════════════════════════════════════════════════

// Page transition is defined in home_screen.dart as _campaignRoute().
// StartCampaignScreen is launched by HomeScreen._openCreateCampaign()
// which reads auth token + user from AuthProvider automatically.