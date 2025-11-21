import '../common/enums.dart';

class SavedWallet {
  final String id;
  final String name;
  final String address;
  final String publicKey;
  final String encryptedMnemonic;
  final String? encryptedPassphrase;
  final WalletProvider walletProvider;
  final String? avatarEmoji;
  final DateTime createdAt;

  SavedWallet({
    required this.id,
    required this.name,
    required this.address,
    required this.publicKey,
    required this.encryptedMnemonic,
    this.encryptedPassphrase,
    required this.walletProvider,
    this.avatarEmoji,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'address': address,
        'publicKey': publicKey,
        'encryptedMnemonic': encryptedMnemonic,
        'encryptedPassphrase': encryptedPassphrase,
        'walletProvider': walletProvider.name,
        'avatarEmoji': avatarEmoji,
        'createdAt': createdAt.toIso8601String(),
      };

  factory SavedWallet.fromJson(Map<String, dynamic> json) => SavedWallet(
        id: json['id'] as String,
        name: json['name'] as String,
        address: json['address'] as String,
        publicKey: json['publicKey'] as String,
        encryptedMnemonic: json['encryptedMnemonic'] as String,
        encryptedPassphrase: json['encryptedPassphrase'] as String?,
        walletProvider: WalletProvider.values.firstWhere(
          (p) => p.name == json['walletProvider'],
          orElse: () => WalletProvider.kasware, // Default for backward compatibility
        ),
        avatarEmoji: json['avatarEmoji'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

