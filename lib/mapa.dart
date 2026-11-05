import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

// Tela interativa com Google Maps exibindo a localização em tempo real e as ocorrências
class MapaScreen extends StatefulWidget {
  // Permite renderizar o mapa embutido na Home ou como tela individual completa
  final bool embedded;

  const MapaScreen({super.key, this.embedded = false});

  @override
  State<MapaScreen> createState() => _MapaScreenState();
}

class _MapaScreenState extends State<MapaScreen> {
  // Controlador para manipular a câmera e ações no Google Maps
  GoogleMapController? _mapController;

  // Assinatura para ouvir o fluxo contínuo de GPS em tempo real
  StreamSubscription<Position>? _posicaoStreamSubscription;

  // Posição padrão de fallback caso o GPS esteja desligado (São Paulo / SP)
  static const CameraPosition _posicaoPadrao = CameraPosition(
    target: LatLng(-23.55052, -46.633308),
    zoom: 14.0,
  );

  // Indica se a permissão de GPS foi concedida
  bool _temPermissaoLocalizacao = false;

  // Indica se o GPS ainda está buscando as coordenadas iniciais
  bool _buscandoLocalizacao = true;

  // Guarda as coordenadas atuais do usuário em tempo real
  LatLng? _posicaoAtualUsuario;

  // Flag para centralizar a câmera apenas na primeira leitura do GPS
  bool _primeiraCentralizacaoFeita = false;

