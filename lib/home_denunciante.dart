import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sos_pet/denuncia.dart';
import 'package:sos_pet/mapa.dart';
import 'package:sos_pet/user_profile.dart';
import 'package:sos_pet/conscientizacao_carousel.dart';

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
                  title: const Text(
                    'Tirar foto com a Câmera',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    'Fotografar o animal ou veículo no momento',
                  ),
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
                  title: const Text(
                    'Escolher da Galeria',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
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
                  subtitle: const Text(
                    'A foto é opcional, você pode continuar sem imagem',
                  ),
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
                content: const Text(
                  'Permissão de câmera negada. Ative-a nas configurações do app.',
                ),
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
      debugPrint(
        'Erro ao acessar ${source == ImageSource.camera ? "câmera" : "galeria"}: $e',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Erro ao abrir ${source == ImageSource.camera ? "câmera" : "galeria"}: $e',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Essa camada de código é da função que abre a tela do Google Maps com solicitação de GPS
  void _abrirTelaMapa() {
    setState(() => _currentIndex = 1);
  }

  void _abrirPerfil() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const UserProfileScreen()));
  }

  @override
  Widget build(BuildContext context) {
    // Scaffold fornece a estrutura básica de layout visual (fundo, barras, botão flutuante)
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 255, 202, 248), 

      // Barra superior com a identidade visual do SOS Pet
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 255, 202, 248),
        foregroundColor: Colors.purple,
        elevation: 1,
        title: Row(
          children: [
            const Icon(Icons.pets, color: Colors.purple),
            const SizedBox(width: 8),
            Text(
              _currentIndex == 1 ? 'Mapa de Casos' : 'SOS Pet',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu),
            tooltip: 'Perfil e opções',
            onPressed: _abrirPerfil,
          ),
        ],
      ),

      // Corpo da tela contendo as ações e o histórico exclusivo do denunciante
      body: _currentIndex == 1
          ? const MapaScreen(embedded: true)
          : SingleChildScrollView(
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: const Icon(
                            Icons.add_a_photo,
                            color: Colors.purple,
                          ),
                          label: const Text(
                            'Fazer Nova Denúncia',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Carrossel com fotos e frases de conscientização que passam a cada 3 segundos
                  const ConscientizacaoCarousel(),

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

                  // StreamBuilder ouvindo as denúncias enviadas pelo usuário em tempo real
                  _buildMinhasDenuncias(),

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

                  const SizedBox(
                    height: 60,
                  ), // Espaço para não cobrir com a barra inferior
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
        child: const Icon(Icons.campaign, size: 38),
      ),
      // Posiciona o botão de denúncia centralizado na barra inferior
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      // Barra inferior com recorte suave para acomodar o botão flutuante central
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        color: const Color.fromARGB(255, 255, 202, 248),
        elevation: 8,
        padding: const EdgeInsets.symmetric(horizontal: 40.0),
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: Icon(
                  Icons.home,
                  size: 38,
                  color: _currentIndex == 0 ? Colors.purple : Colors.grey,
                ),
                onPressed: () => setState(() => _currentIndex = 0),
                tooltip: 'Início',
              ),
              // Espaço central reservado para o botão de denúncia flutuante
              const SizedBox(width: 56),
              IconButton(
                icon: Icon(
                  Icons.map,
                  size: 38,
                  color: _currentIndex == 1 ? Colors.purple : Colors.grey,
                ),
                onPressed: _abrirTelaMapa,
                tooltip: 'Abrir Mapa',
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

  String _formatarDataDenuncia(Timestamp? timestamp) {
    if (timestamp == null) return 'Agora';
    final data = timestamp.toDate();
    final diferenca = DateTime.now().difference(data);

    if (diferenca.inMinutes < 1) return 'Agora mesmo';
    if (diferenca.inMinutes < 60) return 'Há ${diferenca.inMinutes} min';
    if (diferenca.inHours < 24) return 'Há ${diferenca.inHours} h';
    return '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')} às ${data.hour.toString().padLeft(2, '0')}:${data.minute.toString().padLeft(2, '0')}';
  }

  Color _obterCorStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pendente':
        return Colors.orange;
      case 'em atendimento':
      case 'em resgate':
        return Colors.blue;
      case 'animal resgatado':
      case 'resgatado':
      case 'atendimento finalizado':
        return Colors.green;
      default:
        return Colors.purple;
    }
  }

  Widget _buildMinhasDenuncias() {
    final usuario = FirebaseAuth.instance.currentUser;
    if (usuario == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('denuncias')
          .where('usuarioId', isEqualTo: usuario.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24.0),
            child: Center(
              child: CircularProgressIndicator(color: Colors.purple),
            ),
          );
        }

        if (snapshot.hasError) {
          return Card(
            color: Colors.red.shade50,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Text(
                'Erro ao carregar denúncias: ${snapshot.error}',
                style: const TextStyle(color: Colors.red, fontSize: 13),
              ),
            ),
          );
        }

        final docs = (snapshot.data?.docs ?? []).toList();
        // Ordena no cliente pelas mais recentes, sem exigir índice composto no Firestore
        docs.sort((a, b) {
          final tA = a.data()['criadoEm'] as Timestamp?;
          final tB = b.data()['criadoEm'] as Timestamp?;
          if (tA == null && tB == null) return 0;
          if (tA == null) return 1;
          if (tB == null) return -1;
          return tB.compareTo(tA);
        });

        if (docs.isEmpty) {
          return Card(
            elevation: 1,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Padding(
              padding: EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.purple),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Você ainda não enviou nenhuma denúncia. Quando enviar, ela aparecerá aqui em tempo real!',
                      style: TextStyle(color: Colors.black54, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          children: docs.map((doc) {
            final data = doc.data();
            final status = (data['status'] as String?) ?? 'Pendente';
            final corStatus = _obterCorStatus(status);
            final especie = (data['especie'] as String?) ?? 'Animal';
            final condicao = (data['condicaoAnimal'] as String?) ?? '';
            final endereco = (data['endereco'] as String?) ?? 'Endereço não informado';
            final ultimaAtualizacao = (data['ultimaAtualizacao'] as String?) ?? 'Aguardando atendimento.';
            final criadoEm = data['criadoEm'] as Timestamp?;
            final fotoUrl = data['fotoUrl'] as String?;

            return Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 12.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: corStatus.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: corStatus),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(
                              color: corStatus,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Text(
                          _formatarDataDenuncia(criadoEm),
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (fotoUrl != null && fotoUrl.isNotEmpty) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          fotoUrl,
                          height: 140,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    Text(
                      '$especie ${condicao.isNotEmpty ? "• $condicao" : ""}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          size: 16,
                          color: Colors.purple,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            endereco,
                            style: const TextStyle(
                              color: Colors.black54,
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      children: [
                        Icon(
                          status == 'Pendente' ? Icons.hourglass_empty : Icons.check_circle_outline,
                          size: 18,
                          color: corStatus,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            ultimaAtualizacao,
                            style: const TextStyle(
                              color: Colors.black87,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
