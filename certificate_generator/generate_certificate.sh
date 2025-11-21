#!/bin/bash

# Check if openssl is installed
if ! command -v openssl &> /dev/null; then
    echo "Error: openssl is not installed."
    exit 1
fi

# Parse arguments
DOMAIN=""
for arg in "$@"
do
    case $arg in
        --domain=*)
        DOMAIN="${arg#*=}"
        shift
        ;;
    esac
done

if [ -z "$DOMAIN" ]; then
    echo "Error: --domain argument is required"
    echo "Usage: ./generate_certificate.sh --domain=example.kas"
    exit 1
fi

echo "Generating ultra-compact self-signed certificate for $DOMAIN..."

# Generate ECDSA private key (P-256 curve - much smaller than RSA)
# P-256 provides equivalent security to RSA 3072-bit but is only ~256 bits
openssl ecparam -genkey -name prime256v1 -out key.pem 2>/dev/null

if [ $? -ne 0 ]; then
    echo "Error: Failed to generate ECDSA key."
    exit 1
fi

# Create ultra-minimal OpenSSL config (v1 certificate - no extensions = smallest)
DOMAIN_SHORT="${DOMAIN%.kas}"
cat > /tmp/minimal_openssl.cnf <<EOF
[req]
distinguished_name = req_distinguished_name
prompt = no
x509_extensions = v3_none

[req_distinguished_name]
CN = $DOMAIN_SHORT

[v3_none]
EOF

# Generate ultra-minimal v1 certificate (no extensions = smallest possible)
# -x509: Output a self-signed certificate
# -days 9999: Very long validity (9999 days ≈ 27 years) - effectively unlimited
# -key key.pem: Use the generated ECDSA key
# -out cert.pem: Save certificate to cert.pem
# -config: Use minimal config (empty extensions section = v1 certificate)
# -set_serial: Use smallest serial number (1)
# Note: v1 certificates are deprecated but much smaller and still work for self-signed certs
openssl req -x509 -key key.pem -out cert.pem -days 9999 -config /tmp/minimal_openssl.cnf -set_serial 1 2>/dev/null

if [ $? -ne 0 ]; then
    echo "Error: Failed to generate certificate."
    rm -f /tmp/minimal_openssl.cnf
    exit 1
fi

# Clean up temp config
rm -f /tmp/minimal_openssl.cnf

# Convert to DER format (binary) then to Base64 (more compact than PEM)
# DER is more compact than PEM format
openssl x509 -in cert.pem -outform DER -out cert.der 2>/dev/null

if [ $? -ne 0 ]; then
    echo "Error: Failed to convert certificate to DER format."
    exit 1
fi

# Convert DER to Base64 (more compact)
# macOS base64 uses -i flag for input file
CERT_B64=$(base64 -i cert.der | tr -d '\n')

# Create JSON content in the simplified format: {"d":"domain","c":"certificate"}
# Remove .kas extension from domain for storage
# No spaces to minimize size
DOMAIN_WITHOUT_KAS="${DOMAIN%.kas}"
JSON_CONTENT="{\"d\":\"$DOMAIN_WITHOUT_KAS\",\"c\":\"$CERT_B64\"}"

# Save to certificate.json
echo "$JSON_CONTENT" > certificate.json

# Calculate sizes
CERT_SIZE=$(echo -n "$CERT_B64" | wc -c | tr -d ' ')
KEY_SIZE=$(wc -c < key.pem | tr -d ' ')

echo "Success!"
echo "Certificate saved to certificate.json"
echo "Certificate size: $CERT_SIZE bytes (Base64)"
echo "Private key size: $KEY_SIZE bytes"
echo "Raw certificate: cert.pem"
echo "Private key: key.pem"
echo ""
echo "Certificate format: ECDSA P-256 (compact and secure)"
