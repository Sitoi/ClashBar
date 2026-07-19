# ClashBar 文档站

ClashBar 的中文产品落地页与使用文档，基于 Next.js 和 Fumadocs 构建。

## 本地开发

需要 Node.js 与 pnpm。

    pnpm install
    pnpm dev

随后在浏览器打开 http://localhost:3000。

## 常用命令

- `pnpm dev`：启动开发服务器（Next 16 + Turbopack）。
- `pnpm types:check`：生成 MDX/路由类型并执行 TypeScript 检查。
- `pnpm build`：生成生产构建。
- `pnpm start`：运行生产服务器。

> **Note:** `fumadocs-mdx` 的 webpack loader 是 ESM-only。`loaders/fumadocs-mdx-*.cjs` 提供 CJS 桥接，避免 Turbopack `require()` ESM 报错。

## 内容与结构

- `app/(home)/page.tsx`：产品落地页。
- `content/docs/`：中文 MDX 使用文档和导航元数据。
- `lib/layout.shared.tsx`：站点导航、品牌与 GitHub 链接。
- `app/api/search/route.ts`：基于 Orama 的本地文档搜索。

部署时请设置 `NEXT_PUBLIC_SITE_URL` 为站点公开地址，以正确生成绝对 Open Graph 链接。
