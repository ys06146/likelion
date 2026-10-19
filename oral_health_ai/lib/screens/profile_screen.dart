import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'auth/sign_in_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  bool _isSaving = false;

  String _fullName = '';
  final TextEditingController _ageController = TextEditingController();
  String _gender = 'Not set';
  String _bloodType = 'Not set';
  bool _smoker = false;
  bool _alcohol = false;

  final List<String> _genderOptions = const [
    'Not set',
    'Male',
    'Female',
    'Others',
  ];

  final List<String> _bloodTypeOptions = const [
    'Not set',
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-',
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
    });

    await AuthService.refreshProfileFromServer();
    final profile = await AuthService.getSavedProfile();

    if (!mounted) return;

    setState(() {
      _fullName = profile['full_name']?.toString() ?? '';
      _ageController.text = profile['age']?.toString() ?? '';
      _gender = profile['gender']?.toString() ?? 'Not set';
      _bloodType = profile['blood_type']?.toString() ?? 'Not set';
      _smoker = profile['smoker'] == true;
      _alcohol = profile['alcohol'] == true;
      _isLoading = false;
    });
  }

  Future<void> _editAge() async {
    final tempController = TextEditingController(text: _ageController.text);

    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Age'),
        content: TextField(
          controller: tempController,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Enter your age'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, tempController.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == null || result.isEmpty) return;

    final parsed = int.tryParse(result);
    if (parsed == null || parsed <= 0 || parsed > 120) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid age.')),
      );
      return;
    }

    setState(() {
      _ageController.text = parsed.toString();
    });
  }

  Future<void> _editGender() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: _genderOptions
              .map(
                (item) => ListTile(
                  title: Text(item),
                  trailing: item == _gender
                      ? const Icon(Icons.check, color: Color(0xFF0C8A8A))
                      : null,
                  onTap: () => Navigator.pop(context, item),
                ),
              )
              .toList(),
        ),
      ),
    );

    if (result == null) return;

    setState(() {
      _gender = result;
    });
  }

  Future<void> _editBloodType() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _bloodTypeOptions
                .map(
                  (item) => ListTile(
                    title: Text(item),
                    trailing: item == _bloodType
                        ? const Icon(Icons.check, color: Color(0xFF0C8A8A))
                        : null,
                    onTap: () => Navigator.pop(context, item),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );

    if (result == null) return;

    setState(() {
      _bloodType = result;
    });
  }

  Future<void> _saveProfile() async {
    final age = int.tryParse(_ageController.text.trim());

    if (_ageController.text.isNotEmpty &&
        (age == null || age <= 0 || age > 120)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid age.')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final result = await AuthService.updateProfile(
      fullName: _fullName,
      age: age,
      gender: _gender == 'Not set' ? null : _gender,
      bloodType: _bloodType == 'Not set' ? null : _bloodType,
      smoker: _smoker,
      alcohol: _alcohol,
    );

    if (!mounted) return;

    setState(() {
      _isSaving = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result['success'] == true
              ? 'Profile saved successfully.'
              : (result['message']?.toString() ?? 'Failed to save profile.'),
        ),
      ),
    );
  }

  Future<void> _logout() async {
    await AuthService.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const SignInScreen()),
      (_) => false,
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: Color(0xFF9B9BA1),
      ),
    );
  }

  Widget _card(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F9),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(children: children),
    );
  }

  Widget _divider() {
    return const Divider(height: 1, thickness: 1, color: Color(0xFFEAEAF0));
  }

  Widget _editableRow({
    required String title,
    required String value,
    required VoidCallback onTap,
    bool isLast = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.black,
                    ),
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF9B9BA1),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, color: Color(0xFFBDBDC3)),
              ],
            ),
          ),
          if (!isLast) _divider(),
        ],
      ),
    );
  }

  Widget _toggleRow({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool isLast = false,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.black,
                  ),
                ),
              ),
              Switch(
                value: value,
                onChanged: onChanged,
                activeThumbColor: const Color(0xFF0C8A8A),
              ),
            ],
          ),
        ),
        if (!isLast) _divider(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final ageText = _ageController.text.isEmpty
        ? 'Not set'
        : _ageController.text;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'My Profile',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: Color(0xFF0C8A8A)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Center(
                      child: Container(
                        width: 122,
                        height: 122,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [Color(0xFF4AA8B3), Color(0xFF74D3D1)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: const Icon(
                          Icons.person,
                          size: 56,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Center(
                      child: Text(
                        _fullName,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Center(
                      child: Text(
                        'Your saved profile',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFFB0B0B7),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    _sectionTitle('PERSONAL INFO'),
                    const SizedBox(height: 12),
                    _card([
                      _editableRow(
                        title: 'Age',
                        value: ageText,
                        onTap: _editAge,
                      ),
                      _editableRow(
                        title: 'Gender',
                        value: _gender,
                        onTap: _editGender,
                      ),
                      _editableRow(
                        title: 'Blood Type',
                        value: _bloodType,
                        onTap: _editBloodType,
                        isLast: true,
                      ),
                    ]),

                    const SizedBox(height: 26),
                    _sectionTitle('HEALTH FACTORS'),
                    const SizedBox(height: 12),
                    _card([
                      _toggleRow(
                        title: 'Smoker',
                        value: _smoker,
                        onChanged: (value) {
                          setState(() {
                            _smoker = value;
                          });
                        },
                      ),
                      _toggleRow(
                        title: 'Regular Alcohol Consumption',
                        value: _alcohol,
                        onChanged: (value) {
                          setState(() {
                            _alcohol = value;
                          });
                        },
                        isLast: true,
                      ),
                    ]),

                    const SizedBox(height: 26),
                    _sectionTitle('ACCOUNT'),
                    const SizedBox(height: 12),
                    _card([
                      InkWell(
                        onTap: _logout,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 22,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Log Out',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.red,
                                  ),
                                ),
                              ),
                              Icon(Icons.logout, color: Colors.red),
                            ],
                          ),
                        ),
                      ),
                    ]),

                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0C8A8A),
                          disabledBackgroundColor: const Color(0xFF9BC9C9),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Save Profile',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
