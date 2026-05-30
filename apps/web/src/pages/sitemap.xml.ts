import { product, publicRoutes } from '@content/site';

const sitemapRoutes = publicRoutes.filter((route) =>
  ['/', '/privacy', '/terms', '/security', '/data-deletion', '/contact'].includes(route.path),
);

export const GET = () => {
  const siteUrl = new URL(product.siteUrl);
  const urls = sitemapRoutes.map((route) => {
    const url = new URL(route.path, siteUrl);

    return [
      '  <url>',
      `    <loc>${url.toString()}</loc>`,
      '    <changefreq>monthly</changefreq>',
      '  </url>',
    ].join('\n');
  });

  const body = [
    '<?xml version="1.0" encoding="UTF-8"?>',
    '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">',
    ...urls,
    '</urlset>',
    '',
  ].join('\n');

  return new Response(body, {
    headers: {
      'Content-Type': 'application/xml; charset=utf-8',
    },
  });
};
