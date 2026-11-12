import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:sos_pet/avaliacao_dialog.dart';

// Tela de formulário completo para registro de denúncia de animais abandonados ou em risco
class DenunciaScreen extends StatefulWidget {
  // Permite receber uma foto capturada previamente (ex: vinda da tela Home)
  final XFile? fotoInicial;
  final bool flagranteInicial;

  const DenunciaScreen({
    super.key,
    this.fotoInicial,
    this.flagranteInicial = false,
  });

  @override
  State<DenunciaScreen> createState() => _DenunciaScreenState();
}

class _DenunciaScreenState extends State<DenunciaScreen> {
  // Chave global para controle e validação do formulário
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // Controla se houve flagrante de abandono com veículo/autor envolvido (Sim / Não)
  bool _isFlagrante = false;

  // Controladores de texto para campos gerais da ocorrência
  final TextEditingController _localController = TextEditingController();
  final TextEditingController _descricaoController = TextEditingController();

  // Controladores de texto específicos para flagrantes de abandono (veículo)
  final TextEditingController _placaController = TextEditingController();
  final TextEditingController _modeloVeiculoController =
      TextEditingController();
  final TextEditingController _corVeiculoController = TextEditingController();
  final TextEditingController _detalhesAutorController =
      TextEditingController();

  // Valores selecionados para espécie, porte e condição do animal
  String _especieSelecionada = 'Cachorro';
  String _porteSelecionado = 'Médio';
  String _condicaoAnimal = 'Aparentemente bem';

  // Imagem capturada (câmera ou galeria) - Não obrigatória
  XFile? _imagemSelecionada;
  final ImagePicker _picker = ImagePicker();

  bool _enviando = false;

  // Coordenadas obtidas via GPS
  Position? _posicaoGps;
  bool _obtendoGps = false;

  @override
  void initState() {
    super.initState();
    _isFlagrante = widget.flagranteInicial;
    if (widget.fotoInicial != null) {
      _imagemSelecionada = widget.fotoInicial;
    }
  }

  @override
  void dispose() {
    _localController.dispose();
    _descricaoController.dispose();
    _placaController.dispose();
    _modeloVeiculoController.dispose();
    _corVeiculoController.dispose();
    _detalhesAutorController.dispose();
    super.dispose();
  }

