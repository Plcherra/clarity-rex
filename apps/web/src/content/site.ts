export const product = {
  name: 'Clarity',
  assistantName: 'Rex',
  tagline: 'A personal AI financial co-pilot with Rex inside.',
  description:
    'Clarity helps people understand spending, budgets, goals, and financial context using user-authorized account connections.',
  supportEmail: 'clarity.rex@gmail.com',
  operatorName: 'Clarity',
  siteUrl: 'https://rexpilot.com',
  locale: 'en_US',
  socialImagePath: '/og-image.jpg',
  socialImageAlt: 'Clarity personal AI financial co-pilot landing page preview.',
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
    title: 'Clarity - Personal AI Financial Co-Pilot',
    description:
      'Meet Clarity, a personal AI financial co-pilot that helps organize spending, budgets, goals, and financial decisions with Rex inside.',
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
    label: 'Data Deletion',
    title: 'Data Deletion - Clarity',
    description:
      'Request deletion of Clarity account data or learn how to disconnect financial account access.',
    footerRequired: true,
  },
  {
    path: '/contact',
    label: 'Contact',
    title: 'Contact - Clarity',
    description:
      'Contact Clarity for product questions, beta access, privacy requests, data deletion, or security concerns.',
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
] satisfies PublicRoute[];

export const headerLinks = publicRoutes.filter((route) =>
  ['/', '/privacy', '/security', '/contact'].includes(route.path),
);

export const footerLinks = publicRoutes.filter((route) => route.footerRequired);

export const primaryCta = {
  label: 'Request early access',
  href: '/#request-access',
} as const;

export const trustNotes = [
  'User-authorized account connections only.',
  'Clear privacy, security, and deletion paths.',
  'Rex is an assistant inside Clarity, not a bank or financial advisor.',
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
    question: 'Does Rex replace professional financial advice?',
    answer:
      'No. Rex can help organize context and think through options, but users remain responsible for decisions and should consult qualified professionals when needed.',
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
