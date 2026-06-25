const LOGO_URL = "https://goclarity.app/clarity-mark-96.png";
const SUPPORT_EMAIL = "clarity.rex@gmail.com";

type BrandedEmail = {
  eyebrow: string;
  title: string;
  preview: string;
  bodyHtml: string;
  ctaLabel: string;
  ctaHref?: string;
  footerNote: string;
};

export function clarityBrandedEmailHtml(email: BrandedEmail): string {
  const ctaBlock = email.ctaHref
    ? `
      <tr>
        <td style="padding:0 32px 28px;text-align:center;">
          <a href="${email.ctaHref}" style="display:inline-block;background:#081827;color:#ffffff;text-decoration:none;font-size:16px;font-weight:800;line-height:1;padding:15px 28px;border-radius:8px;box-shadow:0 12px 26px rgba(8,24,39,0.14);">
            ${email.ctaLabel}
          </a>
        </td>
      </tr>`
    : "";

  return `<!DOCTYPE html>
<html lang="en">
  <body style="margin:0;padding:0;background:#f5f9fd;color:#17202a;font-family:Inter,-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">
    <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background:#f5f9fd;padding:32px 16px;">
      <tr>
        <td align="center">
          <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:560px;background:#ffffff;border:1px solid #dbe3ea;border-radius:12px;overflow:hidden;box-shadow:0 18px 55px rgba(23,32,42,0.08);">
            <tr>
              <td style="padding:28px 32px 18px;text-align:center;background:linear-gradient(180deg,#f7fbff 0%,#ffffff 100%);">
                <img src="${LOGO_URL}" width="56" height="56" alt="Clarity" style="display:block;margin:0 auto 14px;border-radius:10px;" />
                <p style="margin:0;color:#887900;font-size:12px;font-weight:800;letter-spacing:0.04em;text-transform:uppercase;">${email.eyebrow}</p>
                <h1 style="margin:10px 0 0;color:#081827;font-size:28px;line-height:1.15;font-weight:900;">${email.title}</h1>
              </td>
            </tr>
            <tr>
              <td style="padding:8px 32px 0;">
                <p style="margin:0 0 16px;color:#667085;font-size:16px;line-height:1.65;">${email.preview}</p>
                ${email.bodyHtml}
              </td>
            </tr>
            ${ctaBlock}
            <tr>
              <td style="padding:20px 32px 24px;border-top:1px solid #dbe3ea;background:#fbfaf6;">
                <p style="margin:0 0 8px;color:#667085;font-size:12px;line-height:1.55;">${email.footerNote}</p>
                <p style="margin:0;color:#667085;font-size:12px;line-height:1.55;">
                  Questions? Contact us at
                  <a href="mailto:${SUPPORT_EMAIL}" style="color:#1d4ed8;text-decoration:none;">${SUPPORT_EMAIL}</a>
                </p>
              </td>
            </tr>
          </table>
          <p style="margin:18px 0 0;color:#667085;font-size:12px;line-height:1.5;">Clarity · Personal AI financial co-pilot</p>
        </td>
      </tr>
    </table>
  </body>
</html>`;
}
