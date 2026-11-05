import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

String userSetupPendingKey(String uid) => 'configuracao_inicial_pendente_$uid';

String? normalizePhoneNumber(String value) {
  final input = value.trim();
  if (input.isEmpty) return null;
  if (input.startsWith('+')) {
    final international =
        '+${input.substring(1).replaceAll(RegExp(r'\D'), '')}';
    return RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(international)
        ? international
        : null;
  }

  final digits = input.replaceAll(RegExp(r'\D'), '');
  final international = switch (digits.length) {
    10 || 11 => '+55$digits',
    12 || 13 when digits.startsWith('55') => '+$digits',
    _ => null,
  };
  return international != null &&
          RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(international)
      ? international
      : null;
}

Future<void> saveUserProfile(
  User user, {
  String? phoneNumber,
  bool? initialSetupPending,
  String? role,
}) async {
  if (role != null && !['Denunciante', 'Ong/Clinica'].contains(role)) {
    throw ArgumentError.value(role, 'role', 'Perfil inválido.');
  }

  final reference = FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid);
  final profile = <String, Object>{'uid': user.uid, 'email': user.email ?? ''};
  final telefone = phoneNumber ?? user.phoneNumber;
  if (telefone != null) {
    profile['telefone'] = telefone;
  }
  if (initialSetupPending != null) {
    profile['configuracaoInicialPendente'] = initialSetupPending;
  }
  if (role != null) {
    profile['perfil'] = role;
  }

  await reference.set(profile, SetOptions(merge: true));
}

Future<void> saveUserRole(User user, String role) async {
  if (!['Denunciante', 'Ong/Clinica'].contains(role)) {
    throw ArgumentError.value(role, 'role', 'Perfil inválido.');
  }

  await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
    'uid': user.uid,
    'email': user.email ?? '',
    'perfil': role,
    'configuracaoInicialPendente': false,
  }, SetOptions(merge: true));
}

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  late Future<void> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = saveUserProfile(FirebaseAuth.instance.currentUser!);
  }

  Future<void> _openPersonalData() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const PersonalDataScreen()));
    if (mounted) {
      setState(() {
        _profileFuture = saveUserProfile(FirebaseAuth.instance.currentUser!);
      });
    }
  }

  void _openCredentials() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const CredentialsScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;
    final telefoneVerificado = user.phoneNumber != null;

    return FutureBuilder<void>(
      future: _profileFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Não foi possível carregar seus dados: ${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            CircleAvatar(
              radius: 38,
              backgroundColor: Colors.purple.shade100,
              child: const Icon(Icons.person, size: 42, color: Colors.purple),
            ),
            const SizedBox(height: 12),
            Text(
              user.displayName ?? user.email ?? 'Usuário SOS Pet',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            if (user.email != null) ...[
              const SizedBox(height: 4),
              Text(
                user.email!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54),
              ),
            ],
            const SizedBox(height: 24),
            Card(
              child: ListTile(
                leading: Icon(
                  telefoneVerificado ? Icons.verified : Icons.pending_actions,
                  color: telefoneVerificado ? Colors.green : Colors.orange,
                ),
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.person_outline, color: Colors.purple),
                title: const Text('Dados pessoais'),
                subtitle: const Text('Telefone e confirmação por SMS'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _openPersonalData,
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.key, color: Colors.purple),
                title: const Text('Credenciais'),
                subtitle: const Text('E-mail e forma de acesso'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _openCredentials,
              ),
            ),
          ],
        );
      },
    );
  }
}

class PersonalDataScreen extends StatefulWidget {
  const PersonalDataScreen({super.key});

  @override
  State<PersonalDataScreen> createState() => _PersonalDataScreenState();
}

class _PersonalDataScreenState extends State<PersonalDataScreen> {
  final _phoneController = TextEditingController();
  bool _carregando = false;
  bool _carregandoDados = true;

  User get _user => FirebaseAuth.instance.currentUser!;

  @override
  void initState() {
    super.initState();
    _loadPhone();
  }

  Future<void> _loadPhone() async {
    try {
      await saveUserProfile(_user);
      final document = await FirebaseFirestore.instance
          .collection('users')
          .doc(_user.uid)
          .get();
      _phoneController.text = document.data()?['telefone'] as String? ?? '';
    } catch (error) {
      debugPrint('Erro ao carregar telefone do perfil: $error');
      if (mounted) _showMessage('Não foi possível carregar seus dados.');
    } finally {
      if (mounted) setState(() => _carregandoDados = false);
    }
  }

