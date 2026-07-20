import { RootProvider } from 'fumadocs-ui/provider/next';
import './global.css';
import type { Metadata } from 'next';

const siteUrl = process.env.NEXT_PUBLIC_SITE_URL ?? 'http://localhost:3000';

export const metadata: Metadata = {
  metadataBase: new URL(siteUrl),
  title: {
    default: 'ClashBar 文档',
    template: '%s | ClashBar',
  },
  description: 'ClashBar：面向 macOS 菜单栏的 Mihomo 客户端。',
  icons: {
    icon: [{ url: '/clashbar-logo.ico', type: 'image/x-icon' }],
    shortcut: '/clashbar-logo.ico',
  },
};

export default function Layout({ children }: LayoutProps<'/'>) {
  return (
    <html lang="zh-CN" className="antialiased" suppressHydrationWarning>
      <body className="flex min-h-screen flex-col font-sans">
        <RootProvider>{children}</RootProvider>
      </body>
    </html>
  );
}
