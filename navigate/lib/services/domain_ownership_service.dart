import '../services/kns_api_client.dart';
import '../services/kaspa_explorer_client.dart';

/// Represents a period of ownership for a domain
class OwnershipPeriod {
  final String address;
  final DateTime fromTime;
  final DateTime? toTime; // null for current owner
  final String transactionId;

  OwnershipPeriod({
    required this.address,
    required this.fromTime,
    this.toTime,
    required this.transactionId,
  });

  /// Check if this period includes the given time
  bool includesTime(DateTime time) {
    if (time.isBefore(fromTime)) return false;
    if (toTime != null && time.isAfter(toTime!)) return false;
    return true;
  }

  @override
  String toString() {
    final toTimeStr = toTime?.toIso8601String() ?? 'current';
    return 'OwnershipPeriod(address: $address, from: ${fromTime.toIso8601String()}, to: $toTimeStr)';
  }
}

/// Service to track domain ownership history
class DomainOwnershipService {
  final KNSApiClient knsClient;
  final KaspaExplorerClient kaspaExplorer;

  DomainOwnershipService({
    required this.knsClient,
    required this.kaspaExplorer,
  });

  /// Build complete ownership timeline for a domain by tracing UTXO transfers
  Future<List<OwnershipPeriod>> buildOwnershipTimeline(String domain) async {
    try {
      print('🔍 Ownership: Building timeline for domain: $domain');

      // 1. Get the domain inscription from KNS
      final result = await knsClient.checkDomainExists(domain);
      if (!result.found || result.domain == null) {
        print('❌ Ownership: Domain not found in KNS');
        return [];
      }

      final knsDomain = result.domain!;
      final creationTime = knsDomain.creationBlockTime;
      final rootTxId = knsDomain.transactionId;
      
      print('📍 Ownership: Root transaction: $rootTxId at ${creationTime.toIso8601String()}');

      // 2. Trace ownership history
      final timeline = <OwnershipPeriod>[];
      
      // Get the root transaction to find initial owner
      final rootTx = await kaspaExplorer.getFullTransaction(rootTxId);
      if (rootTx == null) {
        // Fallback to current owner if we can't get root tx
        print('⚠️ Ownership: Could not fetch root transaction, using current owner');
        timeline.add(OwnershipPeriod(
          address: knsDomain.owner,
          fromTime: creationTime,
          toTime: null,
          transactionId: rootTxId,
        ));
        return timeline;
      }

      // The initial owner is the address in the first output (index 0 for inscription)
      String currentOwner = knsDomain.owner; // Start with current owner from KNS
      if (rootTx.outputs.isNotEmpty) {
        // Find the output that contains the inscription (usually index 0)
        // For KNS, the inscription is in output 0
        currentOwner = rootTx.outputs[0].scriptPublicKeyAddress;
      }

      DateTime currentTime = creationTime;
      String currentTxId = rootTxId;
      int currentOutputIndex = 0; // Inscription is always in output 0

      // Add initial ownership period
      print('👤 Ownership: Initial owner: $currentOwner');

      // 3. Trace transfers by finding spending transactions
      final knsCurrentOwner = knsDomain.owner; // Current owner according to KNS
      
      while (true) {
        // Find transaction that spends this output
        // Search BOTH the current tracked owner AND the KNS current owner
        // because spending tx appears in both addresses' transaction lists
        KaspaFullTransaction? spendingTx = await kaspaExplorer.findSpendingTransaction(
          currentTxId,
          currentOutputIndex,
          currentOwner,
        );
        
        // If not found in old owner's txs, try current owner from KNS
        if (spendingTx == null && currentOwner != knsCurrentOwner) {
          print('🔍 Ownership: Checking KNS current owner for spending tx...');
          spendingTx = await kaspaExplorer.findSpendingTransaction(
            currentTxId,
            currentOutputIndex,
            knsCurrentOwner,
          );
        }

        if (spendingTx == null) {
          // This is the current unspent UTXO
          print('✅ Ownership: Reached current owner (unspent)');
          timeline.add(OwnershipPeriod(
            address: currentOwner,
            fromTime: currentTime,
            toTime: null, // Current owner
            transactionId: currentTxId,
          ));
          break;
        }

        // Found a transfer!
        final transferTime = DateTime.fromMillisecondsSinceEpoch(spendingTx.blockTime);
        print('🔄 Ownership: Transfer at ${transferTime.toIso8601String()} via ${spendingTx.transactionId}');
        print('   Transfer has ${spendingTx.outputs.length} outputs');

        // Close current ownership period
        timeline.add(OwnershipPeriod(
          address: currentOwner,
          fromTime: currentTime,
          toTime: transferTime,
          transactionId: currentTxId,
        ));

        // Find the new owner from spending transaction outputs
        // The inscription should be in one of the outputs
        String? newOwner;
        int? newOutputIndex;
        
        // Log all outputs to understand the transfer
        for (var i = 0; i < spendingTx.outputs.length; i++) {
          final output = spendingTx.outputs[i];
          print('   Output $i: ${output.scriptPublicKeyAddress} (amount: ${output.amount})');
        }
        
        for (final output in spendingTx.outputs) {
          // The domain inscription is usually transferred to a specific output
          // We look for the output that's not a fee/change output
          // Typically it's output 0 or 1
          if (output.scriptPublicKeyAddress.isNotEmpty && 
              output.scriptPublicKeyAddress != currentOwner) {
            newOwner = output.scriptPublicKeyAddress;
            newOutputIndex = output.index;
            print('   → Candidate new owner at output ${output.index}: $newOwner');
            break;
          }
        }

        if (newOwner == null || newOwner.isEmpty) {
          print('⚠️ Ownership: Could not determine new owner, stopping trace');
          print('   Current timeline length: ${timeline.length}');
          print('   KNS says current owner is: $knsCurrentOwner');
          break;
        }

        if (newOutputIndex == null) {
          print('⚠️ Ownership: Could not determine output index for new owner');
          newOutputIndex = 0; // Default to 0
        }

        print('👤 Ownership: New owner: $newOwner at output $newOutputIndex');
        
        // Move to next period
        currentOwner = newOwner;
        currentTime = transferTime;
        currentTxId = spendingTx.transactionId;
        currentOutputIndex = newOutputIndex;
      }

      print('✅ Ownership: Built timeline with ${timeline.length} periods');
      for (final period in timeline) {
        print('   $period');
      }

      return timeline;
    } catch (e) {
      print('❌ Ownership: Error building timeline: $e');
      return [];
    }
  }

  /// Get the owner address at a specific point in time
  String? getOwnerAtTime(List<OwnershipPeriod> timeline, DateTime time) {
    for (final period in timeline) {
      if (period.includesTime(time)) {
        return period.address;
      }
    }
    return null;
  }
}
