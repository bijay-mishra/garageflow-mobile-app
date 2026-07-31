import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../state/auth_controller.dart';
import '../../widgets/gradient_header.dart';
import '../../widgets/profile_avatar.dart';
import '../../widgets/states.dart';

/// Name, email, phone — the three things a person can change about themselves.
///
/// Role, company code and the customer or mechanic link are shown but not
/// editable: those are the workshop's decisions about this account, not the
/// account holder's, and the dashboard is where they are made.
class AccountEditScreen extends StatefulWidget {
  const AccountEditScreen({super.key});

  @override
  State<AccountEditScreen> createState() => _AccountEditScreenState();
}

class _AccountEditScreenState extends State<AccountEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _phone;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthController>().user;
    _name = TextEditingController(text: user?.name ?? '');
    _email = TextEditingController(text: user?.email ?? '');
    _phone = TextEditingController(text: user?.phone ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final failure = await context.read<AuthController>().updateProfile(
      name: _name.text,
      email: _email.text,
      phone: _phone.text,
    );

    if (!mounted) return;

    if (failure != null) {
      showSnack(context, failure, isError: true);
      return;
    }

    showSnack(context, AppText.of(context)('account.saved'));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final user = auth.user;
    final t = AppText.of(context);
    final palette = AppTheme.of(context);

    if (user == null) return const SizedBox.shrink();

    return Scaffold(
      appBar: GradientAppBar(title: t('account.title')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        children: [
          Center(
            child: Column(
              children: [
                const ProfilePhotoButton(size: 88),
                const SizedBox(height: 10),
                Text(
                  t('profile.editPhoto'),
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.brand,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          AppCard(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: t('account.name'),
                      prefixIcon: const Icon(
                        Icons.person_outline_rounded,
                        size: 20,
                      ),
                    ),
                    validator: (v) => (v?.trim().length ?? 0) < 2
                        ? t('signup.enterName')
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    decoration: InputDecoration(
                      labelText: t('account.email'),
                      helperText: t('account.emailNote'),
                      helperMaxLines: 2,
                      prefixIcon: const Icon(
                        Icons.mail_outline_rounded,
                        size: 20,
                      ),
                    ),
                    validator: (v) {
                      final text = v?.trim() ?? '';
                      if (text.isEmpty) return t('auth.enterEmail');
                      if (!text.contains('@') || !text.contains('.')) {
                        return t('auth.badEmail');
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: t('account.phone'),
                      prefixIcon: const Icon(Icons.call_outlined, size: 20),
                    ),
                  ),

                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: auth.busy ? null : _save,
                    child: auth.busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : Text(t('common.save')),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 22),
          SectionLabel(t('profile.workshop')),
          AppCard(
            child: Column(
              children: [
                _Fact(label: t('account.role'), value: user.role),
                _Fact(
                  label: t('account.companyCode'),
                  value: user.companyCode.isEmpty ? '—' : user.companyCode,
                ),
                if (user.workshop.isNotEmpty)
                  _Fact(label: t('profile.workshop'), value: user.workshop),
                if (user.isMechanic && user.mechanicName != null)
                  _Fact(
                    label: t('account.assignedAs'),
                    value: user.mechanicName!,
                  ),
                if (user.isCustomer && user.customerId != null)
                  _Fact(
                    label: t('account.customerRef'),
                    value: user.customerId!,
                  ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          Text(
            t('about.accountManaged'),
            style: TextStyle(fontSize: 12, color: palette.faint, height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = AppTheme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 116,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: palette.faint),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: palette.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
