import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  final ImagePicker _imagePicker = ImagePicker();
  late final Future<DocumentSnapshot<Map<String, dynamic>>> _profileDocument;
  String? _photoUrl;
  bool _uploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser!;
    _profileDocument = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
  }

  Future<void> _changeProfilePhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Tirar foto'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Escolher da galeria'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    try {
      final image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (image == null) return;
      if (!mounted) return;

      setState(() => _uploadingPhoto = true);
      final user = FirebaseAuth.instance.currentUser!;
      final bytes = await image.readAsBytes();
      final reference = FirebaseStorage.instance.ref().child(
        'profile_images/${user.uid}/profile',
      );
      await reference.putData(
        bytes,
        SettableMetadata(contentType: image.mimeType ?? 'image/jpeg'),
      );
      final url = await reference.getDownloadURL();
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'fotoPerfil': url,
      }, SetOptions(merge: true));

      if (mounted) {
        setState(() => _photoUrl = url);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto de perfil atualizada.')),
        );
      }
    } on FirebaseException catch (error) {
      debugPrint(
        'Erro Firebase ao atualizar foto de perfil: '
        '${error.code} - ${error.message}',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Não foi possível salvar a foto: '
              '${error.message ?? error.code}',
            ),
          ),
        );
      }
    } catch (error) {
      debugPrint('Erro ao atualizar foto de perfil: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível atualizar a foto.')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  void _openPersonalData() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const PersonalDataScreen()));
  }

  void _openMyReports() {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const MyReportsScreen()));
  }

  void _openNotifications() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const NotificationsScreen()),
    );
  }

  void _openCredentials() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const CredentialsScreen()));
  }

  Future<void> _confirmLogout() async {
    final sair = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sair da conta?'),
        content: const Text('Tem certeza de que deseja sair da sua conta?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
    if (sair != true) return;

    try {
      final preferencias = await SharedPreferences.getInstance();
      await preferencias.remove('perfil_usuario');
      await FirebaseAuth.instance.signOut();
    } catch (error) {
      debugPrint('Erro ao sair da conta: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível sair da conta.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meu perfil'),
        foregroundColor: Colors.purple,
      ),
      body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: _profileDocument,
        builder: (context, snapshot) {
          final storedPhoto = snapshot.data?.data()?['fotoPerfil'] as String?;
          final photoUrl = _photoUrl ?? storedPhoto ?? user.photoURL;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 56,
                      backgroundColor: Colors.purple.shade100,
                      backgroundImage: photoUrl == null
                          ? null
                          : NetworkImage(photoUrl),
                      child: photoUrl == null
                          ? const Icon(
                              Icons.person,
                              size: 58,
                              color: Colors.purple,
                            )
                          : null,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: IconButton.filled(
                        onPressed: _uploadingPhoto ? null : _changeProfilePhoto,
                        tooltip: 'Adicionar foto de perfil',
                        icon: _uploadingPhoto
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.camera_alt),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                user.displayName ?? user.email ?? 'Usuário SOS Pet',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (user.email != null) ...[
                const SizedBox(height: 4),
                Text(
                  user.email!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black54),
                ),
              ],
              if (snapshot.hasError)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Não foi possível carregar a foto salva.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              const SizedBox(height: 24),
              Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.assignment_outlined,
                    color: Colors.purple,
                  ),
                  title: const Text('Minhas denúncias'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _openMyReports,
                ),
              ),
              Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.notifications_none,
                    color: Colors.purple,
                  ),
                  title: const Text('Notificações'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _openNotifications,
                ),
              ),
              Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.person_outline,
                    color: Colors.purple,
                  ),
                  title: const Text('Dados pessoais'),
                  subtitle: const Text('Adicionar número de telefone'),
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
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _confirmLogout,
                icon: const Icon(Icons.logout),
                label: const Text('Sair da conta'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class MyReportsScreen extends StatelessWidget {
  const MyReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;
    final reports = FirebaseFirestore.instance
        .collection('denuncias')
        .where('usuarioId', isEqualTo: user.uid);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Minhas denúncias'),
        foregroundColor: Colors.purple,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: reports.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('Não foi possível carregar suas denúncias.'),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final documents = [...?snapshot.data?.docs]
            ..sort((a, b) {
              final aDate = a.data()['criadoEm'];
              final bDate = b.data()['criadoEm'];
              if (aDate is! Timestamp || bDate is! Timestamp) return 0;
              return bDate.compareTo(aDate);
            });
          if (documents.isEmpty) {
            return const Center(child: Text('Você ainda não fez denúncias.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: documents.length,
            itemBuilder: (context, index) {
              final report = documents[index].data();
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.pets, color: Colors.purple),
                  title: Text(
                    (report['descricao'] as String?)?.trim().isNotEmpty == true
                        ? report['descricao'] as String
                        : (report['tipo'] as String? ?? 'Denúncia'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${report['status'] ?? 'Status indisponível'}'
                    ' • ${report['endereco'] ?? 'Local não informado'}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificações'),
        foregroundColor: Colors.purple,
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.notifications_none, size: 56, color: Colors.purple),
              SizedBox(height: 12),
              Text('Você não possui novas notificações no momento.'),
            ],
          ),
        ),
      ),
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

  Future<void> _savePhoneNumber() async {
    final phoneNumber = normalizePhoneNumber(_phoneController.text);
    if (phoneNumber == null) {
      _showMessage('Informe um telefone válido com código do país.');
      return;
    }

    setState(() => _carregando = true);
    try {
      await saveUserProfile(_user, phoneNumber: phoneNumber);
      if (mounted) {
        _phoneController.text = phoneNumber;
        _showMessage('Telefone salvo nos dados da sua conta.');
      }
    } on FirebaseException catch (error) {
      debugPrint(
        'Erro Firebase ao salvar telefone: ${error.code} - ${error.message}',
      );
      if (mounted) {
        _showMessage(
          'Não foi possível salvar o telefone: '
          '${error.message ?? error.code}',
        );
      }
    } catch (error) {
      debugPrint('Erro ao salvar telefone: $error');
      if (mounted) {
        _showMessage('Não foi possível salvar o telefone. Tente novamente.');
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
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
                  enabled: !_carregando,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Telefone/celular',
                    hintText: '+55 11 99999-9999',
                    prefixIcon: Icon(Icons.phone, color: Colors.purple),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _carregando ? null : _savePhoneNumber,
                  icon: _carregando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(
                    _carregando ? 'Salvando telefone...' : 'Salvar telefone',
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
