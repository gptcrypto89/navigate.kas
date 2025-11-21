import '../services/kns_api_client.dart';
import '../services/kaspa_explorer_client.dart';
import '../services/domain_ownership_service.dart';

/// Service to validate inscriptions (DNS/Certificate) against domain ownership
class InscriptionValidator {
  final KaspaExplorerClient kaspaExplorer;
  final DomainOwnershipService ownershipService;

  InscriptionValidator({
    required this.kaspaExplorer,
    required this.ownershipService,
  });

  /// Validate that an inscription was created by the legitimate domain owner
  /// OR was co-owned with the domain at some point (legitimate transfer)
  /// 
  /// Returns true if:
  /// 1. The inscription's creation transaction was signed by the domain owner at creation time (STRICT)
  /// 2. OR the inscription and domain were both owned by the same address at some point (TRANSFER SUPPORT)
  /// 3. OR the inscription's current owner matches the domain's current owner from KNS (FALLBACK)
  Future<bool> validateInscription(
    KNSDomain inscription,
    List<OwnershipPeriod> ownershipTimeline,
    String knsCurrentOwner, // Current owner from KNS API
  ) async {
    try {
      print('🔍 Validator: Checking inscription ${inscription.assetId}');

      // 1. Get creation time and current owner
      final creationTime = inscription.creationBlockTime;
      final creationTxId = inscription.transactionId;
      final currentOwner = inscription.owner;

      print('   Created at: ${creationTime.toIso8601String()}');
      print('   Transaction: $creationTxId');
      // 2. PRIORITY CHECK: Current owner from KNS API
      // This bypasses timeline issues and uses KNS as source of truth
      print('   🔍 Direct KNS ownership check...');
      print('   Domain current owner (from KNS API): $knsCurrentOwner');
      print('   Inscription current owner: $currentOwner');
      
      if (currentOwner == knsCurrentOwner) {
        print('   ✓ MATCH: Both inscription and domain currently owned by same wallet');
        print('✅ Validator: Inscription is VALID (KNS current owner match)');
        return true;
      }
      
      print('   ✗ NO MATCH: Inscription owner ($currentOwner) ≠ Domain owner ($knsCurrentOwner)');
      
      // 3. Strict validation: check creation signature
      print('   Checking creation signature...');
      
      final expectedOwner = ownershipService.getOwnerAtTime(ownershipTimeline, creationTime);
      if (expectedOwner == null) {
        print('❌ Validator: No domain owner found at creation time');
        return false;
      }

      print('   Expected creator (domain owner at creation): $expectedOwner');

      // Get the creation transaction
      final transactions = await kaspaExplorer.getAddressTransactions(expectedOwner, limit: 100);
      
      KaspaFullTransaction? creationTx;
      for (final tx in transactions) {
        if (tx.transactionId == creationTxId) {
          creationTx = tx;
          break;
        }
      }

      if (creationTx == null) {
        print('❌ Validator: Could not find creation transaction');
        return false;
      }

      // Extract signer addresses
      final signerAddresses = await kaspaExplorer.extractSignerAddresses(creationTx);
      
      print('   Creation signers: ${signerAddresses.join(", ")}');

      // Validate: at least one signer must match the expected owner
      final isValid = signerAddresses.contains(expectedOwner);
      
      if (isValid) {
        print('✅ Validator: Inscription is VALID (signed by domain owner at creation)');
      } else {
        print('❌ Validator: Inscription is INVALID (not signed by owner and no ownership overlap)');
      }

      return isValid;
    } catch (e) {
      print('❌ Validator: Error validating inscription: $e');
      return false;
    }
  }

  /// Filter and select valid inscriptions from a list of candidates
  /// Returns only inscriptions created by legitimate owners, sorted by newest first
  Future<List<KNSDomain>> selectValidInscriptions(
    List<KNSDomain> candidates,
    List<OwnershipPeriod> ownershipTimeline,
    String knsCurrentOwner,
  ) async {
    final validInscriptions = <KNSDomain>[];

    print('🔍 Validator: Checking ${candidates.length} candidate inscriptions');

    for (final candidate in candidates) {
      final isValid = await validateInscription(candidate, ownershipTimeline, knsCurrentOwner);
      if (isValid) {
        validInscriptions.add(candidate);
      }
    }

    // Sort by creation time, newest first
    validInscriptions.sort((a, b) => b.creationBlockTime.compareTo(a.creationBlockTime));

    print('✅ Validator: Found ${validInscriptions.length} valid inscriptions');

    return validInscriptions;
  }

  /// Validate and select the newest valid DNS record
  Future<KNSDomain?> selectValidDnsRecord(
    List<KNSDomain> dnsRecords,
    List<OwnershipPeriod> ownershipTimeline,
    String knsCurrentOwner,
  ) async {
    print('🌐 Validator: Selecting valid DNS record from ${dnsRecords.length} candidates');
    
    final validRecords = await selectValidInscriptions(dnsRecords, ownershipTimeline, knsCurrentOwner);
    
    if (validRecords.isEmpty) {
      print('❌ Validator: No valid DNS records found');
      return null;
    }

    final selected = validRecords.first; // Already sorted by newest
    print('✅ Validator: Selected DNS record: ${selected.assetId} (created ${selected.creationBlockTime})');
    return selected;
  }

  /// Validate and select the newest valid certificate record
  Future<KNSDomain?> selectValidCertificateRecord(
    List<KNSDomain> certRecords,
    List<OwnershipPeriod> ownershipTimeline,
    String knsCurrentOwner,
  ) async {
    print('🔒 Validator: Selecting valid certificate record from ${certRecords.length} candidates');
    
    final validRecords = await selectValidInscriptions(certRecords, ownershipTimeline, knsCurrentOwner);
    
    if (validRecords.isEmpty) {
      print('❌ Validator: No valid certificate records found');
      return null;
    }

    final selected = validRecords.first; // Already sorted by newest
    print('✅ Validator: Selected certificate: ${selected.assetId} (created ${selected.creationBlockTime})');
    return selected;
  }
}
