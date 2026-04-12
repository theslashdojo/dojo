#!/usr/bin/env bash
# Create a new React Email template for use with Resend.
#
# Usage:
#   ./create-template.sh <template-name> [--tailwind] [--dir <path>]
#
# Examples:
#   ./create-template.sh welcome
#   ./create-template.sh invoice --tailwind
#   ./create-template.sh password-reset --dir src/emails
#
# This script:
#   1. Installs required packages if not present
#   2. Creates the template directory
#   3. Scaffolds a TSX template with common components
#   4. Adds a dev preview script to package.json if not present

set -euo pipefail

TEMPLATE_NAME="${1:?Usage: create-template.sh <template-name> [--tailwind] [--dir <path>]}"
USE_TAILWIND=false
TEMPLATE_DIR="./emails"

shift
while [[ $# -gt 0 ]]; do
  case "$1" in
    --tailwind) USE_TAILWIND=true; shift ;;
    --dir) TEMPLATE_DIR="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# Convert template name to PascalCase for the component
PASCAL_NAME=$(echo "$TEMPLATE_NAME" | sed -E 's/(^|-)([a-z])/\U\2/g')

# Install dependencies if package.json exists and packages not installed
if [ -f "package.json" ]; then
  if ! npm ls @react-email/components >/dev/null 2>&1; then
    echo "Installing React Email dependencies..."
    npm install @react-email/components react react-dom
    npm install -D react-email @types/react @types/react-dom
  fi
fi

# Create directory
mkdir -p "$TEMPLATE_DIR"

TEMPLATE_FILE="${TEMPLATE_DIR}/${TEMPLATE_NAME}.tsx"

if [ -f "$TEMPLATE_FILE" ]; then
  echo "Error: Template already exists at $TEMPLATE_FILE"
  exit 1
fi

if [ "$USE_TAILWIND" = true ]; then
  cat > "$TEMPLATE_FILE" << TEMPLATE
import {
  Html,
  Head,
  Body,
  Container,
  Text,
  Button,
  Preview,
  Heading,
  Hr,
  Section,
  Tailwind,
} from '@react-email/components';

interface ${PASCAL_NAME}EmailProps {
  name: string;
  actionUrl: string;
}

export function ${PASCAL_NAME}Email({ name, actionUrl }: ${PASCAL_NAME}EmailProps) {
  return (
    <Tailwind>
      <Html>
        <Head />
        <Preview>${PASCAL_NAME} - Action Required</Preview>
        <Body className="bg-gray-100 font-sans">
          <Container className="max-w-xl mx-auto my-8 p-8 bg-white rounded-lg shadow-sm">
            <Heading className="text-2xl font-bold text-gray-900 mb-4">
              Hello, {name}!
            </Heading>
            <Text className="text-gray-600 text-base leading-relaxed">
              This is your ${TEMPLATE_NAME} email. Customize this template
              with your own content and styling.
            </Text>
            <Hr className="my-6 border-gray-200" />
            <Section className="text-center my-6">
              <Button
                href={actionUrl}
                className="bg-black text-white px-6 py-3 rounded-md text-sm font-medium"
              >
                Take Action
              </Button>
            </Section>
            <Text className="text-gray-400 text-xs mt-8">
              If you didn't expect this email, you can safely ignore it.
            </Text>
          </Container>
        </Body>
      </Html>
    </Tailwind>
  );
}

export default ${PASCAL_NAME}Email;
TEMPLATE
else
  cat > "$TEMPLATE_FILE" << TEMPLATE
import {
  Html,
  Head,
  Body,
  Container,
  Text,
  Button,
  Preview,
  Heading,
  Hr,
  Section,
} from '@react-email/components';

interface ${PASCAL_NAME}EmailProps {
  name: string;
  actionUrl: string;
}

export function ${PASCAL_NAME}Email({ name, actionUrl }: ${PASCAL_NAME}EmailProps) {
  return (
    <Html>
      <Head />
      <Preview>${PASCAL_NAME} - Action Required</Preview>
      <Body style={styles.body}>
        <Container style={styles.container}>
          <Heading as="h1" style={styles.heading}>
            Hello, {name}!
          </Heading>
          <Text style={styles.text}>
            This is your ${TEMPLATE_NAME} email. Customize this template
            with your own content and styling.
          </Text>
          <Hr style={styles.hr} />
          <Section style={{ textAlign: 'center' as const, marginTop: '24px' }}>
            <Button href={actionUrl} style={styles.button}>
              Take Action
            </Button>
          </Section>
          <Text style={styles.footer}>
            If you didn't expect this email, you can safely ignore it.
          </Text>
        </Container>
      </Body>
    </Html>
  );
}

const styles = {
  body: {
    backgroundColor: '#f6f9fc',
    fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',
  },
  container: {
    maxWidth: '600px',
    margin: '0 auto',
    padding: '40px 20px',
  },
  heading: {
    fontSize: '24px',
    fontWeight: 'bold' as const,
    color: '#1a1a1a',
    marginBottom: '16px',
  },
  text: {
    fontSize: '16px',
    lineHeight: '1.6',
    color: '#4a4a4a',
  },
  hr: {
    borderColor: '#e6e6e6',
    margin: '24px 0',
  },
  button: {
    backgroundColor: '#000000',
    color: '#ffffff',
    padding: '12px 24px',
    borderRadius: '6px',
    textDecoration: 'none',
    fontSize: '14px',
    fontWeight: '500' as const,
  },
  footer: {
    fontSize: '12px',
    color: '#999999',
    marginTop: '32px',
  },
};

export default ${PASCAL_NAME}Email;
TEMPLATE
fi

echo "Created template: $TEMPLATE_FILE"
echo ""
echo "Usage with Resend:"
echo "  import { ${PASCAL_NAME}Email } from './${TEMPLATE_DIR}/${TEMPLATE_NAME}';"
echo "  await resend.emails.send({"
echo "    from: 'Acme <hello@yourdomain.com>',"
echo "    to: ['user@example.com'],"
echo "    subject: '${PASCAL_NAME}',"
echo "    react: ${PASCAL_NAME}Email({ name: 'John', actionUrl: 'https://example.com' }),"
echo "  });"
echo ""
echo "Preview locally:"
echo "  npx react-email dev --dir ${TEMPLATE_DIR}"