  // Essa camada de código captura foto da câmera ou escolhe da galeria (não obrigatório)
  Future<void> _selecionarImagem(ImageSource source) async {
    try {
      if (source == ImageSource.camera) {
        // Solicita permissão da câmera em tempo de execução
        final PermissionStatus status = await Permission.camera.request();
        if (status.isPermanentlyDenied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                  'Permissão da câmera negada permanentemente. Ative nas configurações do app.',
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
                content: Text(
                  'Permissão da câmera necessária para fotografar.',
                ),
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

      if (foto != null) {
        setState(() {
          _imagemSelecionada = foto;
        });
      }
    } catch (e) {
      debugPrint('Erro ao selecionar foto: $e');
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

  // Essa camada de código obtém a localização exata atual do celular via GPS e converte em endereço legível
  Future<void> _capturarLocalizacaoAtual() async {
    setState(() => _obtendoGps = true);

    try {
      bool servicoAtivo = await Geolocator.isLocationServiceEnabled();
      if (!servicoAtivo) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Por favor, ative o GPS do celular.'),
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
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Permissão de localização negada.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      }

      if (permissao == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Permissão de GPS negada permanentemente nas configurações.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final Position posicao = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      // Converte as coordenadas GPS em endereço formal (rua, número, bairro, cidade) via geocoding reverso
      String enderecoFormatado = '';
      try {
        final geocoding = Geocoding();
        final List<Placemark> placemarks = await geocoding
            .placemarkFromCoordinates(posicao.latitude, posicao.longitude);

        if (placemarks.isNotEmpty) {
          final Placemark lugar = placemarks.first;
          final List<String> partes = [];

          // Logradouro (rua, avenida) e número
          if (lugar.thoroughfare != null &&
              lugar.thoroughfare!.trim().isNotEmpty) {
            if (lugar.subThoroughfare != null &&
                lugar.subThoroughfare!.trim().isNotEmpty) {
              partes.add(
                '${lugar.thoroughfare!.trim()}, ${lugar.subThoroughfare!.trim()}',
              );
            } else {
              partes.add(lugar.thoroughfare!.trim());
            }
          }

          // Bairro
          if (lugar.subLocality != null &&
              lugar.subLocality!.trim().isNotEmpty) {
            partes.add(lugar.subLocality!.trim());
          }

          // Cidade / Município e Estado
          String cidade = '';
          if (lugar.subAdministrativeArea != null &&
              lugar.subAdministrativeArea!.trim().isNotEmpty) {
            cidade = lugar.subAdministrativeArea!.trim();
          } else if (lugar.locality != null &&
              lugar.locality!.trim().isNotEmpty) {
            cidade = lugar.locality!.trim();
          }

          if (cidade.isNotEmpty) {
            if (lugar.administrativeArea != null &&
                lugar.administrativeArea!.trim().isNotEmpty) {
              partes.add('$cidade - ${lugar.administrativeArea!.trim()}');
            } else {
              partes.add(cidade);
            }
          }

          if (partes.isNotEmpty) {
            enderecoFormatado = partes.join(', ');
          }
        }
      } catch (eGeocoding) {
        debugPrint('Erro no geocoding reverso: $eGeocoding');
      }

      // Se a busca de endereço textual não retornar dados, utiliza coordenadas como fallback seguro
      if (enderecoFormatado.isEmpty) {
        enderecoFormatado =
            'Coordenadas GPS: ${posicao.latitude.toStringAsFixed(5)}, ${posicao.longitude.toStringAsFixed(5)}';
      }

      setState(() {
        _posicaoGps = posicao;
        _localController.text = enderecoFormatado;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Endereço preenchido com base na sua localização atual!',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Erro ao obter GPS: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Não foi possível obter a localização: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _obtendoGps = false);
      }
    }
  }

  // Essa camada de código valida os campos e envia a denúncia para a central de resgate

  Future<void> _enviarDenuncia() async {
    // 1. Valida os campos obrigatórios.
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preencha os campos obrigatórios (*).'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // 2. Verifica se existe um usuário autenticado.
    final usuario = FirebaseAuth.instance.currentUser;

    if (usuario == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Faça login para registrar uma denúncia.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _enviando = true);

    try {
      // 3. Se houver foto, envia ao Firebase Storage.
      String? urlFoto;

      if (_imagemSelecionada != null) {
        try {
          final bytes = await _imagemSelecionada!.readAsBytes();
          final referencia = FirebaseStorage.instance.ref().child(
            'denuncias/${usuario.uid}/${DateTime.now().millisecondsSinceEpoch}.jpg',
          );

          final snapshot = await referencia.putData(
            bytes,
            SettableMetadata(
              contentType: _imagemSelecionada!.mimeType ?? 'image/jpeg',
            ),
          );
          urlFoto = await snapshot.ref.getDownloadURL();
        } on FirebaseException catch (e) {
          debugPrint(
            'Erro ao enviar foto da denúncia: ${e.code} - ${e.message}',
          );
        } catch (e) {
          debugPrint('Erro ao ler ou enviar foto da denúncia: $e');
        }
      }

      // 4. Monta os dados da denúncia.
      final dados = <String, dynamic>{
        'usuarioId': usuario.uid,
        'emailUsuario': usuario.email,
        'tipo': _isFlagrante ? 'Flagrante' : 'Animal encontrado',
        'especie': _especieSelecionada,
        'porte': _porteSelecionado,
        'condicaoAnimal': _condicaoAnimal,
        'descricao': _descricaoController.text.trim(),
        'endereco': _localController.text.trim(),
        'latitude': _posicaoGps?.latitude,
        'longitude': _posicaoGps?.longitude,
        'placaVeiculo': _isFlagrante ? _placaController.text.trim() : null,
        'modeloVeiculo': _isFlagrante
            ? _modeloVeiculoController.text.trim()
            : null,
        'corVeiculo': _isFlagrante ? _corVeiculoController.text.trim() : null,
        'detalhesAutor': _isFlagrante
            ? _detalhesAutorController.text.trim()
            : null,
        'fotoUrl': urlFoto,
        'status': 'Pendente',
        'criadoEm': FieldValue.serverTimestamp(),
        'atualizacoes': <Map<String, dynamic>>[],
        'ultimaAtualizacao': 'Denúncia recebida e aguardando atendimento.',
        'statusAtualizadoEm': FieldValue.serverTimestamp(),
      };

      var primeiraDenuncia = false;
      try {
        final denunciasAnteriores = await FirebaseFirestore.instance
            .collection('denuncias')
            .where('usuarioId', isEqualTo: usuario.uid)
            .limit(1)
            .get(const GetOptions(source: Source.server));
        primeiraDenuncia = denunciasAnteriores.docs.isEmpty;
      } catch (e) {
        debugPrint('Não foi possível verificar denúncias anteriores: $e');
      }

      // 5. Salva um novo documento na coleção "denuncias".
      final resultado = await FirebaseFirestore.instance
          .collection('denuncias')
          .add(dados);

      debugPrint('Denúncia salva com ID ${resultado.id}');

      if (!mounted) return;

      if (primeiraDenuncia) {
        final nomeUsuario = usuario.displayName?.trim();
        final nomeFallback = usuario.email?.split('@').first;
        await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => AvaliacaoDialog(
            usuarioId: usuario.uid,
            nome: nomeUsuario?.isNotEmpty == true
                ? nomeUsuario!
                : nomeFallback ?? 'Usuário SOS Pet',
            email: usuario.email ?? '',
            denunciaId: resultado.id,
          ),
        );
      } else {
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Expanded(child: Text('Denúncia registrada!')),
              ],
            ),
            content: const Text('Sua denúncia foi registrada com sucesso.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }

      if (mounted) {
        Navigator.pop(context);
      }
    } on FirebaseException catch (e) {
      debugPrint('Erro Firebase: ${e.code} - ${e.message}');

      if (mounted) {
        final mensagem = switch (e.code) {
          'permission-denied' =>
            'O Firestore bloqueou a gravação. Verifique se as regras '
                'firestore.rules foram publicadas no projeto Firebase.',
          'unauthenticated' => 'Sua sessão expirou. Faça login novamente.',
          'unavailable' => 'O serviço está indisponível. Verifique sua conexão e tente novamente.',
          _ => e.message ?? e.code,
        };
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar denúncia: $mensagem'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint('Erro ao registrar denúncia: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ocorreu um erro ao registrar a denúncia.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _enviando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Scaffold fornece a estrutura básica de layout visual (fundo, barras, gavetas)
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 255, 202, 248),

      // Barra superior com o título da tela
      appBar: AppBar(
        title: const Text(
          'Registrar Denúncia',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color.fromARGB(255, 255, 202, 248),
        foregroundColor: Colors.purple,
        elevation: 1,
        // Essa camada de código é do botão de voltar para a tela anterior
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.purple),
          tooltip: 'Voltar',
          onPressed: () => Navigator.pop(context),
        ),
      ),

      // Corpo com formulário rolável
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // -------------------------------------------------------------
              // PERGUNTA INICIAL: Flagra de abandono? Sim / Não
              // -------------------------------------------------------------
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.deepOrange,
                            size: 28,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Flagra de abandono?',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Você presenciou alguém abandonando o animal em um veículo ou em flagrante delito?',
                        style: TextStyle(fontSize: 13, color: Colors.black54),
                      ),
                      const SizedBox(height: 16),

                      // Botões de alternância SIM / NÃO
                      Row(
                        children: [
                          // Essa camada de código é do botão de seleção "SIM" (Flagrante)
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                setState(() {
                                  _isFlagrante = true;
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isFlagrante
                                    ? Colors.red
                                    : Colors.grey[200],
                                foregroundColor: _isFlagrante
                                    ? Colors.white
                                    : Colors.black87,
                                elevation: _isFlagrante ? 3 : 0,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              icon: const Icon(Icons.car_crash, size: 20),
                              label: const Text(
                                'SIM (Flagrante)',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Essa camada de código é do botão de seleção "NÃO" (Apenas encontrado)
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                setState(() {
                                  _isFlagrante = false;
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: !_isFlagrante
                                    ? Colors.purple
                                    : Colors.grey[200],
                                foregroundColor: !_isFlagrante
                                    ? Colors.white
                                    : Colors.black87,
                                elevation: !_isFlagrante ? 3 : 0,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              icon: const Icon(Icons.pets, size: 20),
                              label: const Text(
                                'NÃO (Encontrado)',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // -------------------------------------------------------------
              // BLOCO CONDICIONAL: SE SIM (FLAGRANTE DE ABANDONO COM VEÍCULO)
              // -------------------------------------------------------------
              if (_isFlagrante) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.directions_car, color: Colors.red),
                            SizedBox(width: 8),
                            Text(
                              'Dados do Veículo e Infrator',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Preencha as informações que você conseguiu identificar (não obrigatórias):',
                          style: TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                        const SizedBox(height: 16),

                        // Campo Placa do Veículo
                        TextFormField(
                          controller: _placaController,
                          textCapitalization: TextCapitalization.characters,
                          decoration: InputDecoration(
                            labelText: 'Placa do veículo',
                            hintText: 'Ex: ABC-1234 ou ABC1D23',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            prefixIcon: const Icon(
                              Icons.pin,
                              color: Colors.purple,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Linha com Modelo e Cor
                        Row(
                          children: [
                            // Campo Modelo
                            Expanded(
                              child: TextFormField(
                                controller: _modeloVeiculoController,
                                decoration: InputDecoration(
                                  labelText: 'Modelo',
                                  hintText: 'Ex: Gol, Palio',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.car_repair,
                                    color: Colors.purple,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Campo Cor do Veículo
                            Expanded(
                              child: TextFormField(
                                controller: _corVeiculoController,
                                decoration: InputDecoration(
                                  labelText: 'Cor do veículo',
                                  hintText: 'Ex: Prata, Preto',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.color_lens,
                                    color: Colors.purple,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Campo Observações do autor/condutor
                        TextFormField(
                          controller: _detalhesAutorController,
                          maxLines: 2,
                          decoration: InputDecoration(
                            labelText:
                                'Características do condutor / Situação vista',
                            hintText: 'Ex: Homem de camiseta azul fugiu sentido centro...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            prefixIcon: const Icon(
                              Icons.person_search,
                              color: Colors.purple,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // -------------------------------------------------------------
              // DADOS DO ANIMAL (COMUM PARA AMBOS OS CASOS)
              // -------------------------------------------------------------
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.pets, color: Colors.purple),
                          SizedBox(width: 8),
                          Text(
                            'Informações do Animal',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Espécie do Animal
                      DropdownButtonFormField<String>(
                        initialValue: _especieSelecionada,
                        decoration: InputDecoration(
                          labelText: 'Espécie *',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          prefixIcon: const Icon(
                            Icons.category,
                            color: Colors.purple,
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'Cachorro',
                            child: Text('Cachorro'),
                          ),
                          DropdownMenuItem(value: 'Gato', child: Text('Gato')),
                          DropdownMenuItem(
                            value: 'Cavalo',
                            child: Text('Cavalo / Animal de grande porte'),
                          ),
                          DropdownMenuItem(
                            value: 'Outro',
                            child: Text('Outro'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null)
                            setState(() => _especieSelecionada = val);
                        },
                      ),
                      const SizedBox(height: 12),

                      // Porte e Condição
                      Row(
                        children: [
                          // Porte
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _porteSelecionado,
                              decoration: InputDecoration(
                                labelText: 'Porte',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'Pequeno',
                                  child: Text('Pequeno'),
                                ),
                                DropdownMenuItem(
                                  value: 'Médio',
                                  child: Text('Médio'),
                                ),
                                DropdownMenuItem(
                                  value: 'Grande',
                                  child: Text('Grande'),
                                ),
                              ],
                              onChanged: (val) {
                                if (val != null)
                                  setState(() => _porteSelecionado = val);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Condição
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _condicaoAnimal,
                              decoration: InputDecoration(
                                labelText: 'Condição',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'Aparentemente bem',
                                  child: Text('Saudável'),
                                ),
                                DropdownMenuItem(
                                  value: 'Machucado / Ferido',
                                  child: Text('Machucado'),
                                ),
                                DropdownMenuItem(
                                  value: 'Filhote frágil',
                                  child: Text('Filhote'),
                                ),
                                DropdownMenuItem(
                                  value: 'Desnutrido',
                                  child: Text('Desnutrido'),
                                ),
                              ],
                              onChanged: (val) {
                                if (val != null)
                                  setState(() => _condicaoAnimal = val);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Descrição adicional
                      TextFormField(
                        controller: _descricaoController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: 'Descrição detalhada *',
                          hintText: 'Descreva cores, comportamento ou pontos de referência...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          prefixIcon: const Icon(
                            Icons.notes,
                            color: Colors.purple,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Por favor, descreva o animal e a situação';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // -------------------------------------------------------------
              // FOTO DO ANIMAL / OCORRÊNCIA (NÃO OBRIGATÓRIA)
              // -------------------------------------------------------------
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.camera_alt, color: Colors.purple),
                          SizedBox(width: 8),
                          Text(
                            'Foto da Ocorrência (Opcional)',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Fotos do animal ajudam muito na identificação para um resgate mais eficiente.',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                      const SizedBox(height: 12),

                      // Preview da foto se selecionada
                      if (_imagemSelecionada != null)
                        Stack(
                          alignment: Alignment.topRight,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: kIsWeb
                                  ? Image.network(
                                      _imagemSelecionada!.path,
                                      height: 180,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                    )
                                  : Image.file(
                                      File(_imagemSelecionada!.path),
                                      height: 180,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                    ),
                            ),
                            // Essa camada de código é do botão de remover a foto adicionada
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  _imagemSelecionada = null;
                                });
                              },
                              icon: const CircleAvatar(
                                backgroundColor: Colors.red,
                                radius: 16,
                                child: Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                              tooltip: 'Remover foto',
                            ),
                          ],
                        )
                      else
                        Row(
                          children: [
                            // Essa camada de código é do botão para tirar foto com a Câmera
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () =>
                                    _selecionarImagem(ImageSource.camera),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.purple,
                                  side: const BorderSide(color: Colors.purple),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                icon: const Icon(Icons.camera_alt),
                                label: const Text('Câmera'),
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Essa camada de código é do botão para escolher foto da Galeria
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () =>
                                    _selecionarImagem(ImageSource.gallery),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.purple,
                                  side: const BorderSide(color: Colors.purple),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                icon: const Icon(Icons.photo_library),
                                label: const Text('Galeria'),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // -------------------------------------------------------------
              // LOCALIZAÇÃO DA OCORRÊNCIA
              // -------------------------------------------------------------
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.location_on, color: Colors.purple),
                          SizedBox(width: 8),
                          Text(
                            'Local do Animal *',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Campo de endereço / ponto de referência
                      TextFormField(
                        controller: _localController,
                        decoration: InputDecoration(
                          labelText: 'Endereço ou Ponto de Referência *',
                          hintText:
                              'Ex: Rodovia SP-300, Km 45 ou Praça Central',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          prefixIcon: const Icon(
                            Icons.map,
                            color: Colors.purple,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'O local da ocorrência é obrigatório';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      // Essa camada de código é do botão de captura rápida da localização via GPS
                      ElevatedButton.icon(
                        onPressed: _obtendoGps
                            ? null
                            : _capturarLocalizacaoAtual,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple[50],
                          foregroundColor: Colors.purple,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: const BorderSide(color: Colors.purple),
                          ),
                        ),
                        icon: _obtendoGps
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.purple,
                                ),
                              )
                            : const Icon(Icons.my_location, size: 20),
                        label: Text(
                          _obtendoGps
                              ? 'Obtendo endereço...'
                              : (_posicaoGps != null
                                    ? 'Atualizar com localização atual'
                                    : 'Usar minha localização atual'),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // -------------------------------------------------------------
              // BOTÃO FINAL DE ENVIO DA DENÚNCIA
              // -------------------------------------------------------------
              // Essa camada de código é do botão principal para "ENVIAR DENÚNCIA"
              ElevatedButton.icon(
                onPressed: _enviando ? null : _enviarDenuncia,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: _enviando
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded, size: 22),

                label: Text(
                  _enviando ? 'SALVANDO DENÚNCIA...' : 'ENVIAR DENÚNCIA',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
