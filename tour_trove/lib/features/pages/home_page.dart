import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:image_picker/image_picker.dart'; 
import 'package:camera/camera.dart';             

import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart'; 

const String kCustomVisionUrl =
    'https://SEU-ENDPOINT/customvision/v3.0/Prediction/PROJECT_ID/classify/iterations/ITERATION_NAME/image';

const String kPredictionKey = 'PREDICTION_KEY_AQUI';

const String kDescricaoApiBase = 'http://localhost:6790/exposicao/nome?nome=';






class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // ===== Reconhecimento/Foto =====
  final ImagePicker _picker = ImagePicker();
  String? nomeExposicao;
  String? descricaoExposicao;
  bool loading = false;

  // ===== Fala (STT) =====
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechAvailable = false;
  bool _isListening = false;
  String pergunta_do_usuario = '';

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize(
      onStatus: (s) {
        if (s.toLowerCase().contains('notlistening') && mounted) {
          setState(() => _isListening = false);
        }
      },
      onError: (e) {
        if (mounted) {
          setState(() => _isListening = false);
          _snack('Erro de áudio: ${e.errorMsg}');
        }
      },
    );
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    _speech.stop();
    super.dispose();
  }

  // ================== Fluxo: Identificar Exposição ==================
  Future<void> identificar_expsoicao() async {
    try {
      // 1) Capturar imagem 
      XFile? photo;
      if (kIsWeb) {
        photo = await _abrirCameraWebCapturar(context);
      } else {
        photo = await _picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 90,
          preferredCameraDevice: CameraDevice.rear,
        );
      }
      if (photo == null) return;

      setState(() => loading = true);

      // 2) Enviar para Custom Vision
      final Uint8List bytes = await photo.readAsBytes();
      final http.Response cvResp = await http.post(
        Uri.parse(kCustomVisionUrl),
        headers: {
          'Content-Type': 'application/octet-stream',
          'Prediction-Key': kPredictionKey,
        },
        body: bytes,
      );

      if (cvResp.statusCode < 200 || cvResp.statusCode >= 300) {
        throw Exception('Custom Vision ${cvResp.statusCode}: ${cvResp.body}');
      }

      final Map<String, dynamic> result = json.decode(cvResp.body) as Map<String, dynamic>;
      final List predictions = (result['predictions'] as List?) ?? [];

      if (predictions.isEmpty) {
        _snack('Nenhuma previsão encontrada. Tente novamente.');
        setState(() => loading = false);
        return;
      }

      predictions.sort((a, b) {
        final pa = (a['probability'] as num? ?? 0);
        final pb = (b['probability'] as num? ?? 0);
        return pb.compareTo(pa);
      });

      final top = predictions.first as Map<String, dynamic>;
      final String tagName = (top['tagName'] ?? '').toString();
      final double prob = ((top['probability'] ?? 0.0) as num).toDouble();

      if (prob < 0.7) {
        _snack('Confiança baixa (${(prob * 100).toStringAsFixed(1)}%). Tente outra foto.');
        setState(() => loading = false);
        return;
      }

      // 3) Buscar descrição no banco de dados
      final uri = Uri.parse('$kDescricaoApiBase${Uri.encodeComponent(tagName.trim())}');
      final http.Response descResp = await http.get(uri);

      if (descResp.statusCode < 200 || descResp.statusCode >= 300) {
        _snack('Descrição da exposição não encontrada.');
        setState(() => loading = false);
        return;
      }

      final Map<String, dynamic> expo = json.decode(descResp.body) as Map<String, dynamic>;

      setState(() {
        nomeExposicao = (expo['nome'] ?? tagName).toString();
        descricaoExposicao = (expo['descricao'] ?? '').toString();
        loading = false;
      });
    } catch (e) {
      setState(() => loading = false);
      _snack('Erro ao identificar: $e');
    }
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  // ================== STT: Perguntar ==================
  Future<void> _togglePerguntar() async {
    if (!_speechAvailable) {
      _snack('Reconhecimento de voz indisponível neste dispositivo/navegador.');
      return;
    }
    if (_isListening) {
      await _stopListening();
    } else {
      await _startListening();
    }
  }

  Future<void> _startListening() async {
    setState(() {
      _isListening = true;
      pergunta_do_usuario = '';
    });

    await _speech.listen(
      localeId: 'pt_BR',
      listenMode: stt.ListenMode.dictation,
      onResult: (result) {
        final text = result.recognizedWords;
        if (mounted) setState(() => pergunta_do_usuario = text);
      },
    );
  }

  Future<void> _stopListening() async {
    await _speech.stop();
    if (!mounted) return;
    setState(() => _isListening = false);
    _snack('Pergunta capturada!');
    // enviar pergunta para o agente de IA (implemnetar) (joao)
  }

  // ================== Câmera (Web) ==================
  Future<XFile?> _abrirCameraWebCapturar(BuildContext context) async {
    return await showDialog<XFile?>(
      context: context,
      barrierDismissible: true,
      builder: (_) => const Dialog(
        insetPadding: EdgeInsets.all(16),
        child: SizedBox(
          width: 480,
          height: 600,
          child: _WebCameraSheet(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            color: Colors.green,
            alignment: Alignment.center,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _ResultadoExposicao(
                nome: nomeExposicao,
                descricao: descricaoExposicao,
                perguntaDebug: pergunta_do_usuario, //pergunta do usuario aparecendo na tela
              ),
            ),
          ),

          // ===== Botão circular centralizado e responsivo =====
          Positioned.fill(
  child: LayoutBuilder(
    builder: (context, constraints) {
      final shortest = constraints.biggest.shortestSide;
      final double diameter = shortest * 0.22 < 80
          ? 80
          : (shortest * 0.22 > 160 ? 160 : shortest * 0.22);

      return Align(
        alignment: const Alignment(0, 0.1), // eixo Y positivo empurra para baixo
        child: _BotaoCircularPerguntar(
          isListening: _isListening,
          onTap: _togglePerguntar,
          label: _isListening ? 'Escutando' : 'Faça uma pergunta',
          diameter: diameter,
        ),
      );
    },
  ),
),


          // ===== Botão: Identificar (fixo no rodapé) — substituído por PillButton =====
          Positioned(
            left: 0,
            right: 0,
            bottom: 90, 
            child: Center(
              child: PillButton(
                label: 'Identificar',
                onPressed: identificar_expsoicao,
                width: 140,  // tamanho controlado
                height: 36,  // realmente menor
                color: Colors.blue,
                textColor: Colors.white,
                fontSize: 14,
              ),
            ),
          ),

          if (loading)
            Container(
              color: Colors.black.withOpacity(0.35),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}

class _ResultadoExposicao extends StatelessWidget {
  final String? nome;
  final String? descricao;
  final String? perguntaDebug;
  const _ResultadoExposicao({
    required this.nome,
    required this.descricao,
    this.perguntaDebug,
  });

  @override
  Widget build(BuildContext context) {
    final hasData =
        (nome != null && nome!.isNotEmpty) || (descricao != null && descricao!.isNotEmpty);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasData) ...[
          Text(
            nome ?? '',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            descricao ?? '',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 20),
        ] else
          const SizedBox.shrink(),

        // (Opcional) mostra a última pergunta capturada
        if ((perguntaDebug ?? '').isNotEmpty)
          Text(
            'Pergunta: $perguntaDebug',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Colors.white70),
          ),
      ],
    );
  }
}

