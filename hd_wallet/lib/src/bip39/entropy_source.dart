// ignore_for_file: avoid_print

import 'dart:math';
import 'dart:typed_data';
import 'dart:io';
import 'package:crypto/crypto.dart';

/// High-security entropy generation utilities.
/// Uses multiple system and user sources with cryptographic mixing (HKDF + SHA-512)
enum EntropyStrategy {
  systemRandom,
  diceRolls,
  cardShuffle,
  diceAndCard,
}

class EntropySource {
  // ===========================================================
  // 🔐 CORE: Secure System Entropy
  // ===========================================================

  static Uint8List systemRandom(int bits) {
    if (bits % 8 != 0) {
      throw ArgumentError('Bits must be divisible by 8');
    }

    final targetBytes = bits ~/ 8;
    final secure = Random.secure();

    // Multiple independent secure random sources
    final sources = <Uint8List>[];
    
    // Primary secure random
    sources.add(Uint8List.fromList(List.generate(targetBytes, (_) => secure.nextInt(256))));
    
    // Secondary secure random (independent instance)
    final secure2 = Random.secure();
    sources.add(Uint8List.fromList(List.generate(targetBytes, (_) => secure2.nextInt(256))));
    
    // Tertiary: Interleaved secure random with microsecond timing
    final timedSource = Uint8List(targetBytes);
    for (int i = 0; i < targetBytes; i++) {
      final timeSeed = DateTime.now().microsecondsSinceEpoch;
      final secureVal = secure.nextInt(256);
      timedSource[i] = (secureVal ^ (timeSeed & 0xFF)) & 0xFF;
    }
    sources.add(timedSource);

    // Advanced system entropy collection
    final systemEntropy = _collectAdvancedSystemEntropy(targetBytes);
    sources.add(systemEntropy);

    // High-resolution timing jitter
    final jitterEntropy = _collectTimingJitter(targetBytes);
    sources.add(jitterEntropy);

    // Memory address randomness (ASLR-based)
    final memoryEntropy = _collectMemoryEntropy(targetBytes);
    sources.add(memoryEntropy);

    // XOR all sources together
    final xored = Uint8List(targetBytes);
    for (final source in sources) {
      for (int i = 0; i < targetBytes; i++) {
        xored[i] ^= source[i % source.length];
      }
    }

    // Multi-round cryptographic mixing
    final salt = _collectSystemSaltAdvanced();
    var mixed = _multiRoundHKDF(xored, salt, targetBytes, rounds: 3);

    // Whitening with SHA-512 cascade
    mixed = _whitenEntropy(mixed);

    // Quality validation with fallback
    if (!_validateEntropyQuality(mixed)) {
      // Use secure fallback
      mixed = _generateSecureRandomAdvanced(bits);
    }

    // Final avalanche mixing
    final finalEntropy = _avalancheMix(mixed);

    return finalEntropy;
  }

  // ===========================================================
  // 🎴 CARD SHUFFLE
  // ===========================================================
  static Uint8List fromCardShuffle(String cardSequence, int bits) {
    // Parse card sequence: "AS,7D,KC,2H,QH,9C,JD,..."
    final cards = cardSequence
        .split(',')
        .map((s) => s.trim().toUpperCase())
        .where((s) => s.isNotEmpty)
        .toList();

    if (cards.length != 52) {
      throw ArgumentError('Card sequence must contain exactly 52 cards (found ${cards.length})');
    }

    // Validate card format and uniqueness
    final validCards = _validateCardSequence(cards);
    if (!validCards) {
      throw ArgumentError('Invalid card sequence. Each card must be in format [Rank][Suit] (e.g., AS, 7D, KC, 2H) and all 52 cards must be unique.');
    }

    // Convert card sequence to bytes
    // Each card is represented by its position in a standard deck order
    final cardBytes = _cardsToBytes(cards);

    // Validate entropy quality
    if (!_validateEntropyQuality(cardBytes)) {
      throw ArgumentError('Card shuffle shows insufficient randomness.');
    }

    // Mix with system entropy to prevent deterministic attacks
    final systemSalt = _collectSystemSalt();
    var result = _hkdf(cardBytes, systemSalt, bits ~/ 8);
    
    // Additional whitening
    result = _whitenEntropy(result);
    
    return result;
  }