  Future<void> _sendVerificationCode() async {
    final phoneNumber = normalizePhoneNumber(_phoneController.text);
    if (phoneNumber == null) {
      _showMessage('Informe um telefone válido com código do país.');
      return;
    }

    setState(() => _carregando = true);
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (credential) {
          _linkVerifiedPhone(credential, phoneNumber);
        },
        verificationFailed: (error) {
          if (mounted) {
            _showMessage(_phoneErrorMessage(error));
            setState(() => _carregando = false);
          }
        },
        codeSent: (verificationId, _) {
          _askForSmsCode(verificationId, phoneNumber);
        },
        codeAutoRetrievalTimeout: (_) {},
      );
    } on FirebaseAuthException catch (error) {
      _showMessage(_phoneErrorMessage(error));
    } catch (error) {
      debugPrint('Erro ao enviar código SMS: $error');
      _showMessage('Não foi possível enviar o código. Tente novamente.');
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _askForSmsCode(String verificationId, String phoneNumber) async {
    final codeController = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirme seu telefone'),
        content: TextField(
          controller: codeController,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Código recebido por SMS',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(dialogContext, codeController.text.trim()),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    codeController.dispose();
    if (code == null || code.isEmpty || !mounted) return;

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: code,
      );
      await _linkVerifiedPhone(credential, phoneNumber);
    } on FirebaseAuthException catch (error) {
      _showMessage(_phoneErrorMessage(error));
    } catch (error) {
      debugPrint('Erro ao confirmar telefone: $error');
      _showMessage('Não foi possível confirmar o telefone. Tente novamente.');
    }
  }

  Future<void> _linkVerifiedPhone(
    PhoneAuthCredential credential,
    String phoneNumber,
  ) async {
    try {
      await _user.updatePhoneNumber(credential);
      await _user.reload();
      await saveUserProfile(_user, phoneNumber: phoneNumber);
      if (mounted) {
        _phoneController.text = phoneNumber;
        setState(() {});
        _showMessage('Telefone confirmado com sucesso.');
      }
    } on FirebaseAuthException catch (error) {
      if (mounted) _showMessage(_phoneErrorMessage(error));
    } catch (error) {
      debugPrint('Erro ao salvar telefone confirmado: $error');
      if (mounted) _showMessage('Não foi possível salvar o telefone.');
    }
  }

  String _phoneErrorMessage(FirebaseAuthException error) {
    return switch (error.code) {
      'invalid-phone-number' => 'O número de telefone é inválido.',
      'invalid-verification-code' => 'O código SMS informado está incorreto.',
      'session-expired' => 'O código expirou. Solicite um novo código.',
      'too-many-requests' => 'Muitas tentativas. Tente novamente mais tarde.',
      'credential-already-in-use' =>
        'Este telefone já está vinculado a outra conta.',
      'provider-already-linked' => 'Este telefone já foi confirmado.',
      _ =>
        'Não foi possível confirmar o telefone: ${error.message ?? error.code}',
    };
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final verified = _user.phoneNumber != null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dados pessoais'),
        foregroundColor: Colors.purple,
      ),
      body: _carregandoDados
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.email, color: Colors.purple),
                  title: const Text('E-mail'),
                  subtitle: Text(_user.email ?? 'Não informado'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Telefone/celular',
                    hintText: '+55 11 99999-9999',
                    prefixIcon: Icon(Icons.phone, color: Colors.purple),
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
    );
  }
}

class CredentialsScreen extends StatelessWidget {
  const CredentialsScreen({super.key});

  Future<void> _sendPasswordReset(BuildContext context, String email) async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('E-mail de redefinição enviado.')),
        );
      }
    } on FirebaseAuthException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Não foi possível enviar o e-mail: ${error.message ?? error.code}',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;
    final usesPassword = user.providerData.any(
      (provider) => provider.providerId == 'password',
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Credenciais'),
        foregroundColor: Colors.purple,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: const Icon(Icons.email, color: Colors.purple),
            title: const Text('E-mail'),
            subtitle: Text(user.email ?? 'Não informado'),
          ),
          ListTile(
            leading: const Icon(Icons.login, color: Colors.purple),
            title: const Text('Forma de acesso'),
            subtitle: Text(usesPassword ? 'E-mail e senha' : 'Google'),
          ),
          if (usesPassword)
            ListTile(
              leading: const Icon(Icons.lock_reset, color: Colors.purple),
              title: const Text('Redefinir senha'),
              trailing: const Icon(Icons.chevron_right),
              onTap: user.email == null
                  ? null
                  : () => _sendPasswordReset(context, user.email!),
            ),
        ],
      ),
    );
  }
}
