/// Comprehensive URL parsing result
class ParsedUrl {
  final String? scheme;
  final String? userInfo;
  final String host;
  final int? port;
  final String? path;
  final Map<String, String> queryParameters;
  final String? fragment;

  ParsedUrl({
    this.scheme,
    this.userInfo,
    required this.host,
    this.port,
    this.path,
    Map<String, String>? queryParameters,
    this.fragment,
  }) : queryParameters = queryParameters ?? {};

  /// Get the domain (host without port)
  String get domain => host;

  /// Build the full URL string
  String buildUrl({bool includeFragment = true, bool includeQuery = true}) {
    final buffer = StringBuffer();
    
    if (scheme != null) {
      buffer.write('$scheme://');
    }
    
    if (userInfo != null) {
      buffer.write('$userInfo@');
    }
    
    buffer.write(host);
    
    if (port != null) {
      buffer.write(':$port');
    }
    
    if (path != null && path!.isNotEmpty) {
      if (!path!.startsWith('/')) {
        buffer.write('/');
      }
      buffer.write(path);
    }
    
    if (includeQuery && queryParameters.isNotEmpty) {
      buffer.write('?');
      buffer.write(queryParameters.entries
          .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
          .join('&'));
    }
    
    if (includeFragment && fragment != null && fragment!.isNotEmpty) {
      buffer.write('#${Uri.encodeComponent(fragment!)}');
    }
    
    return buffer.toString();
  }

  /// Build display URL (for showing in address bar)
  String buildDisplayUrl() {
    final buffer = StringBuffer();
    
    final displayScheme = scheme ?? 'https';
    buffer.write('$displayScheme://');
    buffer.write(host);
    
    // Only show port if it's non-standard
    if (port != null && port != 80 && port != 443) {
      buffer.write(':$port');
    }
    
    if (path != null && path!.isNotEmpty) {
      if (!path!.startsWith('/')) {
        buffer.write('/');
      }
      buffer.write(path);
    }
    
    if (queryParameters.isNotEmpty) {
      buffer.write('?');
      buffer.write(queryParameters.entries
          .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
          .join('&'));
    }
    
    if (fragment != null && fragment!.isNotEmpty) {
      buffer.write('#${Uri.encodeComponent(fragment!)}');
    }
    
    return buffer.toString();
  }

  /// Build HTTPS URL for actual navigation (uses resolved IP)
  String buildHttpsUrl(String resolvedIp) {
    final buffer = StringBuffer();
    buffer.write('https://$resolvedIp');
    
    if (port != null) {
      buffer.write(':$port');
    }
    
    if (path != null && path!.isNotEmpty) {
      if (!path!.startsWith('/')) {
        buffer.write('/');
      }
      buffer.write(path);
    }
    
    if (queryParameters.isNotEmpty) {
      buffer.write('?');
      buffer.write(queryParameters.entries
          .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
          .join('&'));
    }
    
    if (fragment != null && fragment!.isNotEmpty) {
      buffer.write('#${Uri.encodeComponent(fragment!)}');
    }
    
    return buffer.toString();
  }
}

