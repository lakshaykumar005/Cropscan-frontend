import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:onnxruntime/onnxruntime.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;

class OfflineInferenceService {
  static OrtSession? _session;
  static List<String> _classNames = [];
  static bool _isReady = false;

  // ImageNet normalization constants (same as Python backend)
  static const List<double> _mean = [0.485, 0.456, 0.406];
  static const List<double> _std = [0.229, 0.224, 0.225];

  // Treatment dictionary (same as app.py)
  static final Map<String, Map<String, String>> _treatments = {
    "Apple___Apple_scab": {"action": "Apply fungicide (captan or myclobutanil) every 7-10 days. Remove infected leaves.", "severity": "moderate"},
    "Apple___Black_rot": {"action": "Prune dead wood. Apply copper-based fungicide. Remove mummified fruit.", "severity": "high"},
    "Apple___Cedar_apple_rust": {"action": "Apply myclobutanil before symptoms appear. Remove nearby juniper trees.", "severity": "moderate"},
    "Apple___healthy": {"action": "No treatment needed. Continue routine monitoring.", "severity": "none"},
    "Blueberry___healthy": {"action": "No treatment needed. Maintain soil pH 4.5-5.5.", "severity": "none"},
    "Cherry_(including_sour)___Powdery_mildew": {"action": "Apply sulfur spray. Improve air circulation. Avoid overhead irrigation.", "severity": "moderate"},
    "Cherry_(including_sour)___healthy": {"action": "No treatment needed. Monitor for pests.", "severity": "none"},
    "Corn_(maize)___Cercospora_leaf_spot Gray_leaf_spot": {"action": "Apply strobilurin fungicide. Rotate crops. Use resistant hybrids.", "severity": "high"},
    "Corn_(maize)___Common_rust_": {"action": "Apply propiconazole fungicide. Plant resistant varieties.", "severity": "moderate"},
    "Corn_(maize)___Northern_Leaf_Blight": {"action": "Apply azoxystrobin at tasseling. Use certified disease-free seed.", "severity": "high"},
    "Corn_(maize)___healthy": {"action": "No treatment needed. Maintain proper spacing.", "severity": "none"},
    "Grape___Black_rot": {"action": "Apply mancozeb at bud break. Remove mummified berries.", "severity": "high"},
    "Grape___Esca_(Black_Measles)": {"action": "No chemical cure. Remove infected wood. Protect pruning wounds.", "severity": "high"},
    "Grape___Leaf_blight_(Isariopsis_Leaf_Spot)": {"action": "Apply copper fungicide early season. Improve airflow.", "severity": "moderate"},
    "Grape___healthy": {"action": "No treatment needed. Continue standard management.", "severity": "none"},
    "Orange___Haunglongbing_(Citrus_greening)": {"action": "IMMEDIATE: No cure. Remove infected trees. Control psyllid. Notify agriculture dept.", "severity": "critical"},
    "Peach___Bacterial_spot": {"action": "Apply copper bactericide at petal fall, repeat every 14 days.", "severity": "moderate"},
    "Peach___healthy": {"action": "No treatment needed. Standard thinning program sufficient.", "severity": "none"},
    "Pepper,_bell___Bacterial_spot": {"action": "Apply copper hydroxide. Remove infected plants.", "severity": "moderate"},
    "Pepper,_bell___healthy": {"action": "No treatment needed. Monitor for aphids.", "severity": "none"},
    "Potato___Early_blight": {"action": "Apply chlorothalonil fungicide. Remove lower infected leaves.", "severity": "moderate"},
    "Potato___Late_blight": {"action": "URGENT: Apply metalaxyl immediately. Destroy infected plants.", "severity": "critical"},
    "Potato___healthy": {"action": "No treatment needed. Monitor for Colorado potato beetle.", "severity": "none"},
    "Raspberry___healthy": {"action": "No treatment needed. Prune old canes after harvest.", "severity": "none"},
    "Soybean___healthy": {"action": "No treatment needed. Monitor for soybean aphid.", "severity": "none"},
    "Squash___Powdery_mildew": {"action": "Apply potassium bicarbonate or neem oil. Increase plant spacing.", "severity": "moderate"},
    "Strawberry___Leaf_scorch": {"action": "Remove infected leaves. Apply captan fungicide.", "severity": "moderate"},
    "Strawberry___healthy": {"action": "No treatment needed. Renew beds every 3 years.", "severity": "none"},
    "Tomato___Bacterial_spot": {"action": "Apply copper bactericide weekly. Avoid splashing water on leaves.", "severity": "moderate"},
    "Tomato___Early_blight": {"action": "Apply chlorothalonil. Remove lower leaves. Mulch around base.", "severity": "moderate"},
    "Tomato___Late_blight": {"action": "URGENT: Apply metalaxyl immediately. Bag all infected material.", "severity": "critical"},
    "Tomato___Leaf_Mold": {"action": "Reduce humidity below 85%. Apply mancozeb. Prune for airflow.", "severity": "moderate"},
    "Tomato___Septoria_leaf_spot": {"action": "Apply copper fungicide. Remove infected lower leaves.", "severity": "moderate"},
    "Tomato___Spider_mites Two-spotted_spider_mite": {"action": "Apply miticide or neem oil. Increase humidity.", "severity": "moderate"},
    "Tomato___Target_Spot": {"action": "Apply azoxystrobin. Remove infected debris. Rotate crops.", "severity": "moderate"},
    "Tomato___Tomato_Yellow_Leaf_Curl_Virus": {"action": "No cure. Remove plants. Control whitefly with imidacloprid.", "severity": "critical"},
    "Tomato___Tomato_mosaic_virus": {"action": "No cure. Remove plants immediately. Disinfect tools.", "severity": "high"},
    "Tomato___healthy": {"action": "No treatment needed. Continue standard IPM scouting.", "severity": "none"},
  };

