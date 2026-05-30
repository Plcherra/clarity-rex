import { product } from '@content/site';

export const GET = () => {
  const siteUrl = new URL(product.siteUrl);
  const sitemapUrl = new URL('/sitemap.xml', siteUrl);

  return new Response(
    [
      'User-agent: *',
      'Allow: /',
      '',
      `Sitemap: ${sitemapUrl.toString()}`,
      '',
    ].join('\n'),
    {
      headers: {
        'Content-Type': 'text/plain; charset=utf-8',
      },
    },
  );
};
