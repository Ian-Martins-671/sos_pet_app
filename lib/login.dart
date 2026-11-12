import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sos_pet/user_profile.dart';

String? _androidClientBlockedMessage(FirebaseAuthException error) {
  final message = error.message?.toLowerCase() ?? '';
  if (!message.contains('requests from this android client application')) {
    return null;
  }
  return 'O Firebase está bloqueando este app Android. Confira no Google Cloud '
      'as restrições da chave de API, o pacote do app e o SHA-1 do APK.';
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _emailController = TextEditingController();

  final TextEditingController _passwordController = TextEditingController();

  bool _carregando = false;

  // Login com e-mail e senha pelo Firebase Authentication.
  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _carregando = true;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    } on FirebaseAuthException catch (e, stackTrace) {
      debugPrint(
        'AUTH_DIAGNOSTIC login FirebaseAuthException: '
        'code=${e.code}, message=${e.message}',
      );
      debugPrintStack(stackTrace: stackTrace);
      final mensagem =
          _androidClientBlockedMessage(e) ??
          switch (e.code) {
            'invalid-email' => 'O e-mail informado é inválido.',
            'user-not-found' || 'invalid-credential' =>
              'E-mail ou senha incorretos.',
            'wrong-password' => 'A senha informada está incorreta.',
            'user-disabled' => 'Esta conta foi desativada.',
            'too-many-requests' =>
              'Muitas tentativas. Tente novamente mais tarde.',
            'network-request-failed' =>
              'Verifique sua conexão com a internet.',
            'operation-not-allowed' =>
              'O login por e-mail está desativado no Firebase. Ative esse provedor para continuar.',
            _ => 'Não foi possível entrar. Tente novamente.',
          };

      _mostrarMensagem(mensagem);
    } catch (e, stackTrace) {
      _mostrarMensagem('Ocorreu um erro inesperado.');
      debugPrint('AUTH_DIAGNOSTIC login erro inesperado: $e');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      if (mounted) {
        setState(() {
          _carregando = false;
        });
      }
    }
  }

  // Login com uma conta Google.
  Future<void> _loginWithGoogle() async {
    setState(() {
      _carregando = true;
    });

    try {
      debugPrint('AUTH_DIAGNOSTIC Google: abrindo fluxo de autenticação');
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

      // Se o usuário fechar a janela, cancela o processo.
      if (googleUser == null) {
        debugPrint('AUTH_DIAGNOSTIC Google: fluxo cancelado pelo usuário');
        return;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      debugPrint('AUTH_DIAGNOSTIC Google: tokens obtidos');

      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final result = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );
      debugPrint('AUTH_DIAGNOSTIC Google: autenticação Firebase concluída');
      final user = result.user!;
      if (result.additionalUserInfo?.isNewUser ?? false) {
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool(userSetupPendingKey(user.uid), true);
        } catch (error, stackTrace) {
          debugPrint(
            'AUTH_DIAGNOSTIC Google erro no SharedPreferences: $error',
          );
          debugPrintStack(stackTrace: stackTrace);
        }
      }
      await saveUserProfile(
        user,
        initialSetupPending: result.additionalUserInfo?.isNewUser == true
            ? true
            : null,
      );
      debugPrint('AUTH_DIAGNOSTIC Google: perfil sincronizado');
    } on FirebaseAuthException catch (e, stackTrace) {
      debugPrint(
        'AUTH_DIAGNOSTIC Google FirebaseAuthException: '
        'code=${e.code}, message=${e.message}',
      );
      debugPrintStack(stackTrace: stackTrace);
      _mostrarMensagem(
        _androidClientBlockedMessage(e) ??
            'Não foi possível entrar com o Google.',
      );
    } catch (e, stackTrace) {
      debugPrint('AUTH_DIAGNOSTIC Google erro inesperado: $e');
      debugPrintStack(stackTrace: stackTrace);
      _mostrarMensagem('Falha ao entrar com o Google. Tente novamente.');
    } finally {
      if (mounted) {
        setState(() {
          _carregando = false;
        });
      }
    }
  }

  Future<void> _abrirCadastro() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const RegisterScreen()),
    );
  }

  void _mostrarMensagem(String mensagem) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensagem), backgroundColor: Colors.red),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 255, 202, 248),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/images/icon/iconsospet.png',
                    width: 96,
                    height: 96,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'SOS Pet',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple,
                    ),
                  ),

                  const SizedBox(height: 12),

                  const Text(
                    'Entre ou cadastre-se para ajudar a proteger os animais.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.black54),
                  ),

                  const SizedBox(height: 40),

                  // Campo de e-mail.
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    decoration: InputDecoration(
                      labelText: 'E-mail',
                      hintText: 'exemplo@email.com',
                      prefixIcon: const Icon(Icons.email, color: Colors.purple),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Informe seu e-mail.';
                      }
                      if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                          .hasMatch(value.trim())) {
                        return 'Informe um e-mail válido.';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // Campo de senha.
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Senha',
                      hintText: 'Digite sua senha',
                      prefixIcon: const Icon(Icons.lock, color: Colors.purple),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Informe sua senha.';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 24),

                  // Botão de login tradicional.
                  ElevatedButton(
                    onPressed: _carregando ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _carregando
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'ENTRAR',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),

                  const SizedBox(height: 16),

                  TextButton(
                    onPressed: _carregando ? null : _abrirCadastro,
                    child: const Text(
                      'Cadastre-se',
                      style: TextStyle(
                        color: Colors.purple,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Botão de login com Google.
                  OutlinedButton(
                    onPressed: _carregando ? null : _loginWithGoogle,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.purple,
                      side: const BorderSide(color: Colors.purple),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.g_mobiledata, size: 28),
                        SizedBox(width: 8),
                        Text(
                          'Entrar com Google',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cnpjController = TextEditingController();
  bool _carregando = false;
  String? _perfilSelecionado;

  Future<void> _cadastrar() async {
    if (!_formKey.currentState!.validate()) return;

    final perfil = _perfilSelecionado;
    if (perfil == null) {
      _mostrarMensagem('Selecione se sua conta é de denunciante ou de ONG.');
      return;
    }

    final telefone = normalizePhoneNumber(_phoneController.text);
    if (telefone == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Informe um telefone válido, incluindo o código do país.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    final cnpj = perfil == 'Ong/Clinica'
        ? normalizeCnpj(_cnpjController.text)
        : null;
    if (perfil == 'Ong/Clinica' && cnpj == null) {
      _mostrarMensagem('Informe um CNPJ válido para a ONG.');
      return;
    }

    setState(() => _carregando = true);
    try {
      UserCredential result;
      try {
        debugPrint(
          'AUTH_DIAGNOSTIC cadastro: iniciando criação no Firebase Auth',
        );
        result = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
        debugPrint('AUTH_DIAGNOSTIC cadastro: Firebase Auth criou a conta');
      } on FirebaseAuthException catch (e, stackTrace) {
        debugPrint(
          'AUTH_DIAGNOSTIC cadastro FirebaseAuthException: '
          'code=${e.code}, message=${e.message}',
        );
        debugPrintStack(stackTrace: stackTrace);
        final mensagem = _androidClientBlockedMessage(e) ?? switch (e.code) {
          'email-already-in-use' => 'Este e-mail já está cadastrado.',
          'invalid-email' => 'O e-mail informado é inválido.',
          'weak-password' => 'Escolha uma senha com pelo menos 6 caracteres.',
          'operation-not-allowed' =>
            'O cadastro por e-mail está desativado no Firebase.',
          'network-request-failed' => 'Verifique sua conexão com a internet.',
          _ => 'Não foi possível criar a conta. Tente novamente.',
        };
        _mostrarMensagem(mensagem);
        return;
      } catch (e, stackTrace) {
        debugPrint('AUTH_DIAGNOSTIC cadastro erro inesperado no Auth: $e');
        debugPrintStack(stackTrace: stackTrace);
        _mostrarMensagem('Não foi possível criar a conta. Tente novamente.');
        return;
      }

      SharedPreferences? prefs;
      try {
        prefs = await SharedPreferences.getInstance();
        await prefs.setBool(userSetupPendingKey(result.user!.uid), true);
      } catch (e, stackTrace) {
        debugPrint('AUTH_DIAGNOSTIC cadastro erro no SharedPreferences: $e');
        debugPrintStack(stackTrace: stackTrace);
      }

      String? avisoPerfil;
      try {
        debugPrint(
          'AUTH_DIAGNOSTIC cadastro: iniciando gravação do perfil no Firestore',
        );
        await saveUserProfile(
          result.user!,
          phoneNumber: telefone,
          initialSetupPending: false,
          role: perfil,
          cnpj: cnpj,
        );
        debugPrint('AUTH_DIAGNOSTIC cadastro: perfil gravado no Firestore');
      } on FirebaseException catch (e, stackTrace) {
        debugPrint(
          'AUTH_DIAGNOSTIC cadastro perfil FirebaseException: '
          'code=${e.code}, message=${e.message}',
        );
        debugPrintStack(stackTrace: stackTrace);
        avisoPerfil = switch (e.code) {
          'permission-denied' =>
            'A conta foi criada no Firebase Authentication, mas o perfil não '
                'foi salvo no Firestore (permission-denied). Verifique e publique '
                'as regras do Firestore.',
          'unavailable' || 'network-request-failed' =>
            'A conta foi criada no Firebase Authentication, mas o perfil não '
                'foi salvo no Firestore por falha de conexão. Entre novamente '
                'quando a conexão voltar.',
          _ =>
            'A conta foi criada no Firebase Authentication, mas o perfil não '
                'foi salvo no Firestore (${e.code}).',
        };
      } catch (e, stackTrace) {
        debugPrint('AUTH_DIAGNOSTIC cadastro erro ao salvar perfil: $e');
        debugPrintStack(stackTrace: stackTrace);
        avisoPerfil =
            'A conta foi criada no Firebase Authentication, mas não foi '
            'possível salvar o perfil no Firestore.';
      }

      if (prefs != null) {
        try {
          await prefs.setString('perfil_usuario', perfil);
          await prefs.remove(userSetupPendingKey(result.user!.uid));
        } catch (e, stackTrace) {
          debugPrint('AUTH_DIAGNOSTIC cadastro erro ao atualizar preferências: $e');
          debugPrintStack(stackTrace: stackTrace);
        }
      }

      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      if (avisoPerfil != null) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(avisoPerfil),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 8),
          ),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('AUTH_DIAGNOSTIC cadastro erro inesperado: $e');
      debugPrintStack(stackTrace: stackTrace);
      _mostrarMensagem('Não foi possível concluir o cadastro. Tente novamente.');
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Widget _buildRoleOption({
    required String role,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final selecionado = _perfilSelecionado == role;
    return Card(
      color: selecionado
          ? Colors.purple.withValues(alpha: 0.08)
          : const Color(0xFFFFF8FC),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: selecionado ? Colors.purple : const Color(0xFFE9D8E8),
          width: selecionado ? 1.5 : 1,
        ),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: selecionado ? Colors.purple : Colors.black54,
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: Icon(
          selecionado
              ? Icons.radio_button_checked
              : Icons.radio_button_unchecked,
          color: selecionado ? Colors.purple : Colors.black38,
        ),
        onTap: _carregando
            ? null
            : () => setState(() => _perfilSelecionado = role),
      ),
    );
  }

  void _mostrarMensagem(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensagem), backgroundColor: Colors.red),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _cnpjController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cadastre-se'),
        foregroundColor: Colors.purple,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Crie sua conta para ajudar a proteger os animais.',
                  style: TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Qual será o perfil desta conta?',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _buildRoleOption(
                  role: 'Denunciante',
                  title: 'Quero denunciar',
                  subtitle: 'Registrar e acompanhar ocorrências com animais.',
                  icon: Icons.campaign_outlined,
                ),
                const SizedBox(height: 8),
                _buildRoleOption(
                  role: 'Ong/Clinica',
                  title: 'Represento uma ONG/Clínica',
                  subtitle: 'Receber e acompanhar denúncias para atendimento.',
                  icon: Icons.volunteer_activism_outlined,
                ),
                if (_perfilSelecionado == 'Ong/Clinica') ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _cnpjController,
                    keyboardType: TextInputType.text,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'[A-Za-z0-9./-]'),
                      ),
                    ],
                    maxLength: 18,
                    decoration: const InputDecoration(
                      labelText: 'CNPJ da ONG/Clínica *',
                      hintText: '00.000.000/0000-00',
                      helperText: 'O CNPJ ficará pendente até análise manual. Validar o número não confirma vínculo.',
                      prefixIcon: Icon(
                        Icons.business_outlined,
                        color: Colors.purple,
                      ),
                    ),
                    validator: (value) {
                      if (_perfilSelecionado == 'Ong/Clinica' &&
                          normalizeCnpj(value ?? '') == null) {
                        return 'Informe um CNPJ válido.';
                      }
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'E-mail',
                    prefixIcon: Icon(Icons.email, color: Colors.purple),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final email = value?.trim() ?? '';
                    if (email.isEmpty) return 'Informe seu e-mail.';
                    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                        .hasMatch(email)) {
                      return 'Informe um e-mail válido.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Telefone/celular',
                    hintText: '+55 11 99999-9999',
                    prefixIcon: Icon(Icons.phone, color: Colors.purple),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Informe seu telefone/celular.';
                    }
                    if (normalizePhoneNumber(value) == null) {
                      return 'Use um telefone válido com código do país.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Senha',
                    prefixIcon: Icon(Icons.lock, color: Colors.purple),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.length < 6) {
                      return 'A senha deve ter pelo menos 6 caracteres.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _carregando ? null : _cadastrar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _carregando
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text('CRIAR CONTA'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Tela de escolha do perfil.
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key, required this.onRoleSelected});

  final ValueChanged<String> onRoleSelected;

  Future<String?> _solicitarCnpj(BuildContext context) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final cnpj = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('CNPJ da ONG/Clínica'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            keyboardType: TextInputType.text,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9./-]')),
            ],
            maxLength: 18,
            decoration: const InputDecoration(
              hintText: '00.000.000/0000-00',
              helperText: 'O CNPJ ficará pendente até análise manual. Validar o número não confirma vínculo.',
            ),
            validator: (value) => normalizeCnpj(value ?? '') == null
                ? 'Informe um CNPJ válido.'
                : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dialogContext, normalizeCnpj(controller.text));
              }
            },
            child: const Text('Enviar para análise'),
          ),
        ],
      ),
    );
    controller.dispose();
    return cnpj;
  }

  // Essa camada de código salva o perfil escolhido e redireciona para a Home correta
  Future<void> _selectRole(
    BuildContext context,
    String role, {
    String? cnpj,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw StateError('Usuário não autenticado ao salvar perfil.');
      }
      if (role == 'Ong/Clinica') {
        await saveUserRole(user, role, cnpj: cnpj);
        await _saveRolePreferences(user.uid, role);
        if (context.mounted) onRoleSelected(role);
        return;
      }

      await _saveRolePreferences(user.uid, role);

      if (!context.mounted) return;
      onRoleSelected(role);
      try {
        await saveUserRole(user, role);
      } catch (error) {
        debugPrint('Erro ao sincronizar perfil inicial no Firestore: $error');
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Sua escolha não foi sincronizada com a nuvem. Verifique as regras do Firestore.',
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 6),
          ),
        );
      }
    } catch (error) {
      debugPrint('Erro ao salvar perfil inicial: $error');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is FirebaseException && error.code == 'permission-denied'
                ? 'Não foi possível enviar o CNPJ. Publique as regras atualizadas do Firestore e tente novamente.'
                : 'Não foi possível salvar sua configuração. Verifique a conexão e tente novamente.',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _saveRolePreferences(String uid, String role) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('perfil_usuario', role);
      await prefs.remove(userSetupPendingKey(uid));
    } catch (error, stackTrace) {
      debugPrint('AUTH_DIAGNOSTIC falha ao salvar perfil local: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 255, 202, 248),
      appBar: AppBar(
        title: const Text('Configuração Inicial'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.purple,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Você deseja apenas denunciar ou representa uma ONG/Clínica de resgate?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),

            const SizedBox(height: 48),

            ElevatedButton(
              onPressed: () => _selectRole(context, 'Denunciante'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Apenas Denunciar',
                style: TextStyle(fontSize: 18),
              ),
            ),

            const SizedBox(height: 16),

            OutlinedButton(
              onPressed: () async {
                final cnpj = await _solicitarCnpj(context);
                if (!context.mounted || cnpj == null) return;
                await _selectRole(context, 'Ong/Clinica', cnpj: cnpj);
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.purple,
                side: const BorderSide(color: Colors.purple, width: 2),
                padding: const EdgeInsets.symmetric(vertical: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Represento uma ONG/Clínica',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
