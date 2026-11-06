import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AvaliacaoDialog extends StatefulWidget {
  final String usuarioId;
  final String nome;
  final String email;
  final String denunciaId;

  const AvaliacaoDialog({
    super.key,
    required this.usuarioId,
    required this.nome,
    required this.email,
    required this.denunciaId,
  });

  @override
  State<AvaliacaoDialog> createState() => _AvaliacaoDialogState();
}

class _AvaliacaoDialogState extends State<AvaliacaoDialog> {
  final TextEditingController _comentarioController = TextEditingController();
  int _nota = 0;
  bool _salvando = false;
  bool _salva = false;
  String? _erro;

  @override
  void dispose() {
    _comentarioController.dispose();
    super.dispose();
  }

  Future<void> _salvarAvaliacao() async {
    if (_nota == 0) {
      setState(() => _erro = 'Selecione uma nota de 1 a 5 estrelas.');
      return;
    }

    setState(() {
      _salvando = true;
      _erro = null;
    });

    final comentario = _comentarioController.text.trim();
    try {
      await FirebaseFirestore.instance.collection('avaliacoes').add({
        'usuarioId': widget.usuarioId,
        'nome': widget.nome,
        'email': widget.email,
        'denunciaId': widget.denunciaId,
        'nota': _nota,
        'comentario': comentario.isEmpty ? 'Sem comentário' : comentario,
        'tipo': 'aplicativo',
        'criadoEm': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        setState(() {
          _salva = true;
          _salvando = false;
        });
      }
    } on FirebaseException catch (e) {
      debugPrint('Erro Firebase ao salvar avaliação: ${e.code} - ${e.message}');
      if (mounted) {
        setState(() {
          _erro = switch (e.code) {
            'permission-denied' => 'O Firebase recusou a gravação. Verifique as regras do Firestore.',
            'unauthenticated' => 'Sua sessão expirou. Faça login novamente.',
            'unavailable' =>
              'Não foi possível conectar ao Firebase. Verifique sua conexão.',
            _ => 'Não foi possível salvar a avaliação: ${e.message ?? e.code}',
          };
          _salvando = false;
        });
      }
    } catch (e) {
      debugPrint('Erro ao salvar avaliação: $e');
      if (mounted) {
        setState(() {
          _erro = 'Ocorreu um erro ao salvar sua avaliação. Tente novamente.';
          _salvando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_salva ? 'Obrigado pela avaliação!' : 'Avalie o SOS Pet'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _salva
                  ? 'Sua avaliação foi salva com sucesso.'
                  : 'Sua denúncia foi registrada com sucesso. '
                        'Como foi sua experiência com o aplicativo?',
            ),
            if (!_salva) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  5,
                  (index) => IconButton(
                    tooltip: '${index + 1} estrelas',
                    onPressed: _salvando
                        ? null
                        : () => setState(() {
                            _nota = index + 1;
                            _erro = null;
                          }),
                    icon: Icon(
                      index < _nota ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 32,
                    ),
                  ),
                ),
              ),
              TextField(
                controller: _comentarioController,
                enabled: !_salvando,
                maxLength: 500,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Comentário (opcional)',
                  border: OutlineInputBorder(),
                ),
              ),
              if (_erro != null) ...[
                const SizedBox(height: 8),
                Text(
                  _erro!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ],
        ),
      ),
      actions: _salva
          ? [
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Concluir'),
              ),
            ]
          : [
              TextButton(
                onPressed: _salvando
                    ? null
                    : () => Navigator.pop(context, false),
                child: const Text('Agora não'),
              ),
              FilledButton(
                onPressed: _salvando ? null : _salvarAvaliacao,
                child: _salvando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Enviar avaliação'),
              ),
            ],
    );
  }
}