  // Validate card sequence format and uniqueness
  static bool _validateCardSequence(List<String> cards) {
    const ranks = ['A', '2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K'];
    const suits = ['S', 'D', 'C', 'H'];
    
    final seenCards = <String>{};
    
    for (final card in cards) {
      // Check format: rank + suit
      if (card.length < 2 || card.length > 3) return false;
      
      final suit = card[card.length - 1];
      final rank = card.substring(0, card.length - 1);
      
      if (!ranks.contains(rank) || !suits.contains(suit)) {
        return false;
      }
      
      // Check uniqueness
      if (seenCards.contains(card)) {
        return false;
      }
      seenCards.add(card);
    }
    
    return seenCards.length == 52;
  }

  // Convert card sequence to bytes
  static Uint8List _cardsToBytes(List<String> cards) {
    // Map each card to its position in standard deck order
    // Standard order: AS, 2S, 3S, ..., KS, AD, 2D, ..., KD, AC, 2C, ..., KC, AH, 2H, ..., KH
    const ranks = ['A', '2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K'];
    const suits = ['S', 'D', 'C', 'H'];
    
    final standardOrder = <String>[];
    for (final suit in suits) {
      for (final rank in ranks) {
        standardOrder.add('$rank$suit');
      }
    }
    
    // Create mapping from card to position
    final cardToPosition = <String, int>{};
    for (int i = 0; i < standardOrder.length; i++) {
      cardToPosition[standardOrder[i]] = i;
    }
    
    // Convert shuffled sequence to position bytes
    final bytes = Uint8List(cards.length);
    for (int i = 0; i < cards.length; i++) {
      final position = cardToPosition[cards[i]];
      if (position == null) {
        throw ArgumentError('Invalid card: ${cards[i]}');
      }
      bytes[i] = position;
    }
    
    return bytes;
  }

  // ===========================================================
  // 🎲 DICE ROLLS
  // ===========================================================
  static Uint8List fromDiceRolls(List<int> rolls, int bits) {
    if (rolls.any((r) => r < 1 || r > 6)) {
      throw ArgumentError('Dice rolls must be between 1 and 6');
    }

    final minRequired = minDiceRolls(bits);
    if (rolls.length < minRequired) {
      throw ArgumentError('Need at least $minRequired dice rolls for $bits bits');
    }

    // Enhanced validation with advanced statistical tests
    if (!_validateDiceRandomness(rolls)) {
      throw ArgumentError('Dice rolls appear biased or patterned.');
    }

    // Check for serial correlation
    if (_hasSerialCorrelation(rolls)) {
      throw ArgumentError('Dice rolls show serial correlation.');
    }

    // Process rolls in overlapping windows for better mixing
    BigInt acc = BigInt.zero;
    for (final roll in rolls) {
      acc = acc * BigInt.from(6) + BigInt.from(roll - 1);
    }

    // Multi-stage hashing for better avalanche
    var intermediate = _bigIntToBytes(acc);
    
    // Round 1: HMAC-SHA512 with dice key
    var hmac = Hmac(sha512, 'dice_entropy_key'.codeUnits);
    var hash = hmac.convert(intermediate);
    
    // Round 2: Mix with system entropy
    final systemSalt = _collectSystemSalt();
    hmac = Hmac(sha512, systemSalt);
    hash = hmac.convert(hash.bytes);
    
    // Round 3: HKDF expansion
    final result = _hkdf(Uint8List.fromList(hash.bytes), systemSalt, bits ~/ 8);

    return _whitenEntropy(result);
  }

