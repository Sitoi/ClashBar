import Image from 'next/image'
import Link from 'next/link'

export default function Layout({ children }: LayoutProps<'/'>) {
  return (
    <div className="relative min-h-screen bg-[#030712] text-slate-50 antialiased">
      {/* Global ambient background — continuous across the whole home page */}
      <div
        aria-hidden="true"
        className="pointer-events-none fixed inset-0 overflow-hidden"
      >
        <div className="absolute inset-0 bg-[#030712]" />
        <div className="absolute inset-0 bg-[radial-gradient(ellipse_80%_50%_at_50%_-10%,rgba(56,189,248,0.14),transparent_55%)]" />
        <div className="absolute inset-0 bg-[radial-gradient(ellipse_60%_40%_at_100%_30%,rgba(99,102,241,0.10),transparent_50%)]" />
        <div className="absolute inset-0 bg-[radial-gradient(ellipse_50%_35%_at_0%_70%,rgba(56,189,248,0.08),transparent_50%)]" />
        <div className="absolute inset-0 bg-[radial-gradient(ellipse_55%_40%_at_80%_90%,rgba(129,140,248,0.08),transparent_55%)]" />
        <div className="clashbar-drift absolute -left-[20rem] top-[-12rem] size-[46rem] rounded-full bg-sky-400/[0.10] blur-[120px]" />
        <div className="clashbar-drift absolute -right-[18rem] top-[18%] size-[40rem] rounded-full bg-indigo-500/[0.11] blur-[130px]" />
        <div className="clashbar-drift absolute -left-[14rem] top-[52%] size-[36rem] rounded-full bg-cyan-400/[0.07] blur-[120px]" />
        <div className="clashbar-drift absolute -right-[12rem] top-[78%] size-[34rem] rounded-full bg-violet-500/[0.08] blur-[120px]" />
        <div className="absolute inset-0 bg-[linear-gradient(rgba(255,255,255,0.025)_1px,transparent_1px),linear-gradient(90deg,rgba(255,255,255,0.025)_1px,transparent_1px)] bg-[size:64px_64px] opacity-40 [mask-image:radial-gradient(ellipse_at_center,black_20%,transparent_75%)]" />
      </div>

      <header className="fixed inset-x-0 top-0 z-50 px-4 pt-3 sm:px-6 lg:px-8">
        <div className="mx-auto flex h-14 max-w-[1200px] items-center justify-between rounded-2xl border border-white/10 bg-slate-950/75 px-3.5 shadow-[0_8px_32px_-12px_rgba(0,0,0,0.75)] backdrop-blur-2xl sm:px-5">
          <Link
            href="/"
            className="flex items-center gap-2.5 text-[15px] font-semibold tracking-tight text-white transition-opacity hover:opacity-80"
          >
            <Image
              src="/clashbar-logo.png"
              alt="ClashBar"
              width={28}
              height={28}
              priority
            />
            <span>ClashBar</span>
          </Link>

          <nav
            aria-label="主导航"
            className="hidden items-center gap-1 text-sm font-medium text-slate-400 md:flex"
          >
            <a
              href="#features"
              className="rounded-lg px-3 py-1.5 transition-colors hover:bg-white/[0.05] hover:text-white"
            >
              功能
            </a>
            <a
              href="#quick-start"
              className="rounded-lg px-3 py-1.5 transition-colors hover:bg-white/[0.05] hover:text-white"
            >
              快速开始
            </a>
            <Link
              href="/docs"
              className="rounded-lg px-3 py-1.5 transition-colors hover:bg-white/[0.05] hover:text-white"
            >
              文档
            </Link>
          </nav>

          <div className="flex items-center gap-2">
            <a
              href="https://github.com/Sitoi/ClashBar"
              className="hidden items-center rounded-lg border border-white/10 px-3 py-1.5 text-xs font-medium text-slate-300 transition hover:border-white/20 hover:text-white sm:inline-flex"
            >
              GitHub
            </a>
            <a
              href="https://github.com/Sitoi/ClashBar/releases"
              className="inline-flex items-center gap-2 rounded-lg bg-white px-3.5 py-1.5 text-xs font-semibold text-slate-950 shadow-[0_0_20px_rgba(125,211,252,0.15)] transition hover:bg-sky-50"
            >
              <span className="size-1.5 rounded-full bg-emerald-500" />
              下载
            </a>
          </div>
        </div>
      </header>

      <div className="relative z-10 pt-[4.75rem]">{children}</div>
    </div>
  )
}
