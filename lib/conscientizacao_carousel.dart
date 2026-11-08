import 'dart:async';
import 'package:flutter/material.dart';

// Modelo representando cada item do carrossel de conscientização
class ConscientizacaoItem {
  final String frase;
  final String imagemAsset;

  const ConscientizacaoItem({
    required this.frase,
    required this.imagemAsset,
  });
}

// Widget com carrossel automático que alterna a cada 3 segundos com efeito de transição suave e loop infinito contínuo
class ConscientizacaoCarousel extends StatefulWidget {
  const ConscientizacaoCarousel({super.key});

  // Método público para pré-carregar os assets na inicialização global do app
  static Future<void> precacheImagens(BuildContext context) async {
    for (final item in _ConscientizacaoCarouselState._itens) {
      precacheImage(
        AssetImage(item.imagemAsset),
        context,
      );
    }
  }

  @override
  State<ConscientizacaoCarousel> createState() => _ConscientizacaoCarouselState();
}

class _ConscientizacaoCarouselState extends State<ConscientizacaoCarousel> {
  // Lista com as 32 frases distribuídas entre as fotos de cães e gatos em assets
  static const List<ConscientizacaoItem> _itens = [
    ConscientizacaoItem(
      frase: 'Um animal não é descartável. É uma vida que sente.',
      imagemAsset: 'assets/images/dogs/dog1.jpg',
    ),
    ConscientizacaoItem(
      frase: 'Adotar é transformar duas vidas: a sua e a dele.',
      imagemAsset: 'assets/images/cats/cat1.jpg',
    ),
    ConscientizacaoItem(
      frase: 'Abandonar é virar as costas para quem só oferece amor.',
      imagemAsset: 'assets/images/dogs/dog2.jpg',
    ),
    ConscientizacaoItem(
      frase: 'Eles não precisam de luxo, precisam de cuidado.',
      imagemAsset: 'assets/images/cats/cat2.jpg',
    ),
    ConscientizacaoItem(
      frase: 'Uma denúncia pode salvar uma vida.',
      imagemAsset: 'assets/images/dogs/dog3.jpg',
    ),
    ConscientizacaoItem(
      frase: 'Amor também se demonstra com responsabilidade.',
      imagemAsset: 'assets/images/cats/cat3.jpg',
    ),
    ConscientizacaoItem(
      frase: 'Não compre por impulso. Adote com consciência.',
      imagemAsset: 'assets/images/dogs/dog4.jpg',
    ),
    ConscientizacaoItem(
      frase: 'Quem ama, protege. Quem cuida, não abandona.',
      imagemAsset: 'assets/images/cats/cat4.jpg',
    ),
    ConscientizacaoItem(
      frase: 'Um lar muda tudo para quem já sofreu tanto.',
      imagemAsset: 'assets/images/dogs/dog5.jpg',
    ),
    ConscientizacaoItem(
      frase: 'Animais sentem fome, frio, medo e saudade.',
      imagemAsset: 'assets/images/cats/cat5.jpg',
    ),
    ConscientizacaoItem(
      frase: 'Não ignore um animal em situação de risco.',
      imagemAsset: 'assets/images/dogs/dog6.jpg',
    ),
    ConscientizacaoItem(
      frase: 'Pequenas atitudes podem salvar grandes vidas.',
      imagemAsset: 'assets/images/cats/cat6.jpg',
    ),
    ConscientizacaoItem(
      frase: 'A rua não é lugar para quem só quer carinho.',
      imagemAsset: 'assets/images/dogs/dog7.jpg',
    ),
    ConscientizacaoItem(
      frase: 'Adoção é um compromisso para a vida toda.',
      imagemAsset: 'assets/images/cats/cat7.jpg',
    ),
    ConscientizacaoItem(
      frase: 'Seja a voz de quem não consegue pedir ajuda.',
      imagemAsset: 'assets/images/dogs/dog8.jpg',
    ),
    ConscientizacaoItem(
      frase: 'Cuidar de um animal é um ato de humanidade.',
      imagemAsset: 'assets/images/cats/cat8.jpg',
    ),
    ConscientizacaoItem(
      frase: 'O abandono deixa marcas que não aparecem.',
      imagemAsset: 'assets/images/dogs/dog9.jpg',
    ),
    ConscientizacaoItem(
      frase: 'Eles precisam de respeito, proteção e amor.',
      imagemAsset: 'assets/images/cats/cat9.jpg',
    ),
    ConscientizacaoItem(
      frase: 'Antes de adotar, pense na responsabilidade.',
      imagemAsset: 'assets/images/dogs/dog10.jpg',
    ),
    ConscientizacaoItem(
      frase: 'Não abandone. Procure ajuda.',
      imagemAsset: 'assets/images/cats/cat10.jpg',
    ),
    ConscientizacaoItem(
      frase: 'Todo animal merece uma chance de ser feliz.',
      imagemAsset: 'assets/images/dogs/dog11.jpg',
    ),
    ConscientizacaoItem(
      frase: 'Uma atitude sua pode mudar uma história.',
      imagemAsset: 'assets/images/cats/cat11.jpg',
    ),
    ConscientizacaoItem(
      frase: 'Alimentar, proteger e acolher também é amar.',
      imagemAsset: 'assets/images/dogs/dog12.jpg',
    ),
    ConscientizacaoItem(
      frase: 'Maus-tratos não são brincadeira. Denuncie!',
      imagemAsset: 'assets/images/cats/cat12.jpg',
    ),
    ConscientizacaoItem(
      frase: 'Não existe motivo que justifique o abandono.',
      imagemAsset: 'assets/images/dogs/dog13.jpg',
    ),
    ConscientizacaoItem(
      frase: 'Um coração pequeno também sente grandes dores.',
      imagemAsset: 'assets/images/cats/cat13.jpg',
    ),
    ConscientizacaoItem(
      frase: 'Seja parte da mudança. Ajude a proteger.',
      imagemAsset: 'assets/images/dogs/dog14.jpg',
    ),
    ConscientizacaoItem(
      frase: 'A vida deles também importa.',
      imagemAsset: 'assets/images/cats/cat14.jpg',
    ),
    ConscientizacaoItem(
      frase: 'Respeitar os animais é respeitar a vida.',
      imagemAsset: 'assets/images/dogs/dog15.jpg',
    ),
    ConscientizacaoItem(
      frase: 'Não feche os olhos para o sofrimento animal.',
      imagemAsset: 'assets/images/cats/cat15.jpg',
    ),
    ConscientizacaoItem(
      frase: 'A solidariedade começa com uma atitude.',
      imagemAsset: 'assets/images/dogs/dog16.jpg',
    ),
    ConscientizacaoItem(
      frase: 'Juntos podemos construir um mundo sem abandono.',
      imagemAsset: 'assets/images/cats/cat16.jpg',
    ),
  ];

