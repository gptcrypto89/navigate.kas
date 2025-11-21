/// Utility functions for generating HTML pages for browser states
class HtmlPages {
  /// Generate loading page HTML
  static String loadingPage(String domain, String status) {
    return '''
      <html>
      <head>
        <title>Loading $domain</title>
        <style>
          @keyframes pulse {
            0%, 100% { opacity: 1; transform: scale(1); }
            50% { opacity: 0.8; transform: scale(1.05); }
          }
          
          @keyframes shimmer {
            0% { background-position: -200% center; }
            100% { background-position: 200% center; }
          }
          
          @keyframes fadeIn {
            from { opacity: 0; transform: translateY(10px); }
            to { opacity: 1; transform: translateY(0); }
          }
          
          body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            height: 100vh;
            margin: 0;
            background: linear-gradient(135deg, #1e293b 0%, #0f172a 50%, #1e1b4b 100%);
            color: #f9fafb;
          }
          
          .container {
            text-align: center;
            animation: fadeIn 0.3s ease-out;
          }
          
          .loader {
            width: 60px;
            height: 60px;
            margin: 0 auto 24px;
            border: 3px solid rgba(112, 199, 186, 0.2);
            border-top-color: #70c7ba;
            border-radius: 50%;
            animation: spin 1s linear infinite;
          }
          
          @keyframes spin {
            to { transform: rotate(360deg); }
          }
          
          h1 {
            font-size: 1.5em;
            margin: 0 0 16px 0;
            font-weight: 600;
            background: linear-gradient(90deg, #f9fafb 0%, #70c7ba 50%, #f9fafb 100%);
            background-size: 200% auto;
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            background-clip: text;
            animation: shimmer 3s linear infinite;
          }
          
          .domain {
            font-family: 'Courier New', monospace;
            font-size: 1.2em;
            color: #70c7ba;
            margin: 12px 0;
            animation: pulse 2s ease-in-out infinite;
          }
          
          .status {
            font-size: 0.95em;
            color: #d1d5db;
            opacity: 0.8;
            margin-top: 8px;
          }
          
          .dots {
            display: inline-block;
            width: 20px;
          }
          
          @keyframes dot1 {
            0%, 80%, 100% { opacity: 0; }
            40% { opacity: 1; }
          }
          
          @keyframes dot2 {
            0%, 80%, 100% { opacity: 0; }
            50% { opacity: 1; }
          }
          
          @keyframes dot3 {
            0%, 80%, 100% { opacity: 0; }
            60% { opacity: 1; }
          }
          
          .dot {
            animation-duration: 1.4s;
            animation-iteration-count: infinite;
            animation-fill-mode: both;
          }
          
          .dot:nth-child(1) { animation-name: dot1; }
          .dot:nth-child(2) { animation-name: dot2; animation-delay: 0.2s; }
          .dot:nth-child(3) { animation-name: dot3; animation-delay: 0.4s; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="loader"></div>
          <h1>Verifying Domain</h1>
          <div class="domain">$domain</div>
          <div class="status">
            $status<span class="dots"><span class="dot">.</span><span class="dot">.</span><span class="dot">.</span></span>
          </div>
        </div>
      </body>
      </html>
    ''';
  }

  /// Generate empty page HTML
  static String emptyPage() {
    return '''
      <html>
      <head>
        <title>Navigate</title>
        <style>
          body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            height: 100vh;
            margin: 0;
            background: linear-gradient(135deg, #1e293b 0%, #0f172a 50%, #1e1b4b 100%);
            color: #f9fafb;
          }
          h1 { 
            font-size: 3em; 
            margin: 0.5em 0;
            background: linear-gradient(135deg, #f9fafb 0%, #70c7ba 100%);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            background-clip: text;
          }
          p { font-size: 1.2em; opacity: 0.9; color: #d1d5db; }
        </style>
      </head>
      <body>
        <h1>🌐 Navigate</h1>
        <p>Enter a domain name to get started</p>
        <p style="font-size: 0.9em; opacity: 0.7;">e.g., navigate.kas</p>
      </body>
      </html>
    ''';
  }