  // Conjunto de marcadores de denúncias e posição do usuário no mapa
  final Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    // Essa camada de código carrega os marcadores das denúncias de exemplo
    _carregarMarcadoresExemplo();
    // Essa camada de código inicia o monitoramento da localização em tempo real
    _iniciarLocalizacaoEmTempoReal();
  }

  @override
  void dispose() {
    // Essa camada de código cancela o ouvinte de GPS e descarrega o mapa para não consumir recursos nem interferir nas outras telas
    _posicaoStreamSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  // Essa camada de código configura e inicia a captura contínua do GPS em tempo real
  Future<void> _iniciarLocalizacaoEmTempoReal() async {
    try {
      bool servicoHabilitado = await Geolocator.isLocationServiceEnabled();
      if (!servicoHabilitado) {
        if (mounted) {
          setState(() => _buscandoLocalizacao = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ative o GPS nas configurações do celular para ver sua localização exata.'),
              backgroundColor: Colors.purple,
            ),
          );
        }
        return;
      }

      LocationPermission permissao = await Geolocator.checkPermission();
      if (permissao == LocationPermission.denied) {
        permissao = await Geolocator.requestPermission();
        if (permissao == LocationPermission.denied) {
          if (mounted) {
            setState(() => _buscandoLocalizacao = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Permissão de GPS necessária para exibir sua posição no mapa.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      }

      if (permissao == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() => _buscandoLocalizacao = false);
        }
        return;
      }

      // Permissão confirmada! Habilita o modo de localização no mapa
      if (mounted) {
        setState(() => _temPermissaoLocalizacao = true);
      }

      // 1. Tenta obter rapidamente a última posição conhecida para resposta instantânea
      final Position? ultimaPosicao = await Geolocator.getLastKnownPosition();
      if (ultimaPosicao != null && mounted) {
        _atualizarPosicao(LatLng(ultimaPosicao.latitude, ultimaPosicao.longitude));
      }

      // 2. Obtém a posição atual com precisão alta
      final Position posicaoAtual = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      _atualizarPosicao(LatLng(posicaoAtual.latitude, posicaoAtual.longitude));

      // 3. Ouve as mudanças de localização em tempo real enquanto o usuário estiver nesta tela
      _posicaoStreamSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5, // Atualiza a cada 5 metros percorridos
        ),
      ).listen(
        (Position novaPosicao) {
          _atualizarPosicao(LatLng(novaPosicao.latitude, novaPosicao.longitude));
        },
        onError: (erro) {
          debugPrint('Erro no stream de localização: $erro');
        },
      );
    } catch (e) {
      debugPrint('Aviso ao capturar GPS: $e');
      if (mounted) {
        setState(() => _buscandoLocalizacao = false);
      }
    }
  }

  // Atualiza as coordenadas em tempo real e recentraliza o mapa
  void _atualizarPosicao(LatLng coordenadas) {
    if (!mounted) return;

    setState(() {
      _posicaoAtualUsuario = coordenadas;
      _buscandoLocalizacao = false;

      // Adiciona ou atualiza o marcador roxo indicando a posição do usuário
      _markers.removeWhere((m) => m.markerId == const MarkerId('minha_posicao'));
      _markers.add(
        Marker(
          markerId: const MarkerId('minha_posicao'),
          position: coordenadas,
          infoWindow: const InfoWindow(
            title: 'Você está aqui',
            snippet: 'Localização atual em tempo real',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
        ),
      );
    });

    // Se for a primeira vez que encontrou a localização, foca a câmera automaticamente no usuário
    if (!_primeiraCentralizacaoFeita) {
      _primeiraCentralizacaoFeita = true;
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: coordenadas, zoom: 16.5),
        ),
      );
    }
  }

  // Popula os marcadores de denúncias para visualização
  void _carregarMarcadoresExemplo() {
    setState(() {
      _markers.addAll([
        Marker(
          markerId: const MarkerId('denuncia_1'),
          position: const LatLng(-23.55052, -46.633308),
          infoWindow: const InfoWindow(
            title: 'Cachorro Machucado',
            snippet: 'Status: Pendente - Rua das Flores',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
        Marker(
          markerId: const MarkerId('denuncia_2'),
          position: const LatLng(-23.55352, -46.631308),
          infoWindow: const InfoWindow(
            title: 'Gata com Filhotes',
            snippet: 'Status: Em Resgate - Av. Paulista',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        ),
        Marker(
          markerId: const MarkerId('denuncia_3'),
          position: const LatLng(-23.54752, -46.636308),
          infoWindow: const InfoWindow(
            title: 'Cão Idoso Abandonado',
            snippet: 'Status: Resgatado - Praça Central',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        ),
      ]);
    });
  }

  // Callback chamado quando o mapa é completamente instanciado na tela
  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    // Se a localização já foi obtida antes do mapa renderizar, move a câmera
    if (_posicaoAtualUsuario != null) {
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: _posicaoAtualUsuario!, zoom: 16.5),
        ),
      );
    }
  }

  // Constrói a visualização do mapa com controles de zoom e localização
  Widget _buildMapContent() {
    return Stack(
      children: [
        // Widget do Google Maps renderizando a camada geográfica
        GoogleMap(
          onMapCreated: _onMapCreated,
          initialCameraPosition: _posicaoPadrao,
          markers: _markers,
          myLocationEnabled: _temPermissaoLocalizacao,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          compassEnabled: true,
        ),

        // Barra informativa de busca de GPS
        if (_buscandoLocalizacao)
          Positioned(
            top: 16,
            left: 20,
            right: 80,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
                ],
              ),
              child: const Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.purple),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Obtendo localização em tempo real...',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.purple),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Essa camada de código é do botão de recentralizar o mapa na localização do usuário
        Positioned(
          top: 16,
          right: 16,
          child: FloatingActionButton.small(
            backgroundColor: Colors.white,
            foregroundColor: Colors.purple,
            heroTag: 'recentralizar_mapa',
            tooltip: 'Recentralizar na minha localização',
            onPressed: () {
              // Ao clicar no botão, move a câmera instantaneamente para as coordenadas do usuário
              if (_posicaoAtualUsuario != null) {
                _mapController?.animateCamera(
                  CameraUpdate.newCameraPosition(
                    CameraPosition(target: _posicaoAtualUsuario!, zoom: 17.0),
                  ),
                );
              } else {
                _iniciarLocalizacaoEmTempoReal();
              }
            },
            child: const Icon(Icons.my_location),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Se estiver embutido em outra tela, retorna diretamente o conteúdo do mapa
    if (widget.embedded) {
      return _buildMapContent();
    }

    // Essa camada de código é a estrutura de tela inteira (Scaffold) com barra superior
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Mapa de Ocorrências',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.purple,
        elevation: 1,
        // Essa camada de código é do botão de voltar da barra superior
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.purple),
          tooltip: 'Voltar',
          onPressed: () {
            // Fecha a tela do mapa e retorna à anterior
            Navigator.pop(context);
          },
        ),
      ),
      body: _buildMapContent(),
    );
  }
}
