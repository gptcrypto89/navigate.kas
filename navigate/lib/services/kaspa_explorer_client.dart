import 'dart:convert';
import 'package:http/http.dart' as http;
import '../common/config.dart';

/// Client for interacting with the Kaspa Explorer API
class KaspaExplorerClient {
  final String baseUrl;

  KaspaExplorerClient({this.baseUrl = AppConfig.kaspaExplorerApiUrl});

  /// Get transaction details from the Kaspa blockchain
  Future<KaspaTransaction?> getTransaction(String transactionId) async {
    try {
      print('Kaspa Explorer: Fetching transaction: $transactionId');
      
      final url = Uri.parse('$baseUrl/transactions/$transactionId');

      final response = await http.get(url).timeout(
        const Duration(seconds: AppConfig.kaspaExplorerTimeoutSeconds),
      );

      print('Kaspa Explorer Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return KaspaTransaction.fromMap(data);
      } else if (response.statusCode == 404) {
        print('Kaspa Explorer: Transaction not found');
        return null;
      } else {
        throw Exception('HTTP Error ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('Kaspa Explorer Error: $e');
      if (e.toString().contains('Connection') || 
          e.toString().contains('Failed host lookup')) {
        throw Exception('Cannot connect to Kaspa Explorer API. Please check your internet connection.');
      }
      rethrow;
    }
  }

  /// Verify that a transaction exists and is confirmed on the Kaspa blockchain
  Future<bool> verifyTransaction(String transactionId) async {
    try {
      final transaction = await getTransaction(transactionId);
      
      if (transaction == null) {
        print('Kaspa Explorer: Transaction not found - verification failed');
        return false;
      }

      // Check if transaction is accepted
      final isVerified = transaction.isAccepted;
      print('Kaspa Explorer: Transaction verified: $isVerified');
      
      return isVerified;
    } catch (e) {
      print('Kaspa Explorer: Error verifying transaction: $e');
      return false;
    }
  }

  /// Get balance for an address
  /// API: GET /addresses/{address}/balance
  Future<AddressBalance?> getAddressBalance(String address) async {
    try {
      print('Kaspa Explorer: Fetching balance for address: $address');
      
      final url = Uri.parse('$baseUrl/addresses/$address/balance');

      final response = await http.get(url).timeout(
        const Duration(seconds: AppConfig.kaspaExplorerTimeoutSeconds),
      );

      print('Kaspa Explorer Balance Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return AddressBalance.fromMap(data);
      } else if (response.statusCode == 404) {
        print('Kaspa Explorer: Address not found');
        return null;
      } else {
        throw Exception('HTTP Error ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('Kaspa Explorer Balance Error: $e');
      if (e.toString().contains('Connection') || 
          e.toString().contains('Failed host lookup')) {
        throw Exception('Cannot connect to Kaspa Explorer API. Please check your internet connection.');
      }
      rethrow;
    }
  }

  /// Get full transactions for an address with pagination
  /// API: GET /addresses/{address}/full-transactions?limit={limit}&offset={offset}
  Future<List<KaspaFullTransaction>> getAddressTransactions(
    String address, {
    int limit = AppConfig.kaspaExplorerDefaultLimit,
    int offset = 0,
  }) async {
    try {
      print('Kaspa Explorer: Fetching transactions for address: $address (limit: $limit, offset: $offset)');
      
      final url = Uri.parse('$baseUrl/addresses/$address/full-transactions')
          .replace(queryParameters: {
        'limit': limit.toString(),
        'offset': offset.toString(),
      });

      final response = await http.get(url).timeout(
        const Duration(seconds: AppConfig.kaspaExplorerTimeoutSeconds),
      );

      print('Kaspa Explorer Transactions Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List<dynamic>;
        return data.map((item) => KaspaFullTransaction.fromMap(item as Map<String, dynamic>)).toList();
      } else if (response.statusCode == 404) {
        print('Kaspa Explorer: Address not found');
        return [];
      } else {
        throw Exception('HTTP Error ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('Kaspa Explorer Transactions Error: $e');
      if (e.toString().contains('Connection') || 
          e.toString().contains('Failed host lookup')) {
        throw Exception('Cannot connect to Kaspa Explorer API. Please check your internet connection.');
      }
      rethrow;
    }
  }

  /// Find the transaction that spends a specific output (UTXO)
  /// Returns null if the output is unspent
  Future<KaspaFullTransaction?> findSpendingTransaction(
    String txId,
    int outputIndex,
    String ownerAddress,
  ) async {
    try {
      print('Kaspa Explorer: Finding transaction spending $txId:$outputIndex');
      
      // Get all transactions for the owner address
      // We need to find a transaction that has an input referencing our output
      final transactions = await getAddressTransactions(ownerAddress, limit: 100);
      
      for (final tx in transactions) {
        for (final input in tx.inputs) {
          if (input.previousOutpointHash == txId && 
              input.previousOutpointIndex == outputIndex.toString()) {
            print('Kaspa Explorer: Found spending transaction: ${tx.transactionId}');
            return tx;
          }
        }
      }
      
      print('Kaspa Explorer: Output $txId:$outputIndex is unspent');
      return null;
    } catch (e) {
      print('Kaspa Explorer: Error finding spending transaction: $e');
      return null;
    }
  }

  /// Extract signer addresses from a transaction's inputs
  /// Returns the list of addresses that signed this transaction
  Future<List<String>> extractSignerAddresses(KaspaFullTransaction tx) async {
    final signerAddresses = <String>{};
    
    try {
      print('Kaspa Explorer: Extracting signer addresses from tx: ${tx.transactionId}');
      
      for (final input in tx.inputs) {
        // If the previous outpoint address is cached in the input, use it
        if (input.previousOutpointAddress != null && input.previousOutpointAddress!.isNotEmpty) {
          signerAddresses.add(input.previousOutpointAddress!);
          continue;
        }
        
        // Otherwise, fetch the previous transaction to get the output address
        final prevTx = await getFullTransaction(input.previousOutpointHash);
        if (prevTx != null) {
          final outputIndex = int.tryParse(input.previousOutpointIndex) ?? 0;
          if (outputIndex < prevTx.outputs.length) {
            final output = prevTx.outputs[outputIndex];
            if (output.scriptPublicKeyAddress.isNotEmpty) {
              signerAddresses.add(output.scriptPublicKeyAddress);
            }
          }
        }
      }
      
      print('Kaspa Explorer: Extracted ${signerAddresses.length} signer addresses');
      return signerAddresses.toList();
    } catch (e) {
      print('Kaspa Explorer: Error extracting signer addresses: $e');
      return signerAddresses.toList();
    }
  }

  /// Get full transaction details with inputs and outputs
  Future<KaspaFullTransaction?> getFullTransaction(String transactionId) async {
    try {
      print('Kaspa Explorer: Fetching full transaction: $transactionId');
      
      final url = Uri.parse('$baseUrl/transactions/$transactionId');

      final response = await http.get(url).timeout(
        const Duration(seconds: AppConfig.kaspaExplorerTimeoutSeconds),
      );

      print('Kaspa Explorer Full Transaction Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return KaspaFullTransaction.fromMap(data);
      } else if (response.statusCode == 404) {
        print('Kaspa Explorer: Transaction not found');
        return null;
      } else {
        throw Exception('HTTP Error ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('Kaspa Explorer: Error fetching full transaction: $e');
      return null;
    }
  }
}

/// Represents a transaction on the Kaspa blockchain
class KaspaTransaction {
  final String transactionId;
  final String hash;
  final bool isAccepted;
  final String? acceptingBlockHash;
  final int? acceptingBlockBlueScore;
  final int? acceptingBlockTime;
  final int blockTime;
  final List<String> blockHash;

  KaspaTransaction({
    required this.transactionId,
    required this.hash,
    required this.isAccepted,
    this.acceptingBlockHash,
    this.acceptingBlockBlueScore,
    this.acceptingBlockTime,
    required this.blockTime,
    required this.blockHash,
  });

  factory KaspaTransaction.fromMap(Map<String, dynamic> map) {
    return KaspaTransaction(
      transactionId: map['transaction_id'] as String? ?? '',
      hash: map['hash'] as String? ?? '',
      isAccepted: map['is_accepted'] as bool? ?? false,
      acceptingBlockHash: map['accepting_block_hash'] as String?,
      acceptingBlockBlueScore: map['accepting_block_blue_score'] as int?,
      acceptingBlockTime: map['accepting_block_time'] as int?,
      blockTime: map['block_time'] as int? ?? 0,
      blockHash: (map['block_hash'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'transaction_id': transactionId,
      'hash': hash,
      'is_accepted': isAccepted,
      'accepting_block_hash': acceptingBlockHash,
      'accepting_block_blue_score': acceptingBlockBlueScore,
      'accepting_block_time': acceptingBlockTime,
      'block_time': blockTime,
      'block_hash': blockHash,
    };
  }

  bool get isConfirmed => isAccepted && acceptingBlockHash != null;
}

/// Represents an address balance
class AddressBalance {
  final String address;
  final int balance; // Balance in sompi (smallest unit)

  AddressBalance({
    required this.address,
    required this.balance,
  });

  factory AddressBalance.fromMap(Map<String, dynamic> map) {
    return AddressBalance(
      address: map['address'] as String? ?? '',
      balance: map['balance'] as int? ?? 0,
    );
  }

  /// Convert balance from sompi to KAS (1 KAS = 100,000,000 sompi)
  double get balanceInKas => balance / 100000000.0;

  Map<String, dynamic> toMap() {
    return {
      'address': address,
      'balance': balance,
    };
  }
}

/// Represents a full transaction with inputs and outputs
class KaspaFullTransaction {
  final String subnetworkId;
  final String transactionId;
  final String hash;
  final String mass;
  final String? payload;
  final List<String> blockHash;
  final int blockTime;
  final bool isAccepted;
  final String? acceptingBlockHash;
  final int? acceptingBlockBlueScore;
  final int? acceptingBlockTime;
  final List<TransactionInput> inputs;
  final List<TransactionOutput> outputs;

  KaspaFullTransaction({
    required this.subnetworkId,
    required this.transactionId,
    required this.hash,
    required this.mass,
    this.payload,
    required this.blockHash,
    required this.blockTime,
    required this.isAccepted,
    this.acceptingBlockHash,
    this.acceptingBlockBlueScore,
    this.acceptingBlockTime,
    required this.inputs,
    required this.outputs,
  });

  factory KaspaFullTransaction.fromMap(Map<String, dynamic> map) {
    return KaspaFullTransaction(
      subnetworkId: map['subnetwork_id'] as String? ?? '',
      transactionId: map['transaction_id'] as String? ?? '',
      hash: map['hash'] as String? ?? '',
      mass: map['mass'] as String? ?? '0',
      payload: map['payload'] as String?,
      blockHash: (map['block_hash'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      blockTime: map['block_time'] as int? ?? 0,
      isAccepted: map['is_accepted'] as bool? ?? false,
      acceptingBlockHash: map['accepting_block_hash'] as String?,
      acceptingBlockBlueScore: map['accepting_block_blue_score'] as int?,
      acceptingBlockTime: map['accepting_block_time'] as int?,
      inputs: (map['inputs'] as List<dynamic>?)
              ?.map((e) => TransactionInput.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      outputs: (map['outputs'] as List<dynamic>?)
              ?.map((e) => TransactionOutput.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  bool get isConfirmed => isAccepted && acceptingBlockHash != null;
}

/// Represents a transaction input
class TransactionInput {
  final String transactionId;
  final int index;
  final String previousOutpointHash;
  final String previousOutpointIndex;
  final String? previousOutpointAddress;
  final int? previousOutpointAmount;
  final String signatureScript;
  final String sigOpCount;

  TransactionInput({
    required this.transactionId,
    required this.index,
    required this.previousOutpointHash,
    required this.previousOutpointIndex,
    this.previousOutpointAddress,
    this.previousOutpointAmount,
    required this.signatureScript,
    required this.sigOpCount,
  });

  factory TransactionInput.fromMap(Map<String, dynamic> map) {
    return TransactionInput(
      transactionId: map['transaction_id'] as String? ?? '',
      index: map['index'] as int? ?? 0,
      previousOutpointHash: map['previous_outpoint_hash'] as String? ?? '',
      previousOutpointIndex: map['previous_outpoint_index'] as String? ?? '0',
      previousOutpointAddress: map['previous_outpoint_address'] as String?,
      previousOutpointAmount: map['previous_outpoint_amount'] as int?,
      signatureScript: map['signature_script'] as String? ?? '',
      sigOpCount: map['sig_op_count'] as String? ?? '0',
    );
  }
}

/// Represents a transaction output
class TransactionOutput {
  final String transactionId;
  final int index;
  final int amount; // Amount in sompi
  final String scriptPublicKey;
  final String scriptPublicKeyAddress;
  final String scriptPublicKeyType;

  TransactionOutput({
    required this.transactionId,
    required this.index,
    required this.amount,
    required this.scriptPublicKey,
    required this.scriptPublicKeyAddress,
    required this.scriptPublicKeyType,
  });

  factory TransactionOutput.fromMap(Map<String, dynamic> map) {
    return TransactionOutput(
      transactionId: map['transaction_id'] as String? ?? '',
      index: map['index'] as int? ?? 0,
      amount: map['amount'] as int? ?? 0,
      scriptPublicKey: map['script_public_key'] as String? ?? '',
      scriptPublicKeyAddress: map['script_public_key_address'] as String? ?? '',
      scriptPublicKeyType: map['script_public_key_type'] as String? ?? '',
    );
  }

  /// Convert amount from sompi to KAS
  double get amountInKas => amount / 100000000.0;
}
