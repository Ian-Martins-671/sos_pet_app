import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sos_pet/denuncia.dart';
import 'package:sos_pet/mapa.dart';
import 'package:sos_pet/user_profile.dart';
import 'package:sos_pet/conscientizacao_carousel.dart';

class OngApprovalGate extends StatefulWidget {
  const OngApprovalGate({super.key});

  @override
  State<OngApprovalGate> createState() => _OngApprovalGateState();
}

class _OngApprovalGateState extends State<OngApprovalGate> {
  int _reloadKey = 0;
  bool _saindo = false;

  Future<void> _voltarAoLogin() async {
    setState(() => _saindo = true);
    try {
      await FirebaseAuth.instance.signOut();
    } catch (error) {
      debugPrint('Erro ao sair da conta ONG: $error');
      if (!mounted) return;
      setState(() => _saindo = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível voltar ao login. Tente novamente.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Entre novamente para verificar sua conta.')),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      key: ValueKey(_reloadKey),
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: const Color.fromARGB(255, 255, 202, 248),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 36,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Não foi possível consultar a confirmação do CNPJ.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => setState(() => _reloadKey++),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color.fromARGB(255, 255, 202, 248),
            body: Center(
              child: CircularProgressIndicator(color: Colors.purple),
            ),
          );
        }

        final profile = snapshot.data?.data();
        final cnpjStatus = profile?['cnpjStatus'] as String?;
        final cnpj = normalizeCnpj(profile?['cnpj'] as String? ?? '');
        if (profile?['perfil'] == 'Ong/Clinica' &&
            cnpj != null &&
            cnpjStatus == 'aprovado') {
          return const HomeScreen();
        }

        final recusado = cnpjStatus == 'rejeitado';
        return Scaffold(
          backgroundColor: const Color.fromARGB(255, 255, 202, 248),
          appBar: AppBar(
            backgroundColor: const Color.fromARGB(255, 255, 202, 248),
            foregroundColor: Colors.purple,
            title: Row(
              children: [
                Image.asset(
                  'assets/images/icon/iconsospet.png',
                  width: 32,
                  height: 32,
                ),
                const SizedBox(width: 8),
                const Text('SOS Pet - ONG'),
              ],
            ),
          ),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        recusado
                            ? Icons.gpp_bad_outlined
                            : Icons.hourglass_top_rounded,
                        color: recusado ? Colors.red : Colors.deepOrange,
                        size: 44,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        recusado
                            ? 'CNPJ não confirmado'
                            : 'CNPJ aguardando confirmação',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        recusado
                            ? 'A equipe não conseguiu confirmar o cadastro. Entre em contato com o suporte para corrigir os dados.'
                            : 'O acesso às denúncias será liberado após a análise manual dos dados da ONG. Esta tela será atualizada quando a confirmação for concluída.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.black54),
                      ),
                      if (!recusado) ...[
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _saindo ? null : _voltarAoLogin,
                          child: _saindo
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('OK'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// Tela principal da aplicação para ONGs/Clínicas gerenciando abas, mapa e feed de denúncias em tempo real
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Guarda a aba selecionada: 0 = Início (Feed) ou 1 = Mapa
  int _currentIndex = 0;

  // Filtro de status atualmente selecionado no feed
  String _filtroSelecionado = 'Todos';
  int _feedReloadKey = 0;

  // Essa camada de código é da função que abre o formulário de nova denúncia
  void _abrirTelaDenuncia() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const DenunciaScreen()),
    );
  }

  // Essa camada de código é da função que abre a tela do Google Maps com GPS e marcadores
  void _abrirTelaMapa() {
    setState(() => _currentIndex = 1);
  }

