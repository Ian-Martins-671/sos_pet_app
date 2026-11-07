import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sos_pet/denuncia.dart';
import 'package:sos_pet/mapa.dart';
import 'package:sos_pet/user_profile.dart';
import 'package:sos_pet/conscientizacao_carousel.dart';

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
        return const Row(
          children: [
            Icon(Icons.pets, color: Colors.purple),
            SizedBox(width: 8),
            Text('SOS Pet - ONG', style: TextStyle(fontWeight: FontWeight.bold)),
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
      query = query.where('status', whereIn: ['Animal resgatado', 'Resgatado', 'Atendimento finalizado']);
    }

    return Column(
      children: [
        // Seção de filtros de status rápidos
        Container(
          color: Colors.white,
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
            stream: query.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    const ConscientizacaoCarousel(),
                    const SizedBox(height: 16),
                    Card(
                      color: Colors.red.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: Colors.red),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Não foi possível carregar as denúncias: ${snapshot.error}',
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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

              final docs = snapshot.data?.docs ?? [];

              return ListView.builder(
                padding: const EdgeInsets.only(
                  left: 16.0,
                  right: 16.0,
                  top: 12.0,
                  bottom: 80.0,
                ),
                itemCount: docs.length + 1, // +1 para o carrossel no topo
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return const Padding(
                      padding: EdgeInsets.only(bottom: 16.0),
                      child: ConscientizacaoCarousel(),
                    );
                  }

                  final doc = docs[index - 1];
                  final data = doc.data();
                  return _buildCardDenuncia(doc.id, data);
                },
              );
            },
          ),
        ),
      ],
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
    final endereco = (data['endereco'] as String?) ?? 'Localização não informada';
    final fotoUrl = data['fotoUrl'] as String?;
    final criadoEm = data['criadoEm'] as Timestamp?;
    final tempoTexto = _formatarData(criadoEm);
    final descricao = (data['descricao'] as String?) ?? '';

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 14.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Topo do card com Status, Tipo e Horário
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
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
                    if (isFlagrante) ...[
                      const SizedBox(width: 8),
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
                          children: [
                            Icon(Icons.warning_amber_rounded, size: 14, color: Colors.red),
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
                    ],
                  ],
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
                  errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
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
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],

      appBar: AppBar(
        backgroundColor: Colors.white,
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

      floatingActionButton: FloatingActionButton(
        onPressed: _abrirTelaDenuncia,
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: const CircleBorder(),
        tooltip: 'Fazer Denúncia',
        child: const Icon(Icons.campaign, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

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
              IconButton(
                icon: Icon(
                  Icons.home,
                  color: _currentIndex == 0 ? Colors.purple : Colors.grey,
                ),
                onPressed: () => setState(() => _currentIndex = 0),
                tooltip: 'Início',
              ),
              const SizedBox(width: 48),
              IconButton(
                icon: Icon(
                  Icons.map,
                  color: _currentIndex == 1 ? Colors.purple : Colors.grey,
                ),
                onPressed: _abrirTelaMapa,
                tooltip: 'Mapa de Casos',
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
