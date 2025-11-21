import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:convert/convert.dart';
import 'package:pointycastle/key_derivators/api.dart';
import 'package:pointycastle/key_derivators/pbkdf2.dart';
import 'package:pointycastle/macs/hmac.dart';
import 'package:pointycastle/digests/sha512.dart';
import 'wordlist.dart';
import 'entropy_source.dart';

/// BIP39 Mnemonic implementation with multiple entropy strategies
class Mnemonic {
  static const int _bitsPerWord = 11;
  
  /// Generate a random mnemonic phrase using system random
  /// 
  /// [wordCount] determines the number of words (12, 15, 18, 21, or 24)
  /// - 12 words = 128 bits entropy
  /// - 15 words = 160 bits entropy
  /// - 18 words = 192 bits entropy
  /// - 21 words = 224 bits entropy
  /// - 24 words = 256 bits entropy
  static String generate({int wordCount = 24}) {
    final bits = EntropySource.bitsFromWordCount(wordCount);
    final entropy = EntropySource.systemRandom(bits);
    return fromEntropy(entropy);
  }

  /// Generate mnemonic from dice rolls
  static String fromDiceRolls(List<int> rolls, {int wordCount = 24}) {
    final bits = EntropySource.bitsFromWordCount(wordCount);
    final minRolls = EntropySource.minDiceRolls(bits);
    
    if (rolls.length < minRolls) {
      throw ArgumentError(
        'Need at least $minRolls dice rolls for $wordCount words (${rolls.length} provided)'
      );
    }
    
    final entropy = EntropySource.fromDiceRolls(rolls, bits);
    return fromEntropy(entropy);
  }

  /// Generate mnemonic from card shuffle
  /// 
  /// [cardSequence] should be a comma-separated list of 52 cards in format [Rank][Suit]
  /// Example: "AS,7D,KC,2H,QH,9C,JD,..."
  static String fromCardShuffle(String cardSequence, {int wordCount = 24}) {
    final bits = EntropySource.bitsFromWordCount(wordCount);
    final entropy = EntropySource.fromCardShuffle(cardSequence, bits);
    return fromEntropy(entropy);
  }

  /// Generate mnemonic from dice and card hybrid
  /// 
  /// [combinedInput] should be in format: "cards|dice"
  /// Example: "AS,7D,KC,2H,QH,9C,JD,...|3,6,2,1,4,5,2,6,3,1,..."
  static String fromDiceAndCard(String combinedInput, {int wordCount = 24}) {
    final bits = EntropySource.bitsFromWordCount(wordCount);
    final entropy = EntropySource.fromDiceAndCard(combinedInput, bits);
    return fromEntropy(entropy);
  }

  /// Create mnemonic from entropy bytes
  static String fromEntropy(Uint8List entropy) {
    if (entropy.length < 16 || entropy.length > 32 || entropy.length % 4 != 0) {
      throw ArgumentError('Entropy length must be 16, 20, 24, 28, or 32 bytes');
    }

    // Calculate checksum
    final hash = sha256.convert(entropy);
    final checksumBits = (entropy.length * 8) ~/ 32;

    // Convert entropy + checksum to binary string
    String bits = '';
    for (final byte in entropy) {
      bits += byte.toRadixString(2).padLeft(8, '0');
    }

    // Add checksum bits
    final checksumByte = hash.bytes[0];
    final checksumBinary = checksumByte.toRadixString(2).padLeft(8, '0');
    bits += checksumBinary.substring(0, checksumBits);

    // Split into 11-bit chunks and convert to words
    final wordlist = BIP39Wordlist.fullEnglishSync;
    final words = <String>[];
    for (int i = 0; i < bits.length; i += _bitsPerWord) {
      final wordBits = bits.substring(i, i + _bitsPerWord);
      final index = int.parse(wordBits, radix: 2);
      words.add(wordlist[index]);
    }

    return words.join(' ');
  }

  /// Validate a mnemonic phrase
  static bool validate(String mnemonic) {
    try {
      final words = mnemonic.trim().toLowerCase().split(RegExp(r'\s+'));
      
      // Check word count
      if (words.length < 12 || words.length > 24 || words.length % 3 != 0) {
        return false;
      }

      // Check all words are in wordlist
      final wordlist = BIP39Wordlist.fullEnglishSync;
      for (final word in words) {
        if (!wordlist.contains(word)) {
          return false;
        }
      }

      // Convert words to binary
      String bits = '';
      for (final word in words) {
        final index = wordlist.indexOf(word);
        bits += index.toRadixString(2).padLeft(_bitsPerWord, '0');
      }

      // Split entropy and checksum
      final checksumBits = words.length ~/ 3;
      final entropyBits = bits.substring(0, bits.length - checksumBits);
      final checksum = bits.substring(bits.length - checksumBits);

      // Convert entropy bits back to bytes
      final entropy = Uint8List(entropyBits.length ~/ 8);
      for (int i = 0; i < entropy.length; i++) {
        final byteBits = entropyBits.substring(i * 8, (i + 1) * 8);
        entropy[i] = int.parse(byteBits, radix: 2);
      }

      // Verify checksum
      final hash = sha256.convert(entropy);
      final expectedChecksum = hash.bytes[0]
          .toRadixString(2)
          .padLeft(8, '0')
          .substring(0, checksumBits);

      return checksum == expectedChecksum;
    } catch (e) {
      return false;
    }
  }

  /// Convert mnemonic to seed (64 bytes)
  /// 
  /// [mnemonic] the mnemonic phrase
  /// [passphrase] optional passphrase for additional security
  static Uint8List toSeed(String mnemonic, {String passphrase = ''}) {
    if (!validate(mnemonic)) {
      throw ArgumentError('Invalid mnemonic');
    }

    // Normalize mnemonic
    final normalizedMnemonic = mnemonic.trim().toLowerCase().split(RegExp(r'\s+')).join(' ');

    // PBKDF2 with HMAC-SHA512
    final pbkdf2 = PBKDF2KeyDerivator(HMac(SHA512Digest(), 128))
      ..init(Pbkdf2Parameters(
        Uint8List.fromList('mnemonic$passphrase'.codeUnits),
        2048, // iterations
        64, // key length
      ));

    return pbkdf2.process(Uint8List.fromList(normalizedMnemonic.codeUnits));
  }

  /// Get word count from entropy length
  static int wordCountFromEntropyLength(int entropyLength) {
    if (entropyLength % 4 != 0) {
      throw ArgumentError('Entropy length must be divisible by 4');
    }
    return ((entropyLength * 8) + (entropyLength * 8 ~/ 32)) ~/ _bitsPerWord;
  }
}