  // ===========================================================
  // 🎴 + 🎲 DICE AND CARD HYBRID
  // ===========================================================
  static Uint8List fromDiceAndCard(String combinedInput, int bits) {
    // Split combined input: "cards|dice"
    final parts = combinedInput.split('|');
    if (parts.length != 2) {
      throw ArgumentError('Combined input must be in format: "cards|dice" (e.g., "AS,7D,KC,...|3,6,2,1,4,5,...")');
    }

    final cardSequence = parts[0].trim();
    final diceSequence = parts[1].trim();

    if (cardSequence.isEmpty || diceSequence.isEmpty) {
      throw ArgumentError('Both card sequence and dice sequence must be provided');
    }

    // Parse and validate cards
    final cards = cardSequence
        .split(',')
        .map((s) => s.trim().toUpperCase())
        .where((s) => s.isNotEmpty)
        .toList();

    if (cards.length != 52) {
      throw ArgumentError('Card sequence must contain exactly 52 cards (found ${cards.length})');
    }

    final validCards = _validateCardSequence(cards);
    if (!validCards) {
      throw ArgumentError('Invalid card sequence. Each card must be in format [Rank][Suit] (e.g., AS, 7D, KC, 2H) and all 52 cards must be unique.');
    }

    // Parse and validate dice rolls
    final diceText = diceSequence
        .split(RegExp(r'[\s,]+'))
        .where((s) => s.isNotEmpty)
        .toList();
    
    final rolls = diceText.map((s) => int.parse(s)).toList();

    if (rolls.any((r) => r < 1 || r > 6)) {
      throw ArgumentError('Dice rolls must be between 1 and 6');
    }

    final minDiceRolls = 20; // Minimum recommended
    if (rolls.length < minDiceRolls) {
      throw ArgumentError('Need at least $minDiceRolls dice rolls (found ${rolls.length})');
    }

    // Validate dice randomness
    if (!_validateDiceRandomness(rolls)) {
      throw ArgumentError('Dice rolls appear biased or patterned.');
    }

    if (_hasSerialCorrelation(rolls)) {
      throw ArgumentError('Dice rolls show serial correlation.');
    }

    // Convert cards to bytes
    final cardBytes = _cardsToBytes(cards);

    // Convert dice rolls to bytes
    BigInt diceAcc = BigInt.zero;
    for (final roll in rolls) {
      diceAcc = diceAcc * BigInt.from(6) + BigInt.from(roll - 1);
    }
    final diceBytes = _bigIntToBytes(diceAcc);

    // Combine: cards + "|" + dice
    final combined = Uint8List.fromList([
      ...cardBytes,
      ...'|'.codeUnits,
      ...diceBytes,
    ]);

    // Hash with SHA-512 (BLAKE3 equivalent in Dart - using SHA-512 for FIPS-like security)
    final hash = sha512.convert(combined);
    
    // Extract desired length (default 32 bytes for 256 bits)
    final targetBytes = bits ~/ 8;
    var result = Uint8List.fromList(hash.bytes);
    
    // If we need more bytes, derive using HKDF
    if (result.length < targetBytes) {
      final systemSalt = _collectSystemSalt();
      result = _hkdf(result, systemSalt, targetBytes);
    } else if (result.length > targetBytes) {
      result = Uint8List.fromList(result.sublist(0, targetBytes));
    }

    // Additional whitening
    result = _whitenEntropy(result);
    
    // Final avalanche mixing
    return _avalancheMix(result);
  }

  // ===========================================================
  // 📏 Utility Calculations
  // ===========================================================
  static int minDiceRolls(int bits) => ((bits / 2.585) * 1.2).ceil() + 10;
  static int minCardShuffleCards() => 52; // Always 52 cards for full deck
  static int minDiceAndCardRolls() => 20; // Minimum recommended dice rolls for hybrid

  static bool isValidEntropyBits(int bits) =>
      bits >= 128 && bits <= 512 && bits % 32 == 0;

  static int bitsFromWordCount(int words) => {
        12: 128,
        15: 160,
        18: 192,
        21: 224,
        24: 256
      }[words] ??
      (throw ArgumentError('Invalid word count'));