  // Base grande para permitir rolagem infinita contínua sem interrupção
  static const int _baseInicial = 10000;

  late final PageController _pageController;
  Timer? _timer;
  int _paginaAbsoluta = _baseInicial;
  bool _precacheIniciado = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _paginaAbsoluta);
    _iniciarAutoPlay();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Pré-carrega todas as imagens de assets na memória do dispositivo
    // para que a transição ocorra com a imagem já renderizada
    if (!_precacheIniciado) {
      _precacheIniciado = true;
      for (final item in _itens) {
        precacheImage( 
          AssetImage(item.imagemAsset),
          context,
          size: const Size(600, 300),
        );
      }
    }
  }

  void _iniciarAutoPlay() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!mounted || !_pageController.hasClients) return;
      _paginaAbsoluta++;
      _pageController.animateToPage(
        _paginaAbsoluta,
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 230,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // PageView infinito exibindo cada card com imagem e frase pré-carregadas
            PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() => _paginaAbsoluta = index);
                // Reinicia o contador de 3 segundos quando o usuário desliza manualmente
                _iniciarAutoPlay();
              },
              itemBuilder: (context, index) {
                // Cálculo de índice cíclico para nunca interromper a rotação
                final itemIndex = (index % _itens.length + _itens.length) % _itens.length;
                final item = _itens[itemIndex];

                return Stack(
                  fit: StackFit.expand,
                  children: [
                    // Imagem de fundo em assets já recortada na proporção ideal pelo usuário
                    Image.asset(
                      item.imagemAsset,
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
                      cacheWidth: 900,
                      gaplessPlayback: true,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.purple, Colors.deepPurple],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                        );
                      },
                    ),

                    // Gradiente escuro para garantir nitidez e contraste da frase centralizada
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.25),
                            Colors.black.withValues(alpha: 0.75),
                          ],
                        ),
                      ),
                    ),

                    // Mensagem centralizada no centro da imagem com o ícone de aspas (") e fonte aumentada
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24.0,
                        vertical: 16.0,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.format_quote_rounded,
                            color: Colors.white70,
                            size: 38,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            item.frase,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              height: 1.3,
                              shadows: [
                                Shadow(
                                  offset: Offset(0, 2),
                                  blurRadius: 6,
                                  color: Colors.black,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),


          ],
        ),
      ),
    );
  }
}