  void _abrirPerfil() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const UserProfileScreen()));
  }

  // Retorna o título da barra superior de acordo com a aba selecionada
  Widget _buildAppBarTitle() {
    switch (_currentIndex) {
      case 1:
        return const Row(
          children: [
            Icon(Icons.map, color: Colors.purple),
            SizedBox(width: 8),
            Text(
              'Mapa de Casos',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        );
      default:
        return Row(
          children: [
            Image.asset(
              'assets/images/icon/iconsospet.png',
              width: 32,
              height: 32,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 8),
            const Text(
              'SOS Pet - ONG',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        );
    }
  }

  // Renderiza a visualização ativa conforme a aba selecionada
  Widget _buildBody() {
    switch (_currentIndex) {
      case 1:
        return const MapaScreen(embedded: true);
      default:
        return _buildFeed();
    }
  }

  // Constrói o feed de denúncias conectado em tempo real ao Firestore
  Widget _buildFeed() {
    // Monta a query base ordenada pelas denúncias mais recentes
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('denuncias')
        .orderBy('criadoEm', descending: true);

    // Aplica o filtro de status selecionado
    if (_filtroSelecionado == 'Pendentes') {
      query = query.where('status', isEqualTo: 'Pendente');
    } else if (_filtroSelecionado == 'Em Resgate') {
      query = query.where('status', whereIn: ['Em atendimento', 'Em Resgate']);
    } else if (_filtroSelecionado == 'Resgatados') {
      query = query.where(
        'status',
        whereIn: ['Animal resgatado', 'Resgatado', 'Atendimento finalizado'],
      );
    }

    return Column(
      children: [
        // Seção de filtros de status rápidos
        Container(
          color: const Color.fromARGB(255, 255, 202, 248),
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('Todos'),
                const SizedBox(width: 8),
                _buildFilterChip('Pendentes'),
                const SizedBox(width: 8),
                _buildFilterChip('Em Resgate'),
                const SizedBox(width: 8),
                _buildFilterChip('Resgatados'),
              ],
            ),
          ),
        ),

        // StreamBuilder ouve as ocorrências do Firestore em tempo real
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            key: ValueKey(_feedReloadKey),
            stream: query.snapshots(includeMetadataChanges: true),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                final permissionDenied =
                    snapshot.error is FirebaseException &&
                    (snapshot.error! as FirebaseException).code ==
                        'permission-denied';
                debugPrint('Erro ao carregar denúncias: ${snapshot.error}');
                return ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    const ConscientizacaoCarousel(),
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: Theme.of(context).colorScheme.error,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    permissionDenied
                                        ? 'Sua conta ainda não tem permissão para visualizar as denúncias. O CNPJ precisa ser confirmado e as regras do Firestore publicadas.'
                                        : 'Não foi possível carregar as denúncias. Verifique sua conexão e tente novamente.',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: () {
                                setState(() => _feedReloadKey++);
                              },
                              icon: const Icon(Icons.refresh),
                              label: const Text('Tentar novamente'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    _buildFluxoApp(),
                  ],
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: const [
                    ConscientizacaoCarousel(),
                    SizedBox(height: 32),
                    Center(
                      child: CircularProgressIndicator(color: Colors.purple),
                    ),
                  ],
                );
              }

              final querySnapshot = snapshot.data;
              if (querySnapshot == null || querySnapshot.metadata.isFromCache) {
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const ConscientizacaoCarousel(),
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            const Text(
                              'Aguardando sincronização com o Firebase. '
                              'Para evitar mostrar denúncias já removidas, '
                              'os dados locais não serão exibidos.',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: () {
                                setState(() => _feedReloadKey++);
                              },
                              icon: const Icon(Icons.refresh),
                              label: const Text('Tentar novamente'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    _buildFluxoApp(),
                  ],
                );
              }

              final docs = querySnapshot.docs;

              return ListView(
                padding: const EdgeInsets.only(
                  left: 16.0,
                  right: 16.0,
                  top: 12.0,
                  bottom: 80.0,
                ),
                children: [
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16.0),
                    child: ConscientizacaoCarousel(),
                  ),
                  if (docs.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(Icons.inbox_outlined, color: Colors.purple),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _filtroSelecionado == 'Pendentes'
                                    ? 'Não há denúncias pendentes no momento.'
                                    : 'Nenhuma denúncia encontrada para este filtro.',
                                style: const TextStyle(color: Colors.black54),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ...docs.map((doc) => _buildCardDenuncia(doc.id, doc.data())),
                  _buildFluxoApp(),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFluxoApp() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'Como funciona o SOS Pet?',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        _buildPassoResgate(
          numero: '1',
          titulo: 'Denúncia registrada',
          descricao: 'O denunciante envia os dados, a localização e, se possível, uma foto.',
          icone: Icons.campaign_outlined,
        ),
        _buildPassoResgate(
          numero: '2',
          titulo: 'ONG verifica a ocorrência',
          descricao: 'Após a confirmação do CNPJ, a equipe pode analisar as denúncias pendentes.',
          icone: Icons.fact_check_outlined,
        ),
        _buildPassoResgate(
          numero: '3',
          titulo: 'Atendimento iniciado',
          descricao:
              'A ONG assume a ocorrência e registra atualizações do resgate.',
          icone: Icons.medical_services_outlined,
        ),
        _buildPassoResgate(
          numero: '4',
          titulo: 'Desfecho acompanhado',
          descricao: 'O denunciante acompanha o status até a conclusão do atendimento.',
          icone: Icons.favorite_outline,
        ),
      ],
    );
  }

  Widget _buildPassoResgate({
    required String numero,
    required String titulo,
    required String descricao,
    required IconData icone,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
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

  // Formata o tempo amigável a partir do Timestamp do Firestore
  String _formatarData(Timestamp? timestamp) {
    if (timestamp == null) return 'Agora';
    final data = timestamp.toDate();
    final diferenca = DateTime.now().difference(data);

    if (diferenca.inMinutes < 1) return 'Agora mesmo';
    if (diferenca.inMinutes < 60) return 'Há ${diferenca.inMinutes} min';
    if (diferenca.inHours < 24) return 'Há ${diferenca.inHours} h';
    return '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')} às ${data.hour.toString().padLeft(2, '0')}:${data.minute.toString().padLeft(2, '0')}';
  }

  // Retorna a cor do status correspondente
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

  // Constrói o card real de cada denúncia vinda do Firestore
  Widget _buildCardDenuncia(String id, Map<String, dynamic> data) {
    final status = (data['status'] as String?) ?? 'Pendente';
    final corStatus = _obterCorStatus(status);
    final especie = (data['especie'] as String?) ?? 'Animal';
    final condicao = (data['condicaoAnimal'] as String?) ?? '';
    final tipo = (data['tipo'] as String?) ?? 'Ocorrência';
    final isFlagrante = tipo == 'Flagrante';
    final endereco =
        (data['endereco'] as String?) ?? 'Localização não informada';
    final fotoUrl = data['fotoUrl'] as String?;
    final criadoEm = data['criadoEm'] as Timestamp?;
    final tempoTexto = _formatarData(criadoEm);
    final descricao = (data['descricao'] as String?) ?? '';
    final ultimaAtualizacao =
        (data['ultimaAtualizacao'] as String?) ?? 'Aguardando atendimento.';

    return Card(
      margin: const EdgeInsets.only(bottom: 14.0),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Topo do card com Status, Tipo e Horário
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: corStatus.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: corStatus, width: 1.2),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: corStatus,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (isFlagrante)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          size: 14,
                          color: Colors.red,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'FLAGRANTE',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                Text(
                  tempoTexto,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Foto da ocorrência caso tenha sido enviada
            if (fotoUrl != null && fotoUrl.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  fotoUrl,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const SizedBox.shrink(),
                ),
              ),
              const SizedBox(height: 10),
            ],

            // Título: Espécie e Condição do animal
            Text(
              '$especie ${condicao.isNotEmpty ? "• $condicao" : ""}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            if (descricao.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                descricao,
                style: const TextStyle(color: Colors.black87, fontSize: 13),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 8),

            // Endereço
            Row(
              children: [
                const Icon(Icons.location_on, size: 16, color: Colors.purple),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    endereco,
                    style: const TextStyle(color: Colors.black54, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Icon(
                  status == 'Pendente'
                      ? Icons.hourglass_empty
                      : Icons.update_outlined,
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 255, 202, 248),

      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 255, 202, 248),
        foregroundColor: Colors.purple,
        elevation: 1,
        title: _buildAppBarTitle(),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu),
            tooltip: 'Perfil e opções',
            onPressed: _abrirPerfil,
          ),
        ],
      ),

      body: _buildBody(),

      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        color: Colors.white,
        elevation: 8,
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: SizedBox(
          height: 60,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.home,
                        size: 28,
                        color: _currentIndex == 0 ? Colors.purple : Colors.grey,
                      ),
                      onPressed: () => setState(() => _currentIndex = 0),
                      tooltip: 'Início',
                    ),
                    const SizedBox(width: 56),
                    IconButton(
                      icon: Icon(
                        Icons.map,
                        size: 28,
                        color: _currentIndex == 1 ? Colors.purple : Colors.grey,
                      ),
                      onPressed: _abrirTelaMapa,
                      tooltip: 'Mapa de Casos',
                    ),
                  ],
                ),
              ),
              Positioned(
                top: -28,
                left: 0,
                right: 0,
                child: Center(
                  child: FloatingActionButton(
                    onPressed: _abrirTelaDenuncia,
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    elevation: 4,
                    shape: const CircleBorder(),
                    tooltip: 'Fazer Denúncia',
                    child: const Icon(Icons.campaign, size: 28),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final bool isSelected = _filtroSelecionado == label;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: Colors.purple,
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.purple,
        fontWeight: FontWeight.bold,
      ),
      side: const BorderSide(color: Colors.purple),
      onSelected: (bool selected) {
        if (selected) {
          setState(() {
            _filtroSelecionado = label;
          });
        }
      },
    );
  }
}