  static bool get isReady => _isReady;

  /// Initialize the ONNX model from bundled assets
  static Future<void> initialize() async {
    if (_isReady) return;

    try {
      // Initialize ONNX Runtime environment
      OrtEnv.instance.init();

      // Copy model from assets to filesystem (ONNX Runtime needs a file path)
      final appDir = await getApplicationDocumentsDirectory();
      final modelPath = '${appDir.path}/mobilenetv3_plantdisease.onnx';

      if (!File(modelPath).existsSync()) {
        final data = await rootBundle.load('assets/model/mobilenetv3_plantdisease.onnx');
        await File(modelPath).writeAsBytes(data.buffer.asUint8List());
      }

      // Load class names
      final classJson = await rootBundle.loadString('assets/model/class_names.json');
      final classData = jsonDecode(classJson);
      _classNames = List<String>.from(classData['classes']);

      // Create ONNX session
      final sessionOptions = OrtSessionOptions();
      _session = OrtSession.fromFile(File(modelPath), sessionOptions);

      _isReady = true;
    } catch (e) {
      _isReady = false;
      rethrow;
    }
  }

  /// Run inference on an image file — completely offline
  static Future<Map<String, dynamic>?> predict({
    required XFile imageFile,
    double temperature = 28.0,
    double humidity = 65.0,
    double ndvi = 0.45,
  }) async {
    if (!_isReady || _session == null) return null;

    try {
      // 1. Read and preprocess the image
      final bytes = await imageFile.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return null;

      // CRITICAL: phone photos carry EXIF orientation as a tag, not as rotated
      // pixels. Without this the model sees a sideways/upside-down leaf and
      // confidence collapses. bakeOrientation is a no-op when orientation=1.
      final oriented = img.bakeOrientation(decoded);

      // Match the notebook's val_transform exactly:
      //   T.Resize((224, 224)) -> T.ToTensor() -> T.Normalize(MEAN, STD)
      // PIL.Image.BILINEAR was used at training time. Use `linear` here, not
      // `cubic` — matching the training resampler matters more than visual
      // quality, especially on big downscales (Google images → 224 amplifies
      // any algorithm divergence into a distribution shift the model fails on).
      final resized = img.copyResize(
        oriented,
        width: 224,
        height: 224,
        interpolation: img.Interpolation.linear,
      );

      // Convert to float tensor [1, 3, 224, 224] with ImageNet normalization.
      // rNormalized/gNormalized/bNormalized return 0..1 regardless of bit depth
      // (raw `pixel.r` returns 0..65535 for 16-bit images, breaking normalization).
      final inputData = Float32List(1 * 3 * 224 * 224);
      const plane = 224 * 224;
      for (int y = 0; y < 224; y++) {
        final rowOffset = y * 224;
        for (int x = 0; x < 224; x++) {
          final pixel = resized.getPixel(x, y);
          final idx = rowOffset + x;
          inputData[idx]             = (pixel.rNormalized - _mean[0]) / _std[0];
          inputData[plane + idx]     = (pixel.gNormalized - _mean[1]) / _std[1];
          inputData[2 * plane + idx] = (pixel.bNormalized - _mean[2]) / _std[2];
        }
      }

      // Diagnostic: log image dims and the first 3 normalized pixel values for
      // each channel, so the standalone Python pipeline can be diffed against
      // these numbers when predictions disagree. Goes through debugPrint so it
      // is stripped in release builds.
      assert(() {
        debugPrint('[offline] input ${oriented.width}x${oriented.height} '
            '-> 224x224 (linear)');
        debugPrint('[offline] R[0..2]=${inputData[0].toStringAsFixed(4)},'
            '${inputData[1].toStringAsFixed(4)},${inputData[2].toStringAsFixed(4)} '
            'G[0..2]=${inputData[plane].toStringAsFixed(4)},'
            '${inputData[plane + 1].toStringAsFixed(4)},'
            '${inputData[plane + 2].toStringAsFixed(4)} '
            'B[0..2]=${inputData[2 * plane].toStringAsFixed(4)},'
            '${inputData[2 * plane + 1].toStringAsFixed(4)},'
            '${inputData[2 * plane + 2].toStringAsFixed(4)}');
        return true;
      }());

      // 2. Run ONNX inference
      final inputTensor = OrtValueTensor.createTensorWithDataList(
        inputData,
        [1, 3, 224, 224],
      );
      final inputs = {'leaf_image': inputTensor};
      final runOptions = OrtRunOptions();
      final outputs = _session!.run(runOptions, inputs);

      // 3. Process output logits
      final outputTensor = outputs[0]?.value as List;
      final logits = List<double>.from(outputTensor[0] as List);

      // Softmax
      final maxLogit = logits.reduce(max);
      final exps = logits.map((l) => exp(l - maxLogit)).toList();
      final sumExp = exps.reduce((a, b) => a + b);
      final probs = exps.map((e) => e / sumExp).toList();

      // Prediction
      final predIdx = probs.indexOf(probs.reduce(max));
      final diseaseLabel = _classNames[predIdx];
      final confidence = probs[predIdx];

      // Top 5
      final indices = List.generate(probs.length, (i) => i);
      indices.sort((a, b) => probs[b].compareTo(probs[a]));
      final top5 = indices.take(5).map((i) => {
        "label": _classNames[i].replaceAll('___', ' — ').replaceAll('_', ' '),
        "prob": double.parse((probs[i] * 100).toStringAsFixed(1)),
      }).toList();

      // 4. Compute health metrics (same equations as Python backend)
      final ws = _weatherStress(temperature, humidity);
      final isHealthy = diseaseLabel.toLowerCase().contains('healthy');
      final pd = isHealthy ? (1 - confidence) : confidence;
      final h = _healthScore(pd, ndvi, ws);
      final cafResult = _caf(pd, ndvi, ws, confidence);
      final statusStr = h > 0.6 ? "Healthy" : (h >= 0.3 ? "Moderate Risk" : "High Risk");
      final tx = _treatments[diseaseLabel] ?? {"action": "Consult a local agronomist.", "severity": "unknown"};

      // Release tensors
      inputTensor.release();
      for (final o in outputs) { o?.release(); }
      runOptions.release();

      return {
        "disease_label": diseaseLabel.replaceAll('___', ' — ').replaceAll('_', ' '),
        "confidence": double.parse((confidence * 100).toStringAsFixed(1)),
        "health_score": double.parse((h * 100).toStringAsFixed(1)),
        "health_status": statusStr,
        "weather_stress": double.parse(ws.toStringAsFixed(3)),
        "ndvi_used": double.parse(ndvi.toStringAsFixed(2)),
        "temperature": temperature,
        "humidity": humidity,
        "top5": top5,
        "treatment": tx["action"],
        "severity": tx["severity"],
        "caf": cafResult,
        "is_healthy": isHealthy,
        "demo_mode": false,
        "bg_removal_used": false,
        "bg_method": "none (offline)",
        "pd": double.parse(pd.toStringAsFixed(4)),
        "ws": double.parse(ws.toStringAsFixed(4)),
      };
    } catch (e) {
      return null;
    }
  }