  /// Generate domain not found page HTML
  static String domainNotFoundPage(String domain) {
    return '''
      <html>
      <head>
        <title>Domain Not Registered</title>
        <style>
          body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            height: 100vh;
            margin: 0;
            background: linear-gradient(135deg, #1e293b 0%, #0f172a 50%, #1e1b4b 100%);
            color: #f9fafb;
          }
          .container {
            text-align: center;
            padding: 2em;
            background: rgba(30, 41, 59, 0.8);
            border-radius: 16px;
            backdrop-filter: blur(10px);
            box-shadow: 0 8px 32px rgba(0, 0, 0, 0.4);
            border: 1px solid #334155;
            max-width: 500px;
          }
          .icon {
            font-size: 4em;
            margin-bottom: 0.5em;
          }
          h1 {
            font-size: 2em;
            margin: 0.5em 0;
            font-weight: 600;
            background: linear-gradient(135deg, #f9fafb 0%, #70c7ba 100%);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            background-clip: text;
          }
          .domain {
            font-family: 'Courier New', monospace;
            background: rgba(112, 199, 186, 0.2);
            padding: 0.3em 0.8em;
            border-radius: 8px;
            display: inline-block;
            margin: 0.5em 0;
            font-size: 1.2em;
            border: 1px solid #70c7ba;
            color: #4fd1c7;
          }
          p {
            font-size: 1.1em;
            opacity: 0.9;
            line-height: 1.6;
            margin: 0.5em 0;
            color: #d1d5db;
          }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="icon">🔍</div>
          <h1>Domain Not Registered</h1>
          <p>The domain</p>
          <div class="domain">$domain</div>
          <p>is not registered in the DNS system.</p>
          <p style="font-size: 0.9em; opacity: 0.8; margin-top: 1.5em;">
            Please check the domain name and try again.
          </p>
        </div>
      </body>
      </html>
    ''';
  }

  /// Generate domain not confirmed page HTML
  static String domainNotConfirmedPage(String domain) {
    return '''
      <html>
      <head>
        <title>Transaction Not Confirmed</title>
        <style>
          body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            height: 100vh;
            margin: 0;
            background: linear-gradient(135deg, #1e293b 0%, #0f172a 50%, #1e1b4b 100%);
            color: #f9fafb;
          }
          .container {
            text-align: center;
            padding: 2em;
            background: rgba(30, 41, 59, 0.8);
            border-radius: 16px;
            backdrop-filter: blur(10px);
            box-shadow: 0 8px 32px rgba(0, 0, 0, 0.4);
            border: 1px solid #334155;
            max-width: 500px;
          }
          .icon {
            font-size: 4em;
            margin-bottom: 0.5em;
          }
          h1 {
            font-size: 2em;
            margin: 0.5em 0;
            font-weight: 600;
            background: linear-gradient(135deg, #f9fafb 0%, #fbbf24 100%);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            background-clip: text;
          }
          .domain {
            font-family: 'Courier New', monospace;
            background: rgba(251, 191, 36, 0.2);
            padding: 0.3em 0.8em;
            border-radius: 8px;
            display: inline-block;
            margin: 0.5em 0;
            font-size: 1.2em;
            border: 1px solid #fbbf24;
            color: #fbbf24;
          }
          p {
            font-size: 1.1em;
            opacity: 0.9;
            line-height: 1.6;
            margin: 0.5em 0;
            color: #d1d5db;
          }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="icon">⚠️</div>
          <h1>Transaction Not Confirmed</h1>
          <p>The domain</p>
          <div class="domain">$domain</div>
          <p>exists in KNS but its transaction is not confirmed on the Kaspa blockchain.</p>
          <p style="font-size: 0.9em; opacity: 0.8; margin-top: 1.5em;">
            This domain may be new or there may be an issue with blockchain verification.
          </p>
        </div>
      </body>
      </html>
    ''';
  }

  /// Generate no DNS record page HTML
  static String noDnsRecordPage(String domain) {
    return '''
      <html>
      <head>
        <title>No DNS Record</title>
        <style>
          body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            height: 100vh;
            margin: 0;
            background: linear-gradient(135deg, #1e293b 0%, #0f172a 50%, #1e1b4b 100%);
            color: #f9fafb;
          }
          .container {
            text-align: center;
            padding: 2em;
            background: rgba(30, 41, 59, 0.8);
            border-radius: 16px;
            backdrop-filter: blur(10px);
            box-shadow: 0 8px 32px rgba(0, 0, 0, 0.4);
            border: 1px solid #334155;
            max-width: 500px;
          }
          h1 { color: #ef4444; margin-bottom: 0.5em; }
          p { color: #d1d5db; line-height: 1.6; }
          .domain { 
            color: #70c7ba; 
            font-family: monospace; 
            background: rgba(112, 199, 186, 0.1);
            padding: 4px 8px;
            border-radius: 4px;
          }
        </style>
      </head>
      <body>
        <div class="container">
          <h1>No DNS Record</h1>
          <p>The domain <span class="domain">$domain</span> exists, but no valid DNS record was found.</p>
          <p>Please ensure a DNS record asset is created and confirmed on the blockchain.</p>
        </div>
      </body>
      </html>
    ''';
  }

