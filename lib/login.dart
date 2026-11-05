import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sos_pet/user_profile.dart';

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
    } on FirebaseAuthException catch (e) {
      String mensagem;

      switch (e.code) {
        case 'invalid-email':
          mensagem = 'O e-mail informado é inválido.';
          break;
        case 'user-not-found':
        case 'invalid-credential':
          mensagem = 'E-mail ou senha incorretos.';
          break;
        case 'wrong-password':
          mensagem = 'A senha informada está incorreta.';
          break;
        case 'user-disabled':
          mensagem = 'Esta conta foi desativada.';
          break;
        case 'too-many-requests':
          mensagem = 'Muitas tentativas. Tente novamente mais tarde.';
          break;
        case 'network-request-failed':
          mensagem = 'Verifique sua conexão com a internet.';
          break;
        case 'operation-not-allowed':
          mensagem = 'O login por e-mail está desativado no Firebase. Ative esse provedor para continuar.';
          break;
        default:
          mensagem = 'Não foi possível entrar. Tente novamente.';
      }

      _mostrarMensagem(mensagem);
    } catch (e) {
      _mostrarMensagem('Ocorreu um erro inesperado.');
      debugPrint('Erro no login: $e');
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
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

      // Se o usuário fechar a janela, cancela o processo.
      if (googleUser == null) {
        return;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final result = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );
      final user = result.user!;
      if (result.additionalUserInfo?.isNewUser ?? false) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(userSetupPendingKey(user.uid), true);
      }
      await saveUserProfile(
        user,
        initialSetupPending: result.additionalUserInfo?.isNewUser == true
            ? true
            : null,
      );
    } on FirebaseAuthException catch (e) {
      debugPrint('Erro Firebase no Google: ${e.code}');
      _mostrarMensagem('Não foi possível entrar com o Google.');
    } catch (e) {
      debugPrint('Erro no login com Google: $e');
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
      backgroundColor: Colors.white,
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
                    'Entre para ajudar a proteger os animais.',
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
        const SnackBar(
          content: Text(
            'Informe um telefone válido, incluindo o código do país.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _carregando = true);
    final prefs = await SharedPreferences.getInstance();
    final perfilAnterior = prefs.getString('perfil_usuario');
    await prefs.setString('perfil_usuario', perfil);

    UserCredential result;
    try {
      result = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      await prefs.setBool(userSetupPendingKey(result.user!.uid), true);
    } on FirebaseAuthException catch (e) {
      await _restaurarPerfilLocal(prefs, perfilAnterior);
      final mensagem = switch (e.code) {
        'email-already-in-use' => 'Este e-mail já está cadastrado.',
        'invalid-email' => 'O e-mail informado é inválido.',
        'weak-password' => 'Escolha uma senha com pelo menos 6 caracteres.',
        'operation-not-allowed' =>
          'O cadastro por e-mail está desativado no Firebase.',
        'network-request-failed' => 'Verifique sua conexão com a internet.',
        _ => 'Não foi possível criar a conta. Tente novamente.',
      };
      _mostrarMensagem(mensagem);
      if (mounted) setState(() => _carregando = false);
      return;
    } catch (e) {
      await _restaurarPerfilLocal(prefs, perfilAnterior);
      debugPrint('Erro inesperado ao criar conta: $e');
      _mostrarMensagem('Não foi possível criar a conta. Tente novamente.');
      if (mounted) setState(() => _carregando = false);
      return;
    }

    String? avisoPerfil;
    try {
      await saveUserProfile(
        result.user!,
        phoneNumber: telefone,
        initialSetupPending: false,
        role: perfil,
      );
      await prefs.remove(userSetupPendingKey(result.user!.uid));
    } on FirebaseException catch (e) {
      debugPrint('Erro Firebase ao salvar perfil: ${e.code} - ${e.message}');
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
    } catch (e) {
      debugPrint('Erro inesperado ao salvar perfil do novo usuário: $e');
      avisoPerfil =
          'A conta foi criada no Firebase Authentication, mas não foi '
          'possível salvar o perfil no Firestore.';
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
  }

  Future<void> _restaurarPerfilLocal(
    SharedPreferences prefs,
    String? perfilAnterior,
  ) async {
    if (perfilAnterior == null) {
      await prefs.remove('perfil_usuario');
    } else {
      await prefs.setString('perfil_usuario', perfilAnterior);
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
      color: selecionado ? Colors.purple.withValues(alpha: 0.08) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selecionado ? Colors.purple : Colors.black12,
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

  // Essa camada de código salva o perfil escolhido e redireciona para a Home correta
  Future<void> _selectRole(BuildContext context, String role) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw StateError('Usuário não autenticado ao salvar perfil.');
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('perfil_usuario', role);
      await prefs.remove(userSetupPendingKey(user.uid));

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
              'Sua escolha foi salva neste aparelho, mas não foi sincronizada com a nuvem. Verifique as regras do Firestore.',
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
        const SnackBar(
          content: Text(
            'Não foi possível salvar sua configuração. Verifique a conexão e tente novamente.',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
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
              onPressed: () => _selectRole(context, 'Ong/Clinica'),
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
