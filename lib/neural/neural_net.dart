import 'dart:math';

/// Простая полносвязная нейросеть на чистом Dart.
/// Поддерживает прямой проход и обучение методом обратного распространения.
class NeuralNet {
  NeuralNet({
    required this.inputSize,
    required this.hiddenSizes,
    required this.outputSize,
    List<List<List<double>>>? weights,
    List<List<double>>? biases,
  })  : _weights = weights ?? _initWeights(inputSize, hiddenSizes, outputSize),
        _biases = biases ?? _initBiases(hiddenSizes, outputSize);

  final int inputSize;
  final List<int> hiddenSizes;
  final int outputSize;
  final List<List<List<double>>> _weights;
  final List<List<double>> _biases;

  static List<List<List<double>>> _initWeights(
    int inputSize,
    List<int> hiddenSizes,
    int outputSize,
  ) {
    final r = Random(42);
    double initScale(int inSz, int outSz) =>
        2 * sqrt(2.0 / (inSz + outSz));

    final result = <List<List<double>>>[];
    int prev = inputSize;
    for (final h in hiddenSizes) {
      final scale = initScale(prev, h);
      result.add(List.generate(
        h,
        (_) => List.generate(prev, (_) => (r.nextDouble() - 0.5) * scale),
      ));
      prev = h;
    }
    final scale = initScale(prev, outputSize);
    result.add(List.generate(
      outputSize,
      (_) => List.generate(prev, (_) => (r.nextDouble() - 0.5) * scale),
    ));
    return result;
  }

  static List<List<double>> _initBiases(List<int> hiddenSizes, int outputSize) {
    final r = Random(42);
    return [
      ...hiddenSizes.map((h) => List.generate(h, (_) => 0.01 * (r.nextDouble() - 0.5))),
      List.generate(outputSize, (_) => 0.01 * (r.nextDouble() - 0.5)),
    ];
  }

  /// Умножение матрицы на вектор: out = W * x
  static List<double> _matVec(List<List<double>> w, List<double> x) {
    return List.generate(w.length, (i) {
      var sum = 0.0;
      for (var j = 0; j < x.length; j++) {
        sum += w[i][j] * x[j];
      }
      return sum;
    });
  }

  /// Прямой проход. Возвращает вектор выходов (sigmoid на последнем слое).
  List<double> forward(List<double> input) {
    if (input.length != inputSize) {
      throw ArgumentError('Expected $inputSize inputs, got ${input.length}');
    }
    var x = List<double>.from(input);

    for (var i = 0; i < _weights.length; i++) {
      x = _matVec(_weights[i], x);
      for (var j = 0; j < x.length; j++) {
        x[j] += _biases[i][j];
      }
      if (i < _weights.length - 1) {
        for (var j = 0; j < x.length; j++) {
          x[j] = x[j] > 0 ? x[j] : 0;
        }
      } else {
        for (var j = 0; j < x.length; j++) {
          final v = x[j].clamp(-20.0, 20.0);
          x[j] = 1 / (1 + exp(-v));
        }
      }
    }
    return x;
  }

  /// Обучение на одном примере. Возвращает MSE.
  double trainStep(List<double> input, List<double> target, double lr) {
    if (target.length != outputSize) {
      throw ArgumentError('Expected $outputSize targets, got ${target.length}');
    }

    final layers = <List<double>>[];
    final preActivations = <List<double>>[];

    var x = List<double>.from(input);
    layers.add(x);

    for (var i = 0; i < _weights.length; i++) {
      x = _matVec(_weights[i], x);
      for (var j = 0; j < x.length; j++) {
        x[j] += _biases[i][j];
      }
      preActivations.add(List.from(x));
      if (i < _weights.length - 1) {
        for (var j = 0; j < x.length; j++) {
          x[j] = x[j] > 0 ? x[j] : 0;
        }
      } else {
        for (var j = 0; j < x.length; j++) {
          final v = x[j].clamp(-20.0, 20.0);
          x[j] = 1 / (1 + exp(-v));
        }
      }
      layers.add(List.from(x));
    }

    final output = layers.last;
    var grad = List<double>.generate(outputSize, (i) => 2 * (output[i] - target[i]));

    for (var i = _weights.length - 1; i >= 0; i--) {
      final pa = preActivations[i];
      final inp = layers[i];

      if (i == _weights.length - 1) {
        for (var j = 0; j < grad.length; j++) {
          final s = 1 / (1 + exp(-pa[j].clamp(-20.0, 20.0)));
          grad[j] *= s * (1 - s);
        }
      } else {
        for (var j = 0; j < grad.length; j++) {
          grad[j] *= pa[j] > 0 ? 1.0 : 0.0;
        }
      }

      for (var row = 0; row < _weights[i].length; row++) {
        for (var col = 0; col < _weights[i][row].length; col++) {
          _weights[i][row][col] -= lr * grad[row] * inp[col];
        }
        _biases[i][row] -= lr * grad[row];
      }

      if (i > 0) {
        final newGrad = List<double>.filled(inp.length, 0);
        for (var col = 0; col < inp.length; col++) {
          for (var row = 0; row < grad.length; row++) {
            newGrad[col] += _weights[i][row][col] * grad[row];
          }
        }
        grad = newGrad;
      }
    }

    var err = 0.0;
    for (var i = 0; i < output.length; i++) {
      final d = output[i] - target[i];
      err += d * d;
    }
    return err;
  }

  /// Сериализация весов для сохранения.
  Map<String, dynamic> toJson() {
    return {
      'inputSize': inputSize,
      'hiddenSizes': hiddenSizes,
      'outputSize': outputSize,
      'weights': _weights,
      'biases': _biases,
    };
  }

  /// Загрузка весов из JSON.
  static NeuralNet fromJson(Map<String, dynamic> json) {
    final inputSize = json['inputSize'] as int;
    final hiddenSizes = (json['hiddenSizes'] as List<dynamic>).cast<int>();
    final outputSize = json['outputSize'] as int;
    final weights = (json['weights'] as List<dynamic>)
        .map((w) => (w as List<dynamic>)
            .map((r) => (r as List<dynamic>).cast<double>())
            .toList())
        .toList();
    final biases = (json['biases'] as List<dynamic>)
        .map((b) => (b as List<dynamic>).cast<double>())
        .toList();

    return NeuralNet(
      inputSize: inputSize,
      hiddenSizes: hiddenSizes,
      outputSize: outputSize,
      weights: weights,
      biases: biases,
    );
  }
}
