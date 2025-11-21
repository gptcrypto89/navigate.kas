import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../services/kns_api_client.dart';
import '../services/kaspa_explorer_client.dart';

/// Represents a history entry in browser navigation
class HistoryEntry {
  final String domain;
  final String url;
  final bool isVerified;
  
  HistoryEntry({
    required this.domain,
    required this.url,
    this.isVerified = false,
  });
}

/// Represents a browser tab with its state and controller
class BrowserTab {
  final String id;
  InAppWebViewController? controller;
  final TextEditingController urlController;
  final KNSApiClient knsClient;
  final KaspaExplorerClient kaspaExplorer;
  bool isLoading;
  String currentUrl; // Full display URL (e.g., "me.kas/home")
  String? currentDomain; // Just the domain (e.g., "me.kas")
  String? errorMessage;
  bool isLoadingPage;
  bool isVerified;
  Map<String, dynamic>? certificateData; // Store certificate data
  final List<HistoryEntry> history;
  int historyIndex;
  String title;
  
  BrowserTab({
    required this.id,
    this.controller,
    required this.urlController,
    required this.knsClient,
    required this.kaspaExplorer,
    this.isLoading = false,
    this.currentUrl = '',
    this.currentDomain,
    this.isVerified = false,
    this.certificateData,
    this.errorMessage,
    this.isLoadingPage = false,
    List<HistoryEntry>? history,
    this.historyIndex = -1,
    this.title = 'New Tab',
  }) : history = history ?? [];
  
  bool get canGoBack => historyIndex > 0;
  bool get canGoForward => historyIndex < history.length - 1;
  
  void dispose() {
    urlController.dispose();
  }
}

