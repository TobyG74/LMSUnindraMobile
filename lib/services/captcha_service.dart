import 'dart:typed_data';
import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class CaptchaService {
  final TextRecognizer _textRecognizer = TextRecognizer();

  Future<String> solveCaptcha(Uint8List imageBytes) async {
    File? tempFile;
    try {
      final processedImage = _preprocessImage(imageBytes);
      
      final tempDir = await getTemporaryDirectory();
      tempFile = File('${tempDir.path}/captcha_temp.png');
      await tempFile.writeAsBytes(processedImage);
      
      final inputImage = InputImage.fromFilePath(tempFile.path);

      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
      final String text = recognizedText.text.trim();

      print('OCR Result: $text');

      final result = _solveArithmetic(text);
      return result.toString();
    } catch (e) {
      print('Error in OCR: $e');
      return '0';
    } finally {
      if (tempFile != null && await tempFile.exists()) {
        await tempFile.delete();
      }
    }
  }

  Uint8List _preprocessImage(Uint8List imageBytes) {
    try {
      img.Image? image = img.decodeImage(imageBytes);
      
      if (image == null) return imageBytes;

      image = img.copyResize(image, width: image.width * 3, height: image.height * 3);

      return Uint8List.fromList(img.encodeJpg(image, quality: 100));
    } catch (e) {
      print('Error preprocessing image: $e');
      return imageBytes;
    }
  }

  int _solveArithmetic(String text) {
    String cleanText = text.replaceAll(RegExp(r'\s+'), '');
    cleanText = cleanText.replaceAll('=', '').replaceAll('?', '');

    print('Clean text: $cleanText');

    final patterns = [
      RegExp(r'(\d+)\+(\d+)'),
      RegExp(r'(\d+)-(\d+)'),
      RegExp(r'(\d+)[x×*](\d+)'),
      RegExp(r'(\d+)[/÷](\d+)'),
    ];

    for (var pattern in patterns) {
      final match = pattern.firstMatch(cleanText);
      if (match != null) {
        final num1 = int.parse(match.group(1)!);
        final num2 = int.parse(match.group(2)!);
        final operator = cleanText.substring(match.start + match.group(1)!.length, match.start + match.group(1)!.length + 1);

        print('Found: $num1 $operator $num2');

        switch (operator) {
          case '+':
            return num1 + num2;
          case '-':
            return num1 - num2;
          case 'x':
          case '×':
          case '*':
            return num1 * num2;
          case '/':
          case '÷':
            return num1 ~/ num2;
        }
      }
    }

    return _alternativeSolve(cleanText);
  }

  int _alternativeSolve(String text) {
    final numbers = RegExp(r'\d+').allMatches(text).map((m) => int.parse(m.group(0)!)).toList();
    
    if (numbers.length < 2) {
      print('Not enough numbers found');
      return 0;
    }

    if (text.contains('+')) {
      return numbers[0] + numbers[1];
    } else if (text.contains('-')) {
      return numbers[0] - numbers[1];
    } else if (text.contains('x') || text.contains('×') || text.contains('*')) {
      return numbers[0] * numbers[1];
    } else if (text.contains('/') || text.contains('÷')) {
      return numbers[0] ~/ numbers[1];
    }

    print('No operator found');
    return 0;
  }

  String solveArithmeticManually(String expression) {
    expression = expression.replaceAll(RegExp(r'\s+'), '');
    expression = expression.replaceAll('=', '').replaceAll('?', '');

    final patterns = [
      RegExp(r'(\d+)\+(\d+)'),
      RegExp(r'(\d+)-(\d+)'),
      RegExp(r'(\d+)[x×*](\d+)'),
      RegExp(r'(\d+)[/÷](\d+)'),
    ];

    for (var pattern in patterns) {
      final match = pattern.firstMatch(expression);
      if (match != null) {
        final num1 = int.parse(match.group(1)!);
        final num2 = int.parse(match.group(2)!);
        final operator = expression.substring(match.start + match.group(1)!.length, match.start + match.group(1)!.length + 1);

        switch (operator) {
          case '+':
            return (num1 + num2).toString();
          case '-':
            return (num1 - num2).toString();
          case 'x':
          case '×':
          case '*':
            return (num1 * num2).toString();
          case '/':
          case '÷':
            return (num1 ~/ num2).toString();
        }
      }
    }

    return '0';
  }

  void dispose() {
    _textRecognizer.close();
  }
}