  // ── Paper equations ──────────────────────────────────────
  static double _weatherStress(double temp, double hum) {
    return min(0.6 * (temp - 25).abs() / 25 + 0.4 * (1 - hum / 100), 1.0);
  }

  static double _healthScore(double pd, double vn, double ws) {
    return (0.45 * (1 - pd) + 0.35 * vn + 0.20 * (1 - ws)).clamp(0.0, 1.0);
  }

  static Map<String, dynamic> _caf(double pd, double vn, double ws, double conf) {
    final rc = conf;
    final rn = vn > 0.15 ? vn : 0.1;
    final rw = 1 - ws;
    final tot = rc + rn + rw + 1e-9;
    final w1 = rc / tot;
    final w2 = rn / tot;
    final w3 = rw / tot;
    final h = (w1 * (1 - pd) + w2 * vn + w3 * (1 - ws)).clamp(0.0, 1.0);
    return {
      "H_adaptive": double.parse(h.toStringAsFixed(4)),
      "w1": double.parse(w1.toStringAsFixed(3)),
      "w2": double.parse(w2.toStringAsFixed(3)),
      "w3": double.parse(w3.toStringAsFixed(3)),
      "r_cnn": double.parse(rc.toStringAsFixed(3)),
      "r_ndvi": double.parse(rn.toStringAsFixed(3)),
      "r_weather": double.parse(rw.toStringAsFixed(3)),
    };
  }

  static void dispose() {
    _session?.release();
    OrtEnv.instance.release();
    _isReady = false;
  }
}
