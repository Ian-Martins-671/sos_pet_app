import 'package:flutter/material.dart';
import 'package:sos_pet/denuncia.dart';
import 'package:sos_pet/mapa.dart';
import 'package:sos_pet/user_profile.dart';

// Tela principal da aplicação gerenciando abas, mapa e feed de denúncias
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Guarda a aba selecionada: início ou mapa.
  int _currentIndex = 0;

  // Filtro de status atualmente selecionado no feed
  String _filtroSelecionado = 'Todos';

  // Essa camada de código é da função que abre o formulário de nova denúncia
  void _abrirTelaDenuncia() {
    // Redireciona para o formulário de denúncia empilhando a tela na navegação
    Navigator.push(
      context,
      // Constrói a rota apontando para a DenunciaScreen
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
            Text('SOS Pet', style: TextStyle(fontWeight: FontWeight.bold)),
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

  // Constrói o feed de denúncias com filtros e listagem
  Widget _buildFeed() {
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

        // ListView exibe a listagem dinâmica de ocorrências de animais abandonados
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(
              left: 16.0,
              right: 16.0,
              top: 12.0,
              bottom: 80.0,
            ),
            children: [
              Card(
                color: Colors.amber.shade50,
                child: const ListTile(
                  leading: Icon(Icons.info_outline, color: Colors.deepOrange),
                  title: Text('Exemplos de demonstração'),
                  subtitle: Text(
                    'As denúncias e pendências abaixo são apenas exemplos '
                    'para demonstrar como o feed pode aparecer.',
                  ),
                ),
              ),
              _buildCardExemplo(
                titulo: 'Cachorro machucado na calçada',
                local: 'Rua das Flores, 120 - Centro',
                tempo: 'Há 15 min',
                status: 'Pendente',
                statusColor: Colors.orange,
                urgente: true,
              ),
              _buildCardExemplo(
                titulo: 'Gata com filhotes em terreno baldio',
                local: 'Av. Paulista, 1500 - Bela Vista',
                tempo: 'Há 1 hora',
                status: 'Em Resgate',
                statusColor: Colors.blue,
                urgente: false,
              ),
              _buildCardExemplo(
                titulo: 'Cão idoso abandonado em praça',
                local: 'Praça da Matriz - Jardim das Rosas',
                tempo: 'Há 3 horas',
                status: 'Resgatado',
                statusColor: Colors.green,
                urgente: false,
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Scaffold fornece a estrutura básica de layout visual (fundo, barras, botão flutuante)
    return Scaffold(
      backgroundColor: Colors.grey[100],

      // Barra superior com título dinâmico e ações
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

      // Corpo da tela alternando dinamicamente entre Feed e Mapa
      body: _buildBody(),

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

  // Constrói chip interativo para filtrar os tipos de denúncias na listagem
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

  // Card para exibição de cada denúncia no feed
  Widget _buildCardExemplo({
    required String titulo,
    required String local,
    required String tempo,
    required String status,
    required Color statusColor,
    required bool urgente,
  }) {
    // Card cria um container elevado para destacar cada denúncia visualmente
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Tag de status do atendimento da ocorrência
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  tempo,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              titulo,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.location_on, size: 16, color: Colors.purple),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    local,
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
}