/// Helper class for parsing URLs with full standard URL support
class UrlParsingHelper {
  /// Parse a URL string into its components
  /// Supports: scheme://user:pass@host:port/path?query=value#fragment
  static ParsedUrl parseUrl(String url) {
    if (url.isEmpty) {
      throw ArgumentError('URL cannot be empty');
    }

    // Remove leading/trailing whitespace
    url = url.trim();

    // Default scheme
    String? scheme;
    String? userInfo;
    String host;
    int? port;
    String? path;
    Map<String, String> queryParameters = {};
    String? fragment;

    // Extract fragment first (before parsing rest)
    if (url.contains('#')) {
      final fragmentIndex = url.indexOf('#');
      fragment = url.substring(fragmentIndex + 1);
      url = url.substring(0, fragmentIndex);
    }

    // Extract scheme
    if (url.contains('://')) {
      final schemeIndex = url.indexOf('://');
      scheme = url.substring(0, schemeIndex).toLowerCase();
      url = url.substring(schemeIndex + 3);
    } else {
      // Default to https for KNS domains
      scheme = 'https';
    }

    // Extract query parameters
    if (url.contains('?')) {
      final queryIndex = url.indexOf('?');
      final queryString = url.substring(queryIndex + 1);
      url = url.substring(0, queryIndex);
      
      // Parse query parameters
      if (queryString.isNotEmpty) {
        final pairs = queryString.split('&');
        for (final pair in pairs) {
          if (pair.isEmpty) continue;
          final equalIndex = pair.indexOf('=');
          if (equalIndex == -1) {
            // Parameter without value
            queryParameters[Uri.decodeComponent(pair)] = '';
          } else {
            final key = Uri.decodeComponent(pair.substring(0, equalIndex));
            final value = Uri.decodeComponent(pair.substring(equalIndex + 1));
            queryParameters[key] = value;
          }
        }
      }
    }

    // Extract path
    String? pathPart;
    if (url.contains('/')) {
      final pathIndex = url.indexOf('/');
      pathPart = url.substring(pathIndex);
      url = url.substring(0, pathIndex);
    }

    // Extract user info (user:pass@host)
    if (url.contains('@')) {
      final atIndex = url.indexOf('@');
      userInfo = url.substring(0, atIndex);
      url = url.substring(atIndex + 1);
    }

    // Extract port from host
    if (url.contains(':') && url.contains('[') == false) {
      // IPv6 addresses are in brackets, handle them differently
      final colonIndex = url.lastIndexOf(':');
      final portStr = url.substring(colonIndex + 1);
      final portValue = int.tryParse(portStr);
      if (portValue != null) {
        port = portValue;
        host = url.substring(0, colonIndex);
      } else {
        host = url;
      }
    } else if (url.startsWith('[') && url.contains(']')) {
      // IPv6 address with port: [::1]:8080
      final bracketEnd = url.indexOf(']');
      host = url.substring(0, bracketEnd + 1);
      if (url.length > bracketEnd + 1 && url[bracketEnd + 1] == ':') {
        final portStr = url.substring(bracketEnd + 2);
        port = int.tryParse(portStr);
      }
    } else {
      host = url;
    }

    // Set default port based on scheme if not specified
    if (port == null) {
      switch (scheme) {
        case 'http':
          port = 80;
          break;
        case 'https':
          port = 443;
          break;
        default:
          port = 443; // Default to HTTPS port
      }
    }

    // Clean up path
    if (pathPart != null && pathPart.isNotEmpty) {
      path = pathPart;
    }

    return ParsedUrl(
      scheme: scheme,
      userInfo: userInfo,
      host: host,
      port: port,
      path: path,
      queryParameters: queryParameters,
      fragment: fragment,
    );
  }

  /// Build display URL from domain and full URL
  /// Used for showing user-friendly URLs in the address bar
  static String buildDisplayUrl(String? domain, String fullUrl, {int? port}) {
    if (domain == null || domain.isEmpty) {
      return '';
    }

    try {
      final uri = Uri.parse(fullUrl);
      final buffer = StringBuffer();
      
      // Always show scheme
      buffer.write('${uri.scheme}://');
      buffer.write(domain);
      
      // Show port only if non-standard
      final displayPort = port ?? uri.port;
      if (displayPort != 80 && displayPort != 443) {
        buffer.write(':$displayPort');
      }
      
      // Add path
      if (uri.path.isNotEmpty && uri.path != '/') {
        buffer.write(uri.path);
      }
      
      // Add query parameters
      if (uri.queryParameters.isNotEmpty) {
        buffer.write('?');
        buffer.write(uri.query);
      }
      
      // Add fragment
      if (uri.fragment.isNotEmpty) {
        buffer.write('#${uri.fragment}');
      }
      
      return buffer.toString();
    } catch (e) {
      // Fallback to simple domain if parsing fails
      return domain;
    }
  }

  /// Check if a URL is a standard HTTP/HTTPS URL (not a KNS domain)
  static bool isStandardUrl(String url) {
    try {
      final uri = Uri.parse(url);
      // Check if it's http or https scheme
      if (uri.scheme != 'http' && uri.scheme != 'https') {
        return false;
      }
      
      // KNS domains end with .kas - these should go through KNS resolution
      final host = uri.host.toLowerCase();
      if (host.endsWith('.kas')) {
        return false; // KNS domains are not standard URLs
      }
      
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Check if a domain is a KNS domain
  static bool isKnsDomain(String domain) {
    if (domain.isEmpty) return false;
    return domain.toLowerCase().endsWith('.kas');
  }

  /// Normalize a URL (add scheme if missing, etc.)
  static String normalizeUrl(String url) {
    if (url.isEmpty) return url;
    
    url = url.trim();
    
    // If it's already a standard URL, return as is
    if (isStandardUrl(url)) {
      return url;
    }
    
    // If it starts with //, add https:
    if (url.startsWith('//')) {
      return 'https:$url';
    }
    
    // If it doesn't have a scheme, add https:// for parsing
    // (but we'll check if it's KNS domain later)
    if (!url.contains('://')) {
      return 'https://$url';
    }
    
    return url;
  }
}

