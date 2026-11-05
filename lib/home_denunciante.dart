import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sos_pet/denuncia.dart';
import 'package:sos_pet/mapa.dart';

// Tela principal exclusiva para o usuário Denunciante (focada em registrar e acompanhar seus próprios chamados)
class HomeDenuncianteScreen extends StatefulWidget {
  const HomeDenuncianteScreen({super.key});

  @override
  State<HomeDenuncianteScreen> createState() => _HomeDenuncianteScreenState();
}

class _HomeDenuncianteScreenState extends State<HomeDenuncianteScreen> {
  // Guarda o índice da aba ativa na barra de navegação inferior
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // Essa camada de código solicita a permissão de localização assim que o usuário entra no app
    _solicitarPermissaoLocalizacaoAoIniciar();
  }

  // Essa camada de código pede permissão de GPS no início para agilizar o envio da localização das denúncias
  Future<void> _solicitarPermissaoLocalizacaoAoIniciar() async {
    try {
      bool servicoAtivo = await Geolocator.isLocationServiceEnabled();
      if (!servicoAtivo) {
        return;
      }
      LocationPermission permissao = await Geolocator.checkPermission();
      if (permissao == LocationPermission.denied) {
        // Exibe o diálogo nativo do sistema solicitando autorização do usuário
        await Geolocator.requestPermission();
      }
    } catch (e) {
      debugPrint('Erro ao solicitar permissão de localização inicial: $e');
    }
  }

  final ImagePicker _picker = ImagePicker();

  // Essa camada de código é da função que abre a tela de registro de nova denúncia
  void _abrirTelaDenuncia({XFile? fotoInicial}) {
    // Redireciona para o formulário de denúncia empilhando a tela na navegação
    Navigator.push(
      context,
      // Constrói a rota apontando para a DenunciaScreen (com foto inicial se houver)
      MaterialPageRoute(
        builder: (context) => DenunciaScreen(fotoInicial: fotoInicial),
      ),
    );
  }

  // Essa camada de código abre um menu de opções rápidas para Câmera ou Galeria na Home
  void _menuOpcoesFoto() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Registrar Denúncia com Imagem',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Como deseja adicionar a foto da ocorrência?',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                // Essa camada de código é do botão para abrir a Câmera diretamente da Home
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                    child: Icon(Icons.camera_alt),
                  ),
                  title: const Text('Tirar foto com a Câmera', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Fotografar o animal ou veículo no momento'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _capturarFotoEIrParaDenuncia(ImageSource.camera);
                  },
                ),
                const Divider(),

                // Essa camada de código é do botão para abrir a Galeria de fotos na Home
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    child: Icon(Icons.photo_library),
                  ),
                  title: const Text('Escolher da Galeria', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Selecionar foto salva no seu celular'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _capturarFotoEIrParaDenuncia(ImageSource.gallery);
                  },
                ),
                const Divider(),

                // Essa camada de código é do botão para preencher sem foto
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.grey[200],
                    foregroundColor: Colors.black87,
                    child: const Icon(Icons.edit_note),
                  ),
                  title: const Text('Preencher formulário sem foto'),
                  subtitle: const Text('A foto é opcional, você pode continuar sem imagem'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _abrirTelaDenuncia();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Essa camada de código solicita permissão e acessa a câmera ou galeria do aparelho
  Future<void> _capturarFotoEIrParaDenuncia(ImageSource source) async {
    try {
      if (source == ImageSource.camera) {
        // Solicita explicitamente a permissão de câmera ao sistema operacional
        final PermissionStatus status = await Permission.camera.request();
        if (status.isPermanentlyDenied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Permissão de câmera negada. Ative-a nas configurações do app.'),
                backgroundColor: Colors.red,
                action: SnackBarAction(
                  label: 'Configurações',
                  textColor: Colors.white,
                  onPressed: () => openAppSettings(),
                ),
              ),
            );
          }
          return;
        } else if (!status.isGranted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Permissão de câmera não concedida.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      }

      final XFile? foto = await _picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (foto != null && mounted) {
        _abrirTelaDenuncia(fotoInicial: foto);
      }
    } catch (e) {
      debugPrint('Erro ao acessar ${source == ImageSource.camera ? "câmera" : "galeria"}: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao abrir ${source == ImageSource.camera ? "câmera" : "galeria"}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Essa camada de código é da função de logout: apaga a sessão do Firebase e o perfil salvo localmente

  Future<void> _logout() async {
  try {
    debugPrint('Iniciando logout...');

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('perfil_usuario');

    await FirebaseAuth.instance.signOut();

    debugPrint('Logout realizado com sucesso!');
  } catch (e, stackTrace) {
    debugPrint('Erro ao fazer logout: $e');
    debugPrint('$stackTrace');

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao sair da conta: $e'),
        ),
      );
    }
  }
}
  // Essa camada de código é da função que abre a tela do Google Maps com solicitação de GPS
  void _abrirTelaMapa() {
    // Redireciona diretamente para a tela do mapa ativo com suporte a GPS e marcadores
    Navigator.push(
      context,
      // Constrói a rota apontando para a MapaScreen
      MaterialPageRoute(builder: (context) => const MapaScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Scaffold fornece a estrutura básica de layout visual (fundo, barras, botão flutuante)
    return Scaffold(
      backgroundColor: Colors.grey[100],

      // Barra superior com a identidade visual do SOS Pet
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.purple,
        elevation: 1,
        title: const Row(
          children: [
            Icon(Icons.pets, color: Colors.purple),
            SizedBox(width: 8),
            Text(
              'SOS Pet',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          // Essa camada de código é do botão de notificações do denunciante
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.purple),
            tooltip: 'Notificações',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Você não possui novas notificações no momento.')),
              );
            },
          ),
          // Essa camada de código é do botão de Sair (Logout) — apaga sessão e perfil salvo
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.purple),
            tooltip: 'Sair',
            onPressed: _logout,
          ),
        ],
      ),

      // Corpo da tela contendo as ações e o histórico exclusivo do denunciante
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Banner de boas-vindas acolhedor para o Denunciante
            Container(
              padding: const EdgeInsets.all(20.0),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.purple, Colors.deepPurple],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.purple.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Presenciou um animal em perigo?',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Envie fotos e a localização para acionar as ONGs e clínicas parceiras de resgate.',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 16),

                  // Essa camada de código é do botão de ação rápida no banner com opções para Câmera, Galeria ou Formulário
                  ElevatedButton.icon(
                    onPressed: _menuOpcoesFoto,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.purple,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.add_a_photo, color: Colors.purple),
                    label: const Text(
                      'Fazer Nova Denúncia',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Título da seção de acompanhamento pessoal (RF03 e diagrama de casos de uso)
            const Text(
              'Minhas Denúncias Enviadas',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Acompanhe o andamento dos resgates que você solicitou:',
              style: TextStyle(fontSize: 13, color: Colors.black54),
            ),
            const SizedBox(height: 12),

            // Card exibindo uma denúncia pessoal realizada por este usuário
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue),
                          ),
                          child: const Text(
                            'Em Atendimento',
                            style: TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const Text(
                          'Hoje às 14:30',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Cão com pata machucada próximo à praça',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Row(
                      children: [
                        Icon(Icons.location_on, size: 16, color: Colors.purple),
                        SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Rua das Palmeiras, 450 - Centro',
                            style: TextStyle(color: Colors.black54, fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    const Row(
                      children: [
                        Icon(Icons.check_circle_outline, size: 18, color: Colors.green),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Equipe "Patas Amigas" a caminho do local.',
                            style: TextStyle(color: Colors.black87, fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Seção informativa de como funciona o processo de resgate
            const Text(
              'Como funciona o SOS Pet?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),

            _buildPassoResgate(
              numero: '1',
              titulo: 'Você denuncia',
              descricao: 'Registra fotos e o local exato onde o animal foi visto.',
              icone: Icons.camera_alt,
            ),
            _buildPassoResgate(
              numero: '2',
              titulo: 'ONGs são alertadas',
              descricao: 'Equipes parceiras e voluntários recebem o chamado em tempo real.',
              icone: Icons.notifications_active,
            ),
            _buildPassoResgate(
              numero: '3',
              titulo: 'Animal resgatado',
              descricao: 'O pet recebe cuidados veterinários e você acompanha o desfecho.',
              icone: Icons.favorite,
            ),

            const SizedBox(height: 60), // Espaço para não cobrir com a barra inferior
          ],
        ),
      ),

      // Essa camada de código é do botão central em vermelho de "Denúncia" (redondo e proporcional)
      floatingActionButton: FloatingActionButton(
        onPressed: _abrirTelaDenuncia,
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: const CircleBorder(),
        tooltip: 'Fazer Denúncia',
        child: const Icon(Icons.campaign, size: 28),
      ),
      // Posiciona o botão de denúncia centralizado na barra inferior
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      // Barra inferior com recorte suave para acomodar o botão flutuante central
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 6.0,
        color: Colors.white,
        elevation: 8,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Lado esquerdo da barra inferior
              Row(
                children: [
                  // Essa camada de código é do botão Início (Home)
                  IconButton(
                    icon: Icon(
                      Icons.home,
                      color: _currentIndex == 0 ? Colors.purple : Colors.grey,
                    ),
                    onPressed: () {
                      setState(() {
                        _currentIndex = 0;
                      });
                    },
                    tooltip: 'Início',
                  ),

                  // Essa camada de código é do botão Maps (abre a tela do Google Maps com GPS e pontos de apoio)
                  IconButton(
                    icon: const Icon(
                      Icons.map,
                      color: Colors.purple,
                    ),
                    onPressed: _abrirTelaMapa,
                    tooltip: 'Abrir Mapa',
                  ),
                ],
              ),

              // Lado direito da barra inferior
              Row(
                children: [
                  // Essa camada de código é do botão de Acompanhamento das Minhas Denúncias
                  IconButton(
                    icon: Icon(
                      Icons.assignment,
                      color: _currentIndex == 2 ? Colors.purple : Colors.grey,
                    ),
                    onPressed: () {
                      setState(() {
                        _currentIndex = 2;
                      });
                    },
                    tooltip: 'Minhas Denúncias',
                  ),

                  // Essa camada de código é do botão Perfil do usuário
                  IconButton(
                    icon: Icon(
                      Icons.person,
                      color: _currentIndex == 3 ? Colors.purple : Colors.grey,
                    ),
                    onPressed: () {
                      setState(() {
                        _currentIndex = 3;
                      });
                    },
                    tooltip: 'Perfil',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Constrói cards explicativos com as etapas do processo de resgate
  Widget _buildPassoResgate({
    required String numero,
    required String titulo,
    required String descricao,
    required IconData icone,
  }) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.purple.withValues(alpha: 0.1),
          foregroundColor: Colors.purple,
          child: Icon(icone),
        ),
        title: Text(
          '$numero. $titulo',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Text(
          descricao,
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ),
    );
  }
}

