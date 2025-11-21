import 'config.dart';

// App Information
const String APP_NAME = 'Navigate';

// AI Assistant Defaults
const String AI_DEFAULT_API_URL = AppConfig.aiApiUrl;
const String AI_DEFAULT_MODEL = AppConfig.aiModel;
const String AI_DEFAULT_SYSTEM_PROMPT = 'You are a helpful assistant that helps users understand and interact with web pages. When provided with page content, analyze it and provide helpful insights.';

// Wallet Providers
const String WALLET_PROVIDER_KASWARE = 'Kasware';
const String WALLET_PROVIDER_KASPIUM = 'Kaspium';
const String WALLET_PROVIDER_LEDGER = 'Ledger';
const String WALLET_PROVIDER_TANGEM = 'Tangem';

// Wallet Provider Descriptions
const String WALLET_DESC_KASWARE = 'Standard Schnorr wallet';
const String WALLET_DESC_KASPIUM = 'Standard Schnorr wallet';
const String WALLET_DESC_LEDGER = 'Hardware wallet (Schnorr)';
const String WALLET_DESC_TANGEM = 'Hardware wallet (ECDSA)';

// Wallet Screen UI
const String WALLET_SCREEN_TITLE = 'Wallet Setup';
const String WALLET_YOUR_WALLETS_TITLE = 'Your Wallets';
const String WALLET_WELCOME_TITLE = 'Welcome to Navigate';
const String WALLET_WELCOME_SUBTITLE = 'Create or import a wallet to get started';
const String WALLET_BTN_CREATE_NEW = 'Create New Wallet';
const String WALLET_BTN_IMPORT_EXISTING = 'Import Existing Wallet';
const String WALLET_BTN_LOGOUT = 'Logout';

// Create Wallet Screen UI
const String CREATE_WALLET_TITLE = 'Backup Your Wallet';
const String CREATE_WALLET_WARNING_TITLE = 'Your Responsibility';
const String CREATE_WALLET_WARNING_MSG = 'Your seed phrase is your responsibility. If you lose it, you will permanently lose access to your wallet and all funds. If someone else obtains it, they will have full access to all your funds and assets.';
const String CREATE_WALLET_PROVIDER_LABEL = 'Wallet Provider';
const String CREATE_WALLET_PASSPHRASE_LABEL = 'Passphrase (Optional)';
const String CREATE_WALLET_PASSPHRASE_HINT = 'Enter optional passphrase (BIP39)';
const String CREATE_WALLET_PASSPHRASE_WARNING = 'Adding a passphrase creates a different wallet. Keep it safe!';
const String CREATE_WALLET_CONFIRM_BACKUP = 'I have saved my recovery phrase';
const String CREATE_WALLET_CONFIRM_UNDERSTAND = 'I understand that if I lose my recovery phrase, I will lose access to my wallet permanently.';
const String CREATE_WALLET_BTN_CONTINUE = 'Continue';

// Import Wallet Screen UI
const String IMPORT_WALLET_TITLE = 'Import Wallet';
const String IMPORT_WALLET_HEADER = 'Import Your Wallet';
const String IMPORT_WALLET_SUBHEADER = 'Enter your 12 or 24 word recovery phrase to restore your wallet';
const String IMPORT_WALLET_PHRASE_LABEL = 'Recovery Phrase';
const String IMPORT_WALLET_PHRASE_HINT = 'word1 word2 word3 ...';
const String IMPORT_WALLET_PASSPHRASE_NOTE = 'If your wallet uses a passphrase, enter it here.';
const String IMPORT_WALLET_BTN_IMPORT = 'Import Wallet';

// Wallet Metadata Dialog
const String DIALOG_WALLET_SETTINGS_TITLE = 'Wallet Settings';
const String DIALOG_WALLET_NAME_LABEL = 'Wallet Name';
const String DIALOG_WALLET_NAME_HINT = 'My Wallet';
const String DIALOG_AVATAR_LABEL = 'Choose Avatar';
const String DIALOG_BTN_CANCEL = 'Cancel';
const String DIALOG_BTN_SAVE = 'Save';

// Common Messages
const String MSG_COPIED_TO_CLIPBOARD = 'copied to clipboard';
const String MSG_ADDRESS_COPIED = 'Address copied to clipboard';
const String MSG_SEED_COPIED = 'Seed phrase copied to clipboard';
const String MSG_PASSPHRASE_COPIED = 'Passphrase copied to clipboard';
const String ERR_MASTER_PASSWORD_NOT_SET = 'Master password not set. Please unlock first.';
const String ERR_WALLET_NOT_UNLOCKED = 'Wallet is not unlocked. Please unlock your wallet first.';
const String ERR_FAILED_LOAD_STORAGE = 'Failed to load storage data';

// Browser Settings
const String BROWSER_DEFAULT_THEME = 'Dark';
const String BROWSER_DEFAULT_SEARCH_ENGINE = 'Google';
const String BROWSER_TAB_NEW_TITLE = 'New Tab';
const String BROWSER_ERR_ONLY_KAS_DOMAINS = 'Only .kas domains are supported';
const String BROWSER_ERR_INVALID_URL = 'Invalid URL format';