  /// Generate connection error page HTML
  static String connectionErrorPage(String domain, String errorType, String? details) {
    String errorTitle;
    String errorMessage;
    String icon;
    
    if (errorType.contains('connection refused') || errorType.contains('refused')) {
      errorTitle = 'Connection Refused';
      errorMessage = 'The server at <span class="domain">$domain</span> is not accepting connections on the specified port.';
      icon = '🚫';
    } else if (errorType.contains('timeout') || errorType.contains('timed out')) {
      errorTitle = 'Connection Timeout';
      errorMessage = 'The connection to <span class="domain">$domain</span> timed out. The server may be slow or unreachable.';
      icon = '⏱️';
    } else if (errorType.contains('host') || errorType.contains('not found')) {
      errorTitle = 'Host Not Found';
      errorMessage = 'Could not resolve the hostname for <span class="domain">$domain</span>.';
      icon = '🔍';
    } else if (errorType.contains('SSL') || errorType.contains('certificate')) {
      errorTitle = 'SSL Error';
      errorMessage = 'There was an SSL/TLS error connecting to <span class="domain">$domain</span>.';
      icon = '🔒';
    } else {
      errorTitle = 'Connection Error';
      errorMessage = 'Could not connect to <span class="domain">$domain</span>.';
      icon = '⚠️';
    }
    
    String detailsHtml = '';
    if (details != null && details.isNotEmpty) {
      detailsHtml = '<p style="font-size: 0.9em; opacity: 0.8; margin-top: 1em; color: #94a3b8;">$details</p>';
    }
    
    return '''
      <html>
      <head>
        <title>$errorTitle</title>
        <style>
          body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            height: 100vh;
            margin: 0;
            background: linear-gradient(135deg, #1e293b 0%, #0f172a 50%, #1e1b4b 100%);
            color: #f9fafb;
          }
          .container {
            text-align: center;
            padding: 2em;
            background: rgba(30, 41, 59, 0.8);
            border-radius: 16px;
            backdrop-filter: blur(10px);
            box-shadow: 0 8px 32px rgba(0, 0, 0, 0.4);
            border: 1px solid #334155;
            max-width: 500px;
          }
          .icon {
            font-size: 4em;
            margin-bottom: 0.5em;
          }
          h1 {
            font-size: 2em;
            margin: 0.5em 0;
            font-weight: 600;
            background: linear-gradient(135deg, #f9fafb 0%, #ef4444 100%);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            background-clip: text;
          }
          .domain {
            font-family: 'Courier New', monospace;
            background: rgba(112, 199, 186, 0.2);
            padding: 0.3em 0.8em;
            border-radius: 8px;
            display: inline-block;
            margin: 0.2em 0;
            font-size: 1.1em;
            border: 1px solid #70c7ba;
            color: #4fd1c7;
          }
          p {
            font-size: 1.1em;
            opacity: 0.9;
            line-height: 1.6;
            margin: 0.5em 0;
            color: #d1d5db;
          }
          .suggestions {
            margin-top: 1.5em;
            padding-top: 1.5em;
            border-top: 1px solid #334155;
            text-align: left;
          }
          .suggestions h3 {
            font-size: 1em;
            color: #70c7ba;
            margin-bottom: 0.5em;
          }
          .suggestions ul {
            list-style: none;
            padding: 0;
            margin: 0;
          }
          .suggestions li {
            padding: 0.3em 0;
            color: #94a3b8;
            font-size: 0.9em;
          }
          .suggestions li:before {
            content: "• ";
            color: #70c7ba;
            font-weight: bold;
            margin-right: 0.5em;
          }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="icon">$icon</div>
          <h1>$errorTitle</h1>
          <p>$errorMessage</p>
          $detailsHtml
          <div class="suggestions">
            <h3>Possible solutions:</h3>
            <ul>
              <li>Check if the server is running</li>
              <li>Verify the port number is correct</li>
              <li>Ensure the DNS record points to the correct IP address</li>
              <li>Check your network connection</li>
            </ul>
          </div>
        </div>
      </body>
      </html>
    ''';
  }