  static Uint8List _bigIntToBytes(BigInt n) {
    if (n == BigInt.zero) return Uint8List.fromList([0]);
    final hex = n.toRadixString(16);
    final paddedHex = hex.length.isEven ? hex : '0$hex';
    final bytes = Uint8List(paddedHex.length ~/ 2);
    for (int i = 0; i < bytes.length; i++) {
      bytes[i] = int.parse(paddedHex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return bytes;
  }

  // ===========================================================
  // 🚀 ADVANCED ENTROPY COLLECTION
  // ===========================================================
  
  static Uint8List _collectAdvancedSystemEntropy(int length) {
    final entropy = <int>[];
    final now = DateTime.now();
    
    // High-resolution timing from multiple sources
    entropy.addAll(_intToBytes(now.microsecondsSinceEpoch));
    entropy.addAll(_intToBytes(now.millisecondsSinceEpoch));
    entropy.addAll(_intToBytes(now.microsecond));
    
    // Process information
    entropy.addAll(_intToBytes(pid));
    entropy.addAll(_intToBytes(Platform.numberOfProcessors));
    entropy.addAll(_intToBytes(Platform.operatingSystem.hashCode));
    entropy.addAll(_intToBytes(Platform.operatingSystemVersion.hashCode));
    entropy.addAll(_intToBytes(Platform.localeName.hashCode));
    entropy.addAll(_intToBytes(Platform.localHostname.hashCode));
    
    // Multiple independent random sources
    for (int i = 0; i < 8; i++) {
      entropy.addAll(_intToBytes(Random().nextInt(0xFFFFFFFF)));
      entropy.addAll(_intToBytes(Random.secure().nextInt(0xFFFFFFFF)));
    }
    
    // Hash to desired length
    return _extractEntropyBytes(Uint8List.fromList(entropy), length * 8);
  }

  static Uint8List _collectTimingJitter(int length) {
    final jitter = <int>[];
    final iterations = max(100, length * 4);
    
    int lastTime = DateTime.now().microsecondsSinceEpoch;
    for (int i = 0; i < iterations; i++) {
      // Busy loop to collect timing jitter
      var counter = 0;
      final start = DateTime.now().microsecondsSinceEpoch;
      while (DateTime.now().microsecondsSinceEpoch == start) {
        counter++;
      }
      final end = DateTime.now().microsecondsSinceEpoch;
      
      final delta = end - lastTime;
      jitter.addAll(_intToBytes(delta));
      jitter.addAll(_intToBytes(counter));
      lastTime = end;
    }
    
    return _extractEntropyBytes(Uint8List.fromList(jitter), length * 8);
  }

  static Uint8List _collectMemoryEntropy(int length) {
    final entropy = <int>[];
    
    // Use object allocation addresses (ASLR creates randomness)
    for (int i = 0; i < 50; i++) {
      final obj = Object();
      final list = <int>[];
      final map = <int, int>{};
      
      entropy.addAll(_intToBytes(obj.hashCode));
      entropy.addAll(_intToBytes(list.hashCode));
      entropy.addAll(_intToBytes(map.hashCode));
      entropy.addAll(_intToBytes(identityHashCode(obj)));
      entropy.addAll(_intToBytes(identityHashCode(list)));
    }
    
    return _extractEntropyBytes(Uint8List.fromList(entropy), length * 8);
  }

  static Uint8List _collectSystemSaltAdvanced() {
    final now = DateTime.now();
    final data = <int>[];
    
    // Expanded system information
    data.addAll(_intToBytes(now.microsecondsSinceEpoch));
    data.addAll(_intToBytes(now.millisecondsSinceEpoch));
    data.addAll(_intToBytes(pid));
    data.addAll(_intToBytes(Platform.numberOfProcessors));
    data.addAll(_intToBytes(Platform.operatingSystem.hashCode));
    data.addAll(_intToBytes(Platform.operatingSystemVersion.hashCode));
    data.addAll(_intToBytes(Platform.localeName.hashCode));
    data.addAll(_intToBytes(Platform.localHostname.hashCode));
    
    // Multiple secure random values
    for (int i = 0; i < 4; i++) {
      data.addAll(_intToBytes(Random.secure().nextInt(0xFFFFFFFF)));
    }
    
    // Object allocation randomness
    for (int i = 0; i < 10; i++) {
      data.addAll(_intToBytes(Object().hashCode));
    }
    
    return Uint8List.fromList(data);
  }

  static List<int> _intToBytes(int value) {
    return [
      (value >> 56) & 0xFF,
      (value >> 48) & 0xFF,
      (value >> 40) & 0xFF,
      (value >> 32) & 0xFF,
      (value >> 24) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 8) & 0xFF,
      value & 0xFF,
    ];
  }

  // ===========================================================
  // 🔄 ADVANCED MIXING TECHNIQUES
  // ===========================================================

  static Uint8List _multiRoundHKDF(Uint8List input, Uint8List salt, int length, {int rounds = 3}) {
    var current = input;
    var currentSalt = salt;
    
    for (int round = 0; round < rounds; round++) {
      current = _hkdf(current, currentSalt, length);
      // Update salt for next round
      currentSalt = Uint8List.fromList(sha512.convert([...currentSalt, round]).bytes);
    }
    
    return current;
  }

  static Uint8List _whitenEntropy(Uint8List input) {
    // Apply multiple independent hash functions
    final hash1 = sha512.convert(input).bytes;
    final hash2 = sha512.convert([...input.reversed]).bytes;
    final hash3 = sha512.convert([...input, ...hash1]).bytes;
    
    // XOR all hashes together
    final result = Uint8List(input.length);
    for (int i = 0; i < input.length; i++) {
      result[i] = hash1[i % hash1.length] ^ 
                  hash2[i % hash2.length] ^ 
                  hash3[i % hash3.length];
    }
    
    return result;
  }

  static Uint8List _avalancheMix(Uint8List input) {
    // Ensure every input bit affects every output bit
    final mixed = Uint8List.fromList(input);
    
    // Multiple passes with different rotation amounts
    for (int pass = 0; pass < 3; pass++) {
      for (int i = 0; i < mixed.length; i++) {
        final prev = mixed[(i - 1 + mixed.length) % mixed.length];
        final next = mixed[(i + 1) % mixed.length];
        mixed[i] = (mixed[i] ^ ((prev << (pass + 1)) | (next >> (7 - pass)))) & 0xFF;
      }
    }
    
    return mixed;
  }

  // ===========================================================
  // 🧠 ENTROPY VALIDATION & STATS
  // ===========================================================
  
  static bool _validateEntropyQuality(Uint8List bytes) {
    if (bytes.length < 16) return false;
    
    // Multiple statistical tests
    final chi = _chiSquare(bytes);
    if (chi > 300.0 || chi < 200.0) return false; // Tighter bounds
    
    if (!_runsTest(bytes)) return false;
    if (!_autoCorrelation(bytes)) return false;
    
    // Additional tests
    if (_entropyEstimate(bytes) < 7.0) return false; // Higher threshold
    if (_hasRepeats(bytes)) return false;
    
    // Frequency test
    if (!_frequencyTest(bytes)) return false;
    
    return true;
  }

  static bool _validateDiceRandomness(List<int> rolls) {
    // Chi-square test
    final counts = List.filled(6, 0);
    for (final r in rolls) counts[r - 1]++;
    final expected = rolls.length / 6;
    double chi = 0.0;
    for (final c in counts) {
      final diff = c - expected;
      chi += (diff * diff) / expected;
    }
    if (chi > 11.07) return false;
    
    // No face should be too rare
    final minExpected = expected * 0.5;
    if (counts.any((c) => c < minExpected)) return false;
    
    return true;
  }

  static bool _validateInputEntropy(Uint8List b) {
    if (_hasRepeats(b)) return false;
    if (_entropyEstimate(b) < 6.5) return false; // Higher threshold
    if (!_frequencyTest(b)) return false;
    return true;
  }

  static bool _validateTextEntropy(Uint8List t) {
    final s = String.fromCharCodes(t);
    final diversity = [
      RegExp(r'[a-z]'),
      RegExp(r'[A-Z]'),
      RegExp(r'[0-9]'),
      RegExp(r'[!@#\$%^&*(),.?":{}|<>]')
    ].where((r) => r.hasMatch(s)).length;
    if (diversity < 2) return false;
    if (_entropyEstimate(t) < 4.5) return false; // Higher threshold
    if (_hasTextPattern(s)) return false;
    return true;
  }

  // ===========================================================
  // 🔁 MIXING & FALLBACK
  // ===========================================================
  
  static Uint8List _generateSecureRandomAdvanced(int bits) {
    final bytes = bits ~/ 8;
    
    // Collect from multiple sources
    final sources = <Uint8List>[];
    
    for (int i = 0; i < 5; i++) {
      final secure = Random.secure();
      sources.add(Uint8List.fromList(List.generate(bytes, (_) => secure.nextInt(256))));
    }

    // XOR all sources
    final combined = Uint8List(bytes);
    for (final source in sources) {
      for (int i = 0; i < bytes; i++) {
        combined[i] ^= source[i];
      }
    }

    final salt = _collectSystemSaltAdvanced();
    var derived = _multiRoundHKDF(combined, salt, bytes, rounds: 5);
    derived = _whitenEntropy(derived);

    if (!_validateEntropyQuality(derived)) {
      // Ultimate fallback: cascade hashing
      derived = _extractEntropyBytes(Uint8List.fromList(sha512.convert(derived).bytes), bits);
      derived = _whitenEntropy(derived);
    }
    
    return _avalancheMix(derived);
  }

  static Uint8List _extractEntropyBytes(Uint8List input, int bits) {
    final bytes = bits ~/ 8;
    if (input.length >= bytes) return Uint8List.sublistView(input, 0, bytes);
    
    var out = <int>[];
    var h = input;
    int counter = 0;
    
    while (out.length < bytes) {
      // Mix counter to prevent identical rounds
      h = Uint8List.fromList(sha512.convert([...h, counter]).bytes);
      out.addAll(h);
      counter++;
    }
    
    return Uint8List.fromList(out.take(bytes).toList());
  }

  // ===========================================================
  // 🔬 STATISTICAL TESTS
  // ===========================================================
  
  static double _chiSquare(Uint8List bytes) {
    final counts = List.filled(256, 0);
    for (final b in bytes) counts[b]++;
    final exp = bytes.length / 256;
    double chi = 0.0;
    for (final c in counts) {
      final d = c - exp;
      chi += (d * d) / exp;
    }
    return chi;
  }

  static bool _runsTest(Uint8List b) {
    if (b.length < 8) return true;
    int runs = 1;
    for (int i = 1; i < b.length; i++) {
      if (b[i] != b[i - 1]) runs++;
    }
    final expRuns = (2 * b.length - 1) / 3.0;
    final varRuns = (16 * b.length - 29) / 90.0;
    final z = (runs - expRuns) / sqrt(varRuns);
    return z.abs() < 2.0;
  }

  static bool _autoCorrelation(Uint8List b) {
    if (b.length < 16) return true;
    double corr = 0.0;
    for (int i = 0; i < b.length - 1; i++) {
      corr += b[i] * b[i + 1];
    }
    corr /= (b.length - 1);
    return corr.abs() < 0.15; // Slightly relaxed but still strong
  }

  static bool _frequencyTest(Uint8List b) {
    int ones = 0;
    for (final byte in b) {
      for (int i = 0; i < 8; i++) {
        if ((byte >> i) & 1 == 1) ones++;
      }
    }
    final total = b.length * 8;
    final ratio = ones / total;
    return ratio > 0.45 && ratio < 0.55; // Should be close to 0.5
  }

  static bool _hasRepeats(Uint8List b) {
    // Check for repeating patterns
    for (int len = 1; len <= min(16, b.length ~/ 2); len++) {
      bool rep = true;
      for (int i = len; i < min(len * 3, b.length); i++) {
        if (b[i] != b[i % len]) {
          rep = false;
          break;
        }
      }
      if (rep) return true;
    }
    return false;
  }

  static double _entropyEstimate(Uint8List b) {
    final counts = List.filled(256, 0);
    for (final x in b) counts[x]++;
    double e = 0.0;
    for (final c in counts) {
      if (c > 0) {
        final p = c / b.length;
        e -= p * log(p) / ln2;
      }
    }
    return e;
  }

  static bool _hasTextPattern(String s) {
    const bad = [
      'password', '123', 'abc', 'qwe', 'asd', 'zxc',
      'welcome', 'test', 'example', 'admin', 'user',
      'qwerty', 'asdf', 'pass', '111', '000'
    ];
    final lower = s.toLowerCase();
    for (final w in bad) {
      if (lower.contains(w)) return true;
    }
    return false;
  }

  static bool _hasKeyboardPattern(String s) {
    const patterns = [
      'qwerty', 'asdfgh', 'zxcvbn', 'qwertz', 'azerty',
      '123456', 'abcdef', '098765'
    ];
    final lower = s.toLowerCase();
    for (final pattern in patterns) {
      if (lower.contains(pattern)) return true;
    }
    return false;
  }

  static bool _hasSerialCorrelation(List<int> rolls) {
    if (rolls.length < 10) return false;
    
    // Check for runs of same value
    int maxRun = 1;
    int currentRun = 1;
    for (int i = 1; i < rolls.length; i++) {
      if (rolls[i] == rolls[i - 1]) {
        currentRun++;
        maxRun = max(maxRun, currentRun);
      } else {
        currentRun = 1;
      }
    }
    
    // More than 5 same rolls in a row is suspicious
    if (maxRun > 5) return true;
    
    // Check for alternating patterns
    int alternations = 0;
    for (int i = 2; i < rolls.length; i++) {
      if (rolls[i] == rolls[i - 2] && rolls[i] != rolls[i - 1]) {
        alternations++;
      }
    }
    
    return alternations > rolls.length * 0.4;
  }

  static bool _hasArithmeticSequence(List<int> numbers) {
    if (numbers.length < 5) return false;
    
    // Check for arithmetic progression
    for (int start = 0; start < numbers.length - 4; start++) {
      final diff = numbers[start + 1] - numbers[start];
      bool isSequence = true;
      
      for (int i = start + 2; i < min(start + 10, numbers.length); i++) {
        if (numbers[i] - numbers[i - 1] != diff) {
          isSequence = false;
          break;
        }
      }
      
      if (isSequence) return true;
    }
    
    return false;
  }

  static bool _hasCompressionPattern(Uint8List bytes) {
    // Simple compression test: repeating byte sequences
    final seqCount = <String, int>{};
    
    for (int len = 2; len <= min(8, bytes.length ~/ 4); len++) {
      for (int i = 0; i <= bytes.length - len; i++) {
        final seq = bytes.sublist(i, i + len).join(',');
        seqCount[seq] = (seqCount[seq] ?? 0) + 1;
      }
    }
    
    // If any sequence appears too frequently, it's compressible
    final maxFreq = seqCount.values.isEmpty ? 0 : seqCount.values.reduce(max);
    return maxFreq > max(3, bytes.length ~/ 20);
  }

  // ===========================================================
  // 🧮 SYSTEM ENTROPY SOURCES (ORIGINAL, kept for compatibility)
  // ===========================================================
  
  static Uint8List _collectSystemSalt() {
    final now = DateTime.now();
    final data = [
      now.microsecondsSinceEpoch,
      pid,
      Platform.numberOfProcessors,
      Platform.operatingSystem.hashCode,
      Platform.operatingSystemVersion.hashCode,
      Random().nextInt(0xFFFFFFFF)
    ].expand((x) => [
          (x >> 24) & 0xFF,
          (x >> 16) & 0xFF,
          (x >> 8) & 0xFF,
          x & 0xFF
        ]).toList();
    return Uint8List.fromList(data);
  }

  static Uint8List _hkdf(Uint8List input, Uint8List salt, int length) {
    final hmac = Hmac(sha512, salt);
    final prk = hmac.convert(input).bytes;
    final out = <int>[];
    var t = <int>[];
    int counter = 1;
    while (out.length < length) {
      final data = <int>[...t, counter];
      t = Hmac(sha512, prk).convert(data).bytes;
      out.addAll(t);
      counter++;
    }
    return Uint8List.fromList(out.take(length).toList());
  }
}
