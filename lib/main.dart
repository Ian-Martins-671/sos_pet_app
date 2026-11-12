import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sos_pet/firebase_options.dart';
import 'package:sos_pet/login.dart';
import 'package:sos_pet/home_denunciante.dart';
import 'package:sos_pet/home.dart';
import 'package:sos_pet/user_profile.dart';
import 'package:sos_pet/conscientizacao_carousel.dart';

// Ponto de entrada que inicializa a aplicação Flutter
void main() async {
  // Garante a inicialização correta dos bindings do Flutter antes de chamadas assíncronas
  WidgetsFlutterBinding.ensureInitialized();

  // Essa camada de código inicializa a conexão com os serviços do Google Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const MyApp());
}

// Widget raiz que configura o aplicativo
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // MaterialApp define temas globais, rotas e comportamento geral do app
    return MaterialApp(
      title: 'SOS Pet',
      debugShowCheckedModeBanner: false, // Desativa a faixa de debug visual
      theme: ThemeData(
        // Define a paleta roxa do aplicativo e adota os padrões visuais do Material 3
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.purple),
        scaffoldBackgroundColor: const Color.fromARGB(255, 255, 202, 248),
        cardTheme: const CardThemeData(
          color: Color(0xFFFFF8FC),
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
            side: BorderSide(color: Color(0xFFE9D8E8)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFFFFCFE),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE9D8E8)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE9D8E8)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.purple, width: 1.5),
          ),
        ),
        useMaterial3: true,
      ),
      // Essa camada de código é do AuthGate: controla para onde o app vai ao abrir.
      // Se o usuário já estiver logado, vai direto para a Home sem mostrar o login.
      home: const AuthGate(),
    );
  }
}

// AuthGate encaminha usuários autenticados à Home e os demais à tela de login.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    // Pré-carrega os assets de conscientização na memória assim que o app abre
    ConscientizacaoCarousel.precacheImagens(context);
    // StreamBuilder ouve o fluxo de autenticação do Firebase automaticamente
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.userChanges(),
      builder: (context, snapshot) {
        debugPrint(
          'AuthGate: usuário = ${snapshot.data?.uid ?? "desconectado"}',
        );
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: const Color.fromARGB(255, 255, 202, 248),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'SOS Pet',
                    style: TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple,
                    ),
                  ),
                  SizedBox(height: 32),
                  CircularProgressIndicator(color: Colors.purple),
                ],
              ),
            ),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          return const _HomeRouter();
        }

        // Usuário não está logado: exibe a tela de login
        return const LoginScreen();
      },
    );
  }
}

// Essa camada de código lê o perfil salvo (Denunciante ou ONG) e decide qual Home exibir.
// Enquanto lê o SharedPreferences, mostra uma tela de carregamento.

class _HomeRouter extends StatefulWidget {
  const _HomeRouter();

  @override
  State<_HomeRouter> createState() => _HomeRouterState();
}