/// ---------- Widget de Câmera para Web (preview + capturar) ----------
class _WebCameraSheet extends StatefulWidget {
  const _WebCameraSheet({super.key});

  @override
  State<_WebCameraSheet> createState() => _WebCameraSheetState();
}

class _WebCameraSheetState extends State<_WebCameraSheet> {
  CameraController? _controller;
  Future<void>? _initFuture;
  List<CameraDescription> _cameras = [];

  @override
  void initState() {
    super.initState();
    _initFuture = _initCamera();
  }

  Future<void> _initCamera() async {
    _cameras = await availableCameras();
    final CameraDescription cam = _cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => _cameras.first,
    );

    _controller = CameraController(
      cam,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    await _controller!.initialize();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    final XFile file = await _controller!.takePicture();
    if (!mounted) return;
    Navigator.of(context).pop<XFile>(file);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _initFuture,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: CircularProgressIndicator(),
            ),
          );
        }
        if (_controller == null || !_controller!.value.isInitialized) {
          return const Center(child: Text('Não foi possível inicializar a câmera.'));
        }

        return Column(
          children: [
            Expanded(child: CameraPreview(_controller!)),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FilledButton(
                    onPressed: _capture,
                    child: const Text('Capturar'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop<XFile>(null),
                    child: const Text('Fechar'),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// ---------- Botão Circular “Faça uma pergunta” / “Escutando” ----------
class _BotaoCircularPerguntar extends StatefulWidget {
  final bool isListening;
  final VoidCallback onTap;
  final String label;
  final double diameter; // responsivo

  const _BotaoCircularPerguntar({
    required this.isListening,
    required this.onTap,
    required this.label,
    required this.diameter,
  });

  @override
  State<_BotaoCircularPerguntar> createState() => _BotaoCircularPerguntarState();
}

class _BotaoCircularPerguntarState extends State<_BotaoCircularPerguntar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
      lowerBound: 0.95,
      upperBound: 1.05,
    );
    if (widget.isListening) _ac.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _BotaoCircularPerguntar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isListening && !_ac.isAnimating) {
      _ac.repeat(reverse: true);
    } else if (!widget.isListening && _ac.isAnimating) {
      _ac.stop();
      _ac.value = 1.0;
    }
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool listening = widget.isListening;
    final double d = widget.diameter;      // diâmetro do botão
    final double iconSize = d * 0.42;      // ícone proporcional
    final double ringSize = d * 1.25;      // anéis levemente maiores

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ScaleTransition(
          scale: _ac,
          child: GestureDetector(
            onTap: widget.onTap,
            child: Container(
              width: d,
              height: d,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: listening ? Colors.redAccent : Colors.orange,
                boxShadow: [
                  BoxShadow(
                    blurRadius: listening ? 18 : 8,
                    spreadRadius: listening ? 2 : 1,
                    offset: const Offset(0, 6),
                    color: Colors.black.withOpacity(0.25),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (listening)
                    SizedBox(
                      width: ringSize,
                      height: ringSize,
                      child: _RotatingRings(baseRadius: d * 0.42),
                    ),
                  Icon(
                    listening ? Icons.mic : Icons.mic_none,
                    color: Colors.white,
                    size: iconSize,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          widget.label, // “Faça uma pergunta” ou “Escutando”
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _RotatingRings extends StatefulWidget {
  final double baseRadius; // raio base proporcional ao botão
  const _RotatingRings({super.key, required this.baseRadius});

  @override
  State<_RotatingRings> createState() => _RotatingRingsState();
}

class _RotatingRingsState extends State<_RotatingRings>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return Transform.rotate(
          angle: _ctrl.value * 6.28318, // 2π
          child: CustomPaint(
            painter: _RingsPainter(baseRadius: widget.baseRadius),
          ),
        );
      },
    );
  }
}

class _RingsPainter extends CustomPainter {
  final double baseRadius;
  _RingsPainter({required this.baseRadius});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radii = [baseRadius, baseRadius * 0.75, baseRadius * 0.5];
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (int i = 0; i < radii.length; i++) {
      paint.color = Colors.white.withOpacity(0.25 + i * 0.15);
      final r = radii[i];
      final rect = Rect.fromCircle(center: center, radius: r);
      canvas.drawArc(rect, 0, 1.6, false, paint);
      canvas.drawArc(rect, 2.6, 1.2, false, paint);
      canvas.drawArc(rect, 4.2, 0.9, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// ----------------- BOTÃO PRÓPRIO (substitui AnimatedButton) -----------------
class PillButton extends StatefulWidget {
  final String label;
  final VoidCallback onPressed;
  final double width;
  final double height;
  final Color color;
  final Color textColor;
  final double fontSize;

  const PillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.width = 150,
    this.height = 40,
    this.color = Colors.blue,
    this.textColor = Colors.white,
    this.fontSize = 13,
  });

  @override
  State<PillButton> createState() => _PillButtonState();
}

class _PillButtonState extends State<PillButton> {
  bool _pressed = false;

  void _setPressed(bool v) => setState(() => _pressed = v);

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(widget.height / 2);

    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapCancel: () => _setPressed(false),
      onTapUp: (_) => _setPressed(false),
      onTap: widget.onPressed,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 80),
        scale: _pressed ? 0.97 : 1.0,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: widget.color,
            borderRadius: radius,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(_pressed ? 0.12 : 0.22),
                offset: const Offset(0, 4),
                blurRadius: _pressed ? 6 : 10,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            widget.label,
            style: TextStyle(
              color: widget.textColor,
              fontSize: widget.fontSize,
              fontWeight: FontWeight.w600,
              height: 1.2,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }
}