  /// Generate error page for non-.kas domains
  static String domainNotSupportedPage(String domain) {
    return '''
      <html>
      <head>
        <title>Domain Not Supported</title>
        <style>
          @keyframes fadeIn {
            from { opacity: 0; transform: translateY(10px); }
            to { opacity: 1; transform: translateY(0); }
          }
          
          body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            height: 100vh;
            margin: 0;
            background: linear-gradient(135deg, #1e293b 0%, #0f172a 50%, #1e1b4b 100%);
            color: #f9fafb;
          }
          
          .container {
            text-align: center;
            animation: fadeIn 0.3s ease-out;
            max-width: 600px;
            padding: 2em;
          }
          
          .icon {
            font-size: 4em;
            margin-bottom: 1em;
          }
          
          h1 {
            font-size: 1.8em;
            margin: 0.5em 0;
            color: #f9fafb;
          }
          
          p {
            font-size: 1.1em;
            color: #cbd5e1;
            line-height: 1.6;
            margin: 1em 0;
          }
          
          .domain {
            font-family: monospace;
            background: rgba(112, 199, 186, 0.1);
            padding: 0.3em 0.6em;
            border-radius: 4px;
            color: #70c7ba;
            font-weight: bold;
          }
          
          .info {
            margin-top: 2em;
            padding: 1.5em;
            background: rgba(255, 255, 255, 0.05);
            border-radius: 8px;
            border: 1px solid rgba(112, 199, 186, 0.2);
          }
          
          .info h3 {
            font-size: 1em;
            color: #70c7ba;
            margin-bottom: 0.5em;
          }
          
          .info p {
            font-size: 0.9em;
            color: #94a3b8;
            margin: 0.5em 0;
          }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="icon">🚫</div>
          <h1>Domain Not Supported</h1>
          <p>
            The domain <span class="domain">$domain</span> is not a .kas domain.
          </p>
          <p>
            This browser only supports Kaspa Name Service (.kas) domains.
          </p>
          <div class="info">
            <h3>How to use this browser:</h3>
            <p>• Only .kas domains are supported (e.g., example.kas)</p>
            <p>• Enter a .kas domain in the address bar to navigate</p>
            <p>• The domain must be registered on the Kaspa blockchain</p>
          </div>
        </div>
      </body>
      </html>
    ''';
  }

  /// Generate certificate error page HTML
  static String certificateErrorPage(String domain) {
    return '''
      <html>
      <head>
        <title>Security Warning</title>
        <style>
          body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            height: 100vh;
            margin: 0;
            background: linear-gradient(135deg, #1e293b 0%, #0f172a 50%, #1e1b4b 100%);
            color: #f9fafb;
          }
          .container {
            text-align: center;
            padding: 2em;
            background: rgba(30, 41, 59, 0.8);
            border-radius: 16px;
            backdrop-filter: blur(10px);
            box-shadow: 0 8px 32px rgba(0, 0, 0, 0.4);
            border: 1px solid #ef4444;
            max-width: 500px;
          }
          .icon {
            font-size: 4em;
            margin-bottom: 0.5em;
          }
          h1 {
            font-size: 2em;
            margin: 0.5em 0;
            font-weight: 600;
            color: #ef4444;
          }
          .domain {
            font-family: 'Courier New', monospace;
            background: rgba(239, 68, 68, 0.1);
            padding: 0.3em 0.8em;
            border-radius: 8px;
            display: inline-block;
            margin: 0.5em 0;
            font-size: 1.2em;
            border: 1px solid #ef4444;
            color: #ef4444;
          }
          p {
            font-size: 1.1em;
            opacity: 0.9;
            line-height: 1.6;
            margin: 0.5em 0;
            color: #d1d5db;
          }
          .warning-box {
            margin-top: 1.5em;
            padding: 1em;
            background: rgba(239, 68, 68, 0.1);
            border-radius: 8px;
            text-align: left;
          }
          .warning-box h3 {
            font-size: 1em;
            color: #ef4444;
            margin-bottom: 0.5em;
            margin-top: 0;
          }
          .warning-box p {
            font-size: 0.9em;
            margin: 0;
            color: #fca5a5;
          }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="icon">🔒</div>
          <h1>Security Warning</h1>
          <p>The connection to</p>
          <div class="domain">$domain</div>
          <p>was blocked because the server's certificate does not match the one pinned on the blockchain.</p>
          
          <div class="warning-box">
            <h3>Potential Man-in-the-Middle Attack</h3>
            <p>
              This could mean someone is intercepting your connection. 
              The browser has prevented this connection to protect your security.
            </p>
          </div>
        </div>
      </body>
      </html>
    ''';
  }
}

