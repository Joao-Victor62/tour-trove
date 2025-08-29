import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:animated_button/animated_button.dart';
import 'package:http/http.dart' as http;

import 'package:image_picker/image_picker.dart'; // Android/iOS
import 'package:camera/camera.dart';             // Web (e mobile, se quiser)

/// ====== CONFIGURE AQUI ======
const String kCustomVisionUrl = 'https://SEU-ENDPOINT/customvision/v3.0/Prediction/PROJECT_ID/classify/iterations/ITERATION_NAME/image';
const String kPredictionKey   = 'SUA_PREDICTION_KEY_AQUI';
const String kDescricaoApiBase = 'http://localhost:6790/exposicao/nome?nome=';
/// ====== FIM CONFIG ======

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ImagePicker _picker = ImagePicker();

  String? nomeExposicao;
  String? descricaoExposicao;
  bool loading = false;

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

      // 2) Enviar pro Custom Vision
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
      final double prob   = ((top['probability'] ?? 0.0) as num).toDouble();

      if (prob < 0.7) {
        _snack('Confiança baixa (${(prob * 100).toStringAsFixed(1)}%). Tente outra foto.');
        setState(() => loading = false);
        return;
      }

      // 3) Buscar descrição na sua API
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Fundo + resultado
          Container(
            color: Colors.green,
            alignment: Alignment.center,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _ResultadoExposicao(
                nome: nomeExposicao,
                descricao: descricaoExposicao,
              ),
            ),
          ),

          // Botão "Identificar"
          Positioned(
            left: 0,
            right: 0,
            bottom: 120,
            child: Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(25),
                child: AnimatedButton(
                  color: Colors.blue,
                  shadowDegree: ShadowDegree.light,
                  onPressed: identificar_expsoicao,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Text(
                      'Identificar',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
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

  /// Abre um modal com preview da câmera (Web) e retorna um XFile com a foto.
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
}

class _ResultadoExposicao extends StatelessWidget {
  final String? nome;
  final String? descricao;
  const _ResultadoExposicao({required this.nome, required this.descricao});

  @override
  Widget build(BuildContext context) {
    final hasData = (nome != null && nome!.isNotEmpty) || (descricao != null && descricao!.isNotEmpty);
    if (!hasData) {
      return const Text(
        "Página principal",
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 20, color: Colors.white),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          nome ?? '',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white),
        ),
        const SizedBox(height: 12),
        Text(
          descricao ?? '',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, color: Colors.white, height: 1.3),
        ),
      ],
    );
  }
}

/// ---------- Widget de Câmera para Web ----------
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
          return const Center(child: Padding(
            padding: EdgeInsets.all(24.0),
            child: CircularProgressIndicator(),
          ));
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