class _HomeRouterState extends State<_HomeRouter> {
  // Guarda o perfil lido do armazenamento local ('Denunciante' ou 'Ong/Clinica')
  String? _perfil;
  String? _erro;
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    // Essa camada de código carrega o perfil salvo ao inicializar o roteador
    _carregarPerfil();
  }

  Future<void> _carregarPerfil() async {
    try {
      final user = FirebaseAuth.instance.currentUser!;
      SharedPreferences? prefs;
      String? localRole;
      bool? localSetupPending;
      try {
        prefs = await SharedPreferences.getInstance();
        localRole = prefs.getString('perfil_usuario');
        localSetupPending = prefs.getBool(userSetupPendingKey(user.uid));
      } catch (error, stackTrace) {
        debugPrint('AUTH_DIAGNOSTIC falha ao ler SharedPreferences: $error');
        debugPrintStack(stackTrace: stackTrace);
      }

      Map<String, dynamic>? data;
      try {
        final snapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        data = snapshot.data();
      } catch (error) {
        // Keep returning users in the app when remote profile rules/network
        // are unavailable; local preferences retain the role and setup state.
        debugPrint('Não foi possível carregar o perfil remoto: $error');
      }

      final savedRole = data?['perfil'] as String?;
      if (savedRole == 'Ong/Clinica') {
        final cnpj = normalizeCnpj(data?['cnpj'] as String? ?? '');
        final cnpjStatus = data?['cnpjStatus'] as String?;
        if (cnpj == null ||
            !['pendente', 'aprovado', 'rejeitado'].contains(cnpjStatus)) {
          _setLoadedProfile(null);
          return;
        }
        await _persistProfilePreferences(
          prefs,
          user.uid,
          role: savedRole,
          cnpj: cnpj,
          clearSetupPending: true,
        );
        _setLoadedProfile(savedRole);
        return;
      }

      if (savedRole == 'Denunciante') {
        await _persistProfilePreferences(
          prefs,
          user.uid,
          role: savedRole,
          clearSetupPending: true,
        );
        _setLoadedProfile(savedRole);
        return;
      }

      if (localRole == 'Ong/Clinica') {
        _setLoadedProfile(null);
        return;
      }

      if (localRole == 'Denunciante') {
        await _persistProfilePreferences(
          prefs,
          user.uid,
          clearSetupPending: true,
        );
        try {
          await saveUserRole(user, localRole!);
        } catch (error) {
          debugPrint(
            'Não foi possível sincronizar o perfil salvo localmente: $error',
          );
        }
        _setLoadedProfile(localRole);
        return;
      }

      final setupPending =
          localSetupPending ?? data?['configuracaoInicialPendente'] == true;
      if (setupPending) {
        _setLoadedProfile(null);
        return;
      }

      // Existing accounts without a saved choice keep using the reporter home.
      await _persistProfilePreferences(
        prefs,
        user.uid,
        role: 'Denunciante',
      );
      try {
        await saveUserRole(user, 'Denunciante');
      } catch (error) {
        debugPrint('Não foi possível sincronizar o perfil padrão: $error');
      }
      _setLoadedProfile('Denunciante');
    } catch (error) {
      debugPrint('Erro ao carregar o perfil do usuário: $error');
      if (mounted) {
        setState(() {
          _erro = 'Não foi possível carregar seu perfil. Verifique sua conexão e tente novamente.';
          _carregando = false;
        });
      }
    }
  }

  Future<void> _persistProfilePreferences(
    SharedPreferences? prefs,
    String uid, {
    String? role,
    String? cnpj,
    bool clearSetupPending = false,
  }) async {
    if (prefs == null) return;
    try {
      if (role != null) {
        await prefs.setString('perfil_usuario', role);
      }
      if (cnpj != null) {
        await prefs.setString(userCnpjKey(uid), cnpj);
      }
      if (clearSetupPending) {
        await prefs.remove(userSetupPendingKey(uid));
      }
    } catch (error, stackTrace) {
      debugPrint('AUTH_DIAGNOSTIC falha ao salvar SharedPreferences: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  void _setLoadedProfile(String? perfil) {
    if (!mounted) return;
    setState(() {
      _perfil = perfil;
      _carregando = false;
      _erro = null;
    });
  }

  Future<void> _voltarParaLogin() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (error, stackTrace) {
      debugPrint('Erro ao encerrar sessão para voltar ao login: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível voltar ao login. Tente novamente.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Exibe carregamento enquanto lê o perfil do disco
    if (_carregando) {
      return const Scaffold(
        backgroundColor: Color.fromARGB(255, 255, 202, 248),
        body: Center(child: CircularProgressIndicator(color: Colors.purple)),
      );
    }

    if (_erro != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_erro!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _voltarParaLogin,
                  child: const Text('Voltar para o login'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Se o perfil não foi salvo ainda (primeiro login), vai para o Onboarding de escolha
    if (_perfil == null) {
      return OnboardingScreen(onRoleSelected: _onRoleSelected);
    }

    // Essa camada de código é do roteador de perfil: redireciona para a Home correta
    if (_perfil == 'Denunciante') {
      return const HomeDenuncianteScreen();
    } else {
      return const OngApprovalGate();
    }
  }

  void _onRoleSelected(String perfil) {
    setState(() {
      _perfil = perfil;
    });
  }
}
