const appStoreUrl = import.meta.env.PUBLIC_APP_STORE_URL?.trim() || '';
const playStoreUrl =
  import.meta.env.PUBLIC_PLAY_STORE_URL?.trim() ||
  'https://play.google.com/store/apps/details?id=com.clarity.clarity';
const webLoginUrl =
  import.meta.env.PUBLIC_WEB_LOGIN_URL?.trim() || 'https://app.goclarity.app';

export const product = {
  name: 'Clarity',
  assistantName: 'Rex',
  tagline: 'One calm place for money, memory, and Rex.',
  description:
    'Clarity is a privacy-first personal finance and AI assistant app. Connect accounts with consent, track budgets and goals, organize what Clarity knows, and talk to Rex in chat or voice — on iPhone, Android, and web.',
  supportEmail: 'clarity.rex@gmail.com',
  operatorName: 'Clarity',
  siteUrl: 'https://goclarity.app',
  locale: 'en_US',
  socialImagePath: '/og-image.jpg',
  socialImageAlt: 'Clarity dashboard preview — money, memory, and Rex in one calm place.',
} as const;

export const downloadLinks = {
  appStore: appStoreUrl,
  playStore: playStoreUrl,
  webLogin: webLoginUrl,
} as const;

export type PublicRoute = {
  path: string;
  label: string;
  title: string;
  description: string;
  footerRequired: boolean;
};

export const publicRoutes = [
  {
    path: '/',
    label: 'Home',
    title: 'Clarity - Money, Memory, and Rex in One Place',
    description:
      'Meet Clarity: privacy-first finance, budgets, goals, and Rex — the AI assistant inside the app. Available on iPhone, Android, and web.',
    footerRequired: true,
  },
  {
    path: '/privacy',
    label: 'Privacy',
    title: 'Privacy Policy - Clarity',
    description:
      'Learn what Clarity collects, how Plaid-connected data is used, how Rex uses context, and how privacy requests work.',
    footerRequired: true,
  },
  {
    path: '/terms',
    label: 'Terms',
    title: 'Terms of Service - Clarity',
    description:
      'Review Clarity service terms, user responsibilities, AI assistant boundaries, and financial advice limitations.',
    footerRequired: true,
  },
  {
    path: '/security',
    label: 'Security',
    title: 'Security and Data Handling - Clarity',
    description:
      'Understand Clarity security practices, data handling, vendor use, account disconnection, and security contact paths.',
    footerRequired: true,
  },
  {
    path: '/data-deletion',
    label: 'Data Retention and Deletion',
    title: 'Data Retention and Deletion Policy - Clarity',
    description:
      'Review Clarity data retention practices, deletion rights, request timelines, disposal methods, and privacy contact information.',
    footerRequired: true,
  },
  {
    path: '/contact',
    label: 'Contact',
    title: 'Contact - Clarity',
    description:
      'Contact Clarity for product questions, privacy requests, data deletion, or security concerns.',
    footerRequired: true,
  },
  {
    path: '/form-success',
    label: 'Form Success',
    title: 'Request Received - Clarity',
    description:
      'Confirmation that Clarity received a public waitlist, contact, privacy, deletion, or security request.',
    footerRequired: false,
  },
  {
    path: '/form-error',
    label: 'Form Error',
    title: 'Form Error - Clarity',
    description:
      'Fallback information if a Clarity public form could not be submitted.',
    footerRequired: false,
  },
  {
    path: '/auth/confirmed',
    label: 'Email Confirmed',
    title: 'Email Confirmed - Clarity',
    description:
      'Confirmation page shown after a user verifies their Clarity account email address.',
    footerRequired: false,
  },
] satisfies PublicRoute[];

export const headerLinks = publicRoutes.filter((route) =>
  ['/', '/privacy', '/security', '/terms', '/contact'].includes(route.path),
);

export const footerLinks = publicRoutes.filter((route) => route.footerRequired);

export const primaryCta = {
  label: 'Get Clarity',
  href: '/#get-clarity',
} as const;

export const trustNotes = [
  'User-controlled connections through Plaid',
  'Privacy-first design and public data controls',
  'Your data stays yours',
  'No bank credentials collected by Clarity',
] as const;

export const faqs = [
  {
    question: 'Is Clarity a bank?',
    answer:
      'No. Clarity is a personal finance organization and AI assistant experience. It is not a bank, broker, tax advisor, or lender.',
  },
  {
    question: 'How does Clarity connect financial accounts?',
    answer:
      'Clarity is designed to use user-authorized account connections through providers such as Plaid. Users choose what to connect and can disconnect access.',
  },
  {
    question: 'Does Clarity store my bank password?',
    answer:
      'No. Clarity is designed around provider-based account authorization. Users should never send bank credentials, one-time codes, account numbers, or sensitive documents through public forms.',
  },
  {
    question: 'Does Rex replace professional financial advice?',
    answer:
      'No. Rex can help organize context and think through options, but users remain responsible for decisions and should consult qualified professionals when needed.',
  },
  {
    question: 'What can Rex see?',
    answer:
      'Rex can use the context you choose to provide or connect inside Clarity, such as transactions, budgets, goals, approved memory, and conversation history. Access depends on product settings and user authorization.',
  },
  {
    question: 'Can I delete my data?',
    answer:
      'Yes. Clarity publishes a data deletion path and contact route. Some records may be retained for limited legal, security, backup, or operational reasons as described in the Privacy Policy.',
  },
  {
    question: 'Where can I get Clarity?',
    answer:
      'Clarity is available on iPhone, Android, and web. Download from the App Store or Google Play, or sign in on the web with the same Clarity account.',
  },
] as const;

export const formCopy = {
  sensitiveDataWarning:
    'Do not include bank passwords, account numbers, card numbers, SSNs, one-time codes, API keys, screenshots, CSV files, or other sensitive financial details.',
  waitlistConsent:
    'I agree that Clarity may contact me about beta access, product updates, and my request. I understand I should not include bank credentials or sensitive financial details in this form.',
  contactConsent:
    'I agree that Clarity may contact me about this request. I understand I should not include bank credentials or sensitive financial details in this form.',
  success:
    "Thanks. We received your request and will review it through Clarity's published support path.",
  error:
    'We could not submit the form right now. You can also contact Clarity through the published support email.',
} as const;
