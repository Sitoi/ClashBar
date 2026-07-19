import type { BaseLayoutProps } from 'fumadocs-ui/layouts/shared';
import Image from 'next/image';
import { appName, gitConfig } from './shared';

export function baseOptions(): BaseLayoutProps {
  return {
    nav: {
      title: (
        <span className="flex items-center gap-2.5 font-semibold tracking-tight">
          <Image
            src="/clashbar-logo.png"
            alt=""
            width={24}
            height={24}
            priority
            className="rounded-[6px]"
          />
          <span className="text-[15px]">{appName}</span>
          <span className="hidden rounded-md border border-fd-border bg-fd-muted/50 px-1.5 py-0.5 text-[10px] font-medium uppercase tracking-wider text-fd-muted-foreground sm:inline">
            Docs
          </span>
        </span>
      ),
    },
    links: [
      {
        text: '快速开始',
        url: '/docs/quick-start',
        active: 'nested-url',
      },
      {
        text: '功能总览',
        url: '/docs/features',
        active: 'nested-url',
      },
      {
        text: '关于',
        url: '/docs/about',
        active: 'nested-url',
      },
    ],
    githubUrl: `https://github.com/${gitConfig.user}/${gitConfig.repo}`,
  };
}
