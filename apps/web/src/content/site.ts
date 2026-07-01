const appStoreUrl = import.meta.env.PUBLIC_APP_STORE_URL?.trim() || '';
const playStoreUrl =
  import.meta.env.PUBLIC_PLAY_STORE_URL?.trim() ||
  'https://play.google.com/store/apps/details?id=com.clarity.clarity';
const webLoginUrl =
  import.meta.env.PUBLIC_WEB_LOGIN_URL?.trim() || 'https://goclarity.app/app/';

export const product = {
  name: 'Clarity',
  assistantName: 'Rex',
  tagline: 'One calm place for money, memory, and Rex.',
  oneLiner:
    'Personal finance, budgets, and durable memory — with Rex, the assistant that explains your picture from real data, not guesses.',
  description:
    'Connect accounts, track budgets, and talk to Rex on web, iPhone, and Android. One calm workspace for your money and what matters.',
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
    title: 'Clarity — Money, Memory, and Rex',
    description: product.description,
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
      'Confirmation that Clarity received a public contact, privacy, deletion, or security request.',
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

export const headerLinks = (
  ['/privacy', '/security', '/terms', '/contact'] as const
).map((path) => publicRoutes.find((route) => route.path === path)!);

export const footerLinks = publicRoutes.filter((route) => route.footerRequired);

export const primaryCta = {
  label: 'Open Clarity',
  href: downloadLinks.webLogin,
} as const;

export const subscriptionValue = {
  headline: 'Finance and Rex — one subscription, one workspace.',
  subhead:
    'Stop juggling a money app, notes app, and a generic chatbot. Clarity keeps the numbers, memory, and assistant in sync.',
  columns: [
    {
      title: 'Your money picture',
      body: 'Balances, cash flow, budgets, and transactions — updated from accounts you connect.',
    },
    {
      title: 'Memory that stays organized',
      body: 'People, goals, events, and preferences — separate from chat history.',
    },
    {
      title: 'Rex when you need context',
      body: 'Chat and voice on the same data you see in the app.',
    },
  ],
  pricingNote:
    'Start on web today. Subscription activates with your account when billing goes live — no surprise charges on the marketing site.',
} as const;

export const howItWorksSteps = [
  {
    title: 'Create your account on web',
    body: 'Sign up at goclarity.app in minutes. Download on iPhone or Android when store links are live — same login everywhere.',
  },
  {
    title: 'Connect accounts with consent',
    body: 'Link banks through Plaid when you choose. Clarity never asks for your bank password.',
  },
  {
    title: 'Review your month and talk to Rex',
    body: 'Dashboard, budgets, Knows, and Rex share one source of truth on phone and web.',
  },
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
      'Clarity uses user-authorized account connections through Plaid. You choose what to connect and can disconnect at any time. See our Security page for details.',
  },
  {
    question: 'Does Clarity store my bank password?',
    answer:
      'No. Authorization goes through Plaid. Never send bank credentials, one-time codes, or account numbers through public forms or chat.',
  },
  {
    question: 'Does Rex replace professional financial advice?',
    answer:
      'No. Rex helps organize context and explain your picture from connected data. You remain responsible for decisions — consult qualified professionals when needed.',
  },
  {
    question: 'What can Rex see?',
    answer:
      'Rex uses the context you connect or save inside Clarity: transactions, budgets, goals, saved memory, and conversation history. Rex does not move money or guess balances.',
  },
  {
    question: 'Can I delete my data?',
    answer:
      'Yes. Use our data deletion page or contact support. Some records may be retained for limited legal, security, or operational reasons as described in the Privacy Policy.',
  },
] as const;

export const formCopy = {
  sensitiveDataWarning:
    'Do not include bank passwords, account numbers, card numbers, SSNs, one-time codes, API keys, screenshots, CSV files, or other sensitive financial details.',
  waitlistConsent:
    'I agree that Clarity may contact me about product updates and my request. I understand I should not include bank credentials or sensitive financial details in this form.',
  contactConsent:
    'I agree that Clarity may contact me about this request. I understand I should not include bank credentials or sensitive financial details in this form.',
  success:
    "Thanks. We received your request and will review it through Clarity's published support path.",
  error:
    'We could not submit the form right now. You can also contact Clarity through the published support email.',
} as const;
