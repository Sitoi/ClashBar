import {
  ArrowRight,
  BookOpen,
  Check,
  Download,
  Gauge,
  GitBranch,
  MonitorSmartphone,
  Server,
  Settings2,
  ShieldCheck,
  Zap,
} from 'lucide-react'
import Image from 'next/image'
import Link from 'next/link'

const highlights = [
  { label: '安装包体积', value: '2.7 MB', hint: '无 Core 构建约数' },
  { label: '含 Core 体积', value: '≈14 MB', hint: '打包 mihomo 目标 <15 MB' },
  { label: '代理内核', value: 'mihomo', hint: 'Meta 生态兼容' },
  { label: '系统要求', value: 'macOS 13+', hint: 'Homebrew / DMG 安装' },
]

const pillars = [
  {
    icon: <Zap className="size-5" />,
    title: '菜单栏即控制台',
    description:
      '配置、节点、系统代理与排障视图收进一个紧凑的原生面板，点击菜单栏图标即可完成日常操作。',
  },
  {
    icon: <Gauge className="size-5" />,
    title: '轻量常驻',
    description:
      '安装包约 2.7 MB，零第三方依赖，专注低占用与稳定运行，不把菜单栏工具做成重型桌面套件。',
  },
  {
    icon: <GitBranch className="size-5" />,
    title: 'mihomo 驱动',
    description:
      '基于 mihomo 内核，支持本地 YAML、远程订阅、系统代理与 TUN，覆盖从入门到进阶的接管路径。',
  },
]

const quickSteps = [
  {
    title: '清理冲突客户端',
    body: '先退出其他 mihomo / Clash 系客户端，避免系统代理、端口或后台辅助进程互相覆盖。',
  },
  {
    title: '完成首次启动',
    body: '首次启动时，先用默认配置启动一次，让 mihomo 完成所需资源准备。',
  },
  {
    title: '导入节点配置',
    body: '在“节点”页面选择或导入本地 YAML、远程订阅配置。',
  },
  {
    title: '启动或重启内核',
    body: '启动内核；刚替换配置或内核时，使用“重启内核”。',
  },
  {
    title: '验证线路可用性',
    body: '在节点分组中选择节点并执行延迟测试，先确认线路可用。',
  },
  {
    title: '开启系统代理',
    body: '确认连通性正常后再开启系统代理；若开关无反应，请检查“登录项”中的后台活动。',
  },
]

const bentoCard =
  'bento-card relative flex flex-col overflow-hidden rounded-3xl border border-white/10 bg-gradient-to-b from-white/[0.055] to-white/[0.015] p-4 transition duration-200 hover:border-white/15'

function ShortcutKey({ children }: { children: string }) {
  return (
    <kbd className="inline-flex items-center justify-center rounded-md border border-white/10 bg-black/45 px-1.5 py-0.5 font-mono text-[10px] font-semibold leading-none tracking-wide text-slate-300 shadow-[inset_0_1px_rgba(255,255,255,0.06)]">
      {children}
    </kbd>
  )
}

export default function HomePage() {
  return (
    <main className="relative">
      {/* Hero */}
      <section className="relative mx-auto grid max-w-[1200px] items-center gap-14 px-6 pb-16 pt-16 sm:px-8 lg:grid-cols-[minmax(0,1.05fr)_minmax(380px,0.95fr)] lg:gap-12 lg:pb-24 lg:pt-24">
        <div className="max-w-xl">
          <p className="mb-6 inline-flex items-center gap-2 rounded-full border border-white/10 bg-white/[0.04] px-3.5 py-1.5 text-xs font-medium text-slate-300 shadow-[inset_0_1px_rgba(255,255,255,0.06)]">
            <span className="flex size-5 items-center justify-center rounded-full bg-sky-400/15 text-sky-300">
              <MonitorSmartphone className="size-3" />
            </span>
            原生 macOS 菜单栏代理客户端
          </p>

          <h1 className="text-balance text-[clamp(2.75rem,5.5vw,4.25rem)] font-semibold leading-[1.05] tracking-[-0.045em] text-white">
            轻量、稳定、够用
            <span className="mt-2 block bg-[linear-gradient(120deg,#f8fafc_0%,#7dd3fc_45%,#a5b4fc_100%)] bg-clip-text text-transparent">
              菜单栏一开就能接管流量
            </span>
          </h1>

          <p className="mt-6 max-w-lg text-pretty text-base leading-7 text-slate-400 sm:text-lg sm:leading-8">
            ClashBar 基于 mihomo
            构建，把配置导入、节点切换、系统代理与排障视图收进一个紧凑的原生面板——专注日常使用，而不是堆功能。
          </p>

          <div className="mt-9 flex flex-col gap-3 sm:flex-row sm:items-center">
            <a
              href="https://github.com/Sitoi/ClashBar/releases"
              className="group inline-flex h-12 items-center justify-center gap-2 rounded-xl bg-white px-7 text-sm font-semibold text-slate-950 shadow-[0_0_0_1px_rgba(255,255,255,0.08),0_12px_40px_-8px_rgba(56,189,248,0.45)] transition duration-200 hover:-translate-y-0.5 hover:bg-sky-50"
            >
              <Download className="size-4 transition group-hover:scale-110" />
              下载最新版本
            </a>
            <div className="flex gap-3">
              <a
                href="https://github.com/Sitoi/ClashBar"
                className="inline-flex h-12 flex-1 items-center justify-center gap-2 rounded-xl border border-white/10 bg-white/[0.03] px-5 text-sm font-medium text-white transition duration-200 hover:border-white/20 hover:bg-white/[0.07] sm:flex-none sm:px-6"
              >
                GitHub
                <ArrowRight className="size-4 opacity-60" />
              </a>
              <Link
                href="/docs"
                className="inline-flex h-12 flex-1 items-center justify-center gap-2 rounded-xl border border-white/10 bg-white/[0.03] px-5 text-sm font-medium text-slate-200 transition duration-200 hover:border-white/20 hover:bg-white/[0.07] sm:flex-none sm:px-6"
              >
                <BookOpen className="size-4 opacity-70" />
                文档
              </Link>
            </div>
          </div>

          <ul className="mt-8 flex flex-wrap gap-x-5 gap-y-2.5 text-sm text-slate-400">
            {['SwiftUI + AppKit', '零第三方依赖', 'GPL-3.0 开源'].map(
              (item) => (
                <li
                  key={item}
                  className="flex items-center gap-2"
                >
                  <Check
                    className="size-3.5 text-sky-400"
                    strokeWidth={2.5}
                  />
                  {item}
                </li>
              ),
            )}
          </ul>
        </div>

        <div className="relative mx-auto w-full max-w-[460px] py-6 lg:ml-auto lg:py-0">
          <div
            aria-hidden="true"
            className="absolute inset-[6%] rounded-[2.5rem] bg-[conic-gradient(from_200deg_at_50%_50%,rgba(56,189,248,0.35),rgba(129,140,248,0.22),rgba(52,211,153,0.12),rgba(56,189,248,0.35))] opacity-50 blur-[56px]"
          />
          <div
            aria-hidden="true"
            className="absolute inset-[10%] rounded-[2rem] border border-white/10 bg-sky-400/[0.03]"
          />

          <div className="clashbar-float absolute -left-2 top-[18%] z-20 hidden rounded-2xl border border-white/10 bg-slate-950/80 px-3.5 py-2.5 shadow-2xl backdrop-blur-xl sm:left-0 lg:block">
            <span className="flex items-center gap-2 text-[10px] font-semibold tracking-[0.14em] text-slate-400">
              <span className="size-1.5 rounded-full bg-emerald-400 shadow-[0_0_10px_rgba(52,211,153,0.9)]" />
              SYSTEM ONLINE
            </span>
            <span className="mt-1.5 block font-mono text-sm font-semibold text-white">
              127.0.0.1:7890
            </span>
          </div>

          <div className="clashbar-float-delayed absolute bottom-[12%] -right-1 z-20 hidden rounded-2xl border border-white/10 bg-slate-950/80 px-3.5 py-2.5 shadow-2xl backdrop-blur-xl sm:right-0 lg:block">
            <span className="block text-[10px] font-semibold tracking-[0.14em] text-slate-400">
              INSTALL SIZE
            </span>
            <span className="mt-1 block text-xl font-semibold tracking-tight text-sky-200">
              2.7{' '}
              <span className="text-xs font-medium tracking-normal text-sky-300/80">
                MB
              </span>
            </span>
          </div>

          <Image
            src="/clashbar-dark.png"
            alt="ClashBar 深色菜单栏界面"
            width={812}
            height={1580}
            priority
            className="relative z-10 mx-auto h-auto max-h-[640px] w-auto max-w-full rounded-[1.75rem] object-contain drop-shadow-[0_28px_56px_rgba(0,0,0,0.75)]"
          />
        </div>
      </section>

      {/* Proof strip */}
      <section className="relative border-y border-white/[0.06]">
        <div className="mx-auto grid max-w-[1200px] grid-cols-2 divide-x divide-y divide-white/[0.06] sm:grid-cols-4 sm:divide-y-0">
          {highlights.map((item) => (
            <div
              key={item.label}
              className="px-6 py-7 text-center sm:px-4 lg:px-8"
            >
              <p className="text-[11px] font-medium uppercase tracking-[0.16em] text-slate-500">
                {item.label}
              </p>
              <p className="mt-2 text-xl font-semibold tracking-tight text-white sm:text-2xl">
                {item.value}
              </p>
              <p className="mt-1 text-xs text-slate-500">{item.hint}</p>
            </div>
          ))}
        </div>
      </section>

      {/* Pillars */}
      <section className="relative mx-auto max-w-[1200px] px-6 py-20 sm:px-8 lg:py-24">
        <SectionHeading
          eyebrow="为什么选择 ClashBar"
          title="为菜单栏而生的代理体验"
          description="不做重型套件，只把日常最常用的能力做好、做稳、做轻。"
        />
        <div className="grid gap-4 md:grid-cols-3">
          {pillars.map((pillar) => (
            <article
              key={pillar.title}
              className="group relative overflow-hidden rounded-2xl border border-white/[0.08] bg-gradient-to-b from-white/[0.05] to-white/[0.015] p-6 transition duration-300 hover:border-white/15 hover:from-white/[0.07]"
            >
              <div className="flex size-10 items-center justify-center rounded-xl border border-sky-400/20 bg-sky-400/10 text-sky-300">
                {pillar.icon}
              </div>
              <h3 className="mt-5 text-lg font-semibold tracking-tight text-white">
                {pillar.title}
              </h3>
              <p className="mt-2.5 text-sm leading-6 text-slate-400">
                {pillar.description}
              </p>
            </article>
          ))}
        </div>
      </section>

      {/* Features — 8-col bento (aligned with main site index.html) */}
      <section
        id="features"
        className="relative mx-auto max-w-[1200px] scroll-mt-24 px-5 py-16 sm:px-8 lg:py-20"
      >
        <div className="mb-8 flex flex-col gap-3 sm:flex-row sm:items-end sm:justify-between">
          <div className="min-w-0 max-w-2xl">
            <p className="text-xs font-semibold tracking-[0.16em] text-sky-300/90">
              功能概览
            </p>
            <h2 className="mt-2 text-3xl font-semibold tracking-[-0.03em] text-white sm:text-4xl">
              原生菜单栏控制台
            </h2>
            <p className="mt-2.5 text-sm leading-6 text-slate-400">
              节点 · 分流 · 连接 · 日志 ·
              设置，以及系统代理、TUN、订阅与远程管理——一屏扫完。
            </p>
          </div>
          <Link
            href="/docs/features"
            className="inline-flex shrink-0 items-center gap-1.5 self-start rounded-xl border border-sky-400/20 bg-sky-400/10 px-4 py-2 text-sm font-semibold text-sky-200 transition hover:bg-sky-400/15 sm:self-auto"
          >
            功能总览
            <ArrowRight className="size-4" />
          </Link>
        </div>

        {/*
          Desktop 8-col × 4-row bento (auto-rows min 112px):
          Row1-2: Runtime(4×2) | Conn(1×2) | Rules(3×2)
          Row3-4: Mode(2×2) | Nodes(2×2) | Proxy(1) TUN(1) Logs(2)
                               Core+Config(2) Remote(2)
        */}
        <div
          className="bento-grid grid auto-rows-[minmax(112px,auto)] grid-cols-1 gap-3 md:grid-cols-2 lg:grid-cols-8"
          aria-label="ClashBar 功能展示"
        >
          {/* 1. 运行态指标 4×2 */}
          <article
            className={`${bentoCard} justify-between md:col-span-2 md:row-span-2 lg:col-span-4 lg:col-start-1 lg:row-span-2 lg:row-start-1`}
          >
            <div
              aria-hidden="true"
              className="pointer-events-none absolute -left-20 -top-20 size-64 rounded-full bg-sky-400/20 blur-[80px]"
            />
            <div className="relative z-10">
              <h3 className="mb-0.5 text-base font-semibold tracking-tight text-white">
                运行态指标
              </h3>
              <p className="max-w-none text-[12px] leading-snug text-slate-400 sm:whitespace-nowrap">
                在菜单栏和面板同时看到上/下行速率、连接数、内存占用和当前模式。
              </p>
            </div>
            <div className="relative z-10 mt-2.5">
              <div className="mb-2 grid grid-cols-2 gap-2">
                <div className="rounded-xl border border-white/5 bg-black/40 p-2">
                  <strong className="block text-lg font-bold text-white">
                    1.2{' '}
                    <span className="text-xs font-medium text-slate-500">
                      MB/s
                    </span>
                  </strong>
                  <span className="mt-0.5 block text-[10px] uppercase tracking-wider text-slate-500">
                    实时速率
                  </span>
                </div>
                <div className="rounded-xl border border-white/5 bg-black/40 p-2">
                  <strong className="block text-lg font-bold text-white">
                    48.2{' '}
                    <span className="text-xs font-medium text-slate-500">
                      MB
                    </span>
                  </strong>
                  <span className="mt-0.5 block text-[10px] uppercase tracking-wider text-slate-500">
                    内存占用
                  </span>
                </div>
              </div>
              <div
                className="runtime-chart"
                aria-hidden="true"
              >
                <svg
                  viewBox="0 0 240 92"
                  fill="none"
                  xmlns="http://www.w3.org/2000/svg"
                  preserveAspectRatio="none"
                >
                  <path
                    d="M10 70C22 62 34 46 46 44C58 42 70 54 82 49C94 44 106 22 118 24C130 26 142 40 154 38C166 36 178 18 190 20C202 22 214 34 230 28V92H10V70Z"
                    fill="url(#runtime-download-fill)"
                  />
                  <path
                    d="M10 80C22 76 34 68 46 66C58 64 70 72 82 70C94 68 106 56 118 58C130 60 142 66 154 64C166 62 178 48 190 50C202 52 214 62 230 58V92H10V80Z"
                    fill="url(#runtime-upload-fill)"
                  />
                  <polyline
                    points="10,70 46,44 82,49 118,24 154,38 190,20 230,28"
                    stroke="#38BDF8"
                    strokeWidth="3"
                    strokeLinecap="round"
                    strokeLinejoin="round"
                  />
                  <polyline
                    points="10,80 46,66 82,70 118,58 154,64 190,50 230,58"
                    stroke="#34D399"
                    strokeWidth="3"
                    strokeLinecap="round"
                    strokeLinejoin="round"
                  />
                  <circle
                    cx="190"
                    cy="20"
                    r="4"
                    fill="#38BDF8"
                  />
                  <circle
                    cx="190"
                    cy="20"
                    r="8"
                    fill="#38BDF8"
                    fillOpacity="0.12"
                  />
                  <circle
                    cx="190"
                    cy="50"
                    r="4"
                    fill="#34D399"
                  />
                  <circle
                    cx="190"
                    cy="50"
                    r="8"
                    fill="#34D399"
                    fillOpacity="0.12"
                  />
                  <defs>
                    <linearGradient
                      id="runtime-download-fill"
                      x1="0"
                      y1="18"
                      x2="0"
                      y2="92"
                      gradientUnits="userSpaceOnUse"
                    >
                      <stop
                        stopColor="#38BDF8"
                        stopOpacity="0.25"
                      />
                      <stop
                        offset="1"
                        stopColor="#38BDF8"
                        stopOpacity="0"
                      />
                    </linearGradient>
                    <linearGradient
                      id="runtime-upload-fill"
                      x1="0"
                      y1="44"
                      x2="0"
                      y2="92"
                      gradientUnits="userSpaceOnUse"
                    >
                      <stop
                        stopColor="#34D399"
                        stopOpacity="0.2"
                      />
                      <stop
                        offset="1"
                        stopColor="#34D399"
                        stopOpacity="0"
                      />
                    </linearGradient>
                  </defs>
                </svg>
                <div className="runtime-chart-legend">
                  <span className="runtime-chart-series">
                    <span className="runtime-chart-dot download" />
                    下行
                  </span>
                  <span className="runtime-chart-series">
                    <span className="runtime-chart-dot upload" />
                    上行
                  </span>
                </div>
              </div>
              <div className="mt-2 flex items-center justify-between border-t border-white/5 pt-2 text-[10px] font-semibold uppercase tracking-wider text-slate-500">
                <span className="flex items-center gap-2">
                  <span className="size-1.5 rounded-full bg-sky-400 shadow-[0_0_8px_rgba(56,189,248,0.7)]" />
                  42 Connections
                </span>
                <span>Rule Mode</span>
              </div>
            </div>
          </article>

          {/* 2. 连接排障 1×2 */}
          <article
            className={`${bentoCard} justify-between md:col-span-1 md:row-span-2 lg:col-span-1 lg:col-start-5 lg:row-span-2 lg:row-start-1`}
          >
            <div
              aria-hidden="true"
              className="pointer-events-none absolute -bottom-10 -right-10 size-40 rounded-full bg-red-500/10 blur-[60px]"
            />
            <div>
              <h3 className="mb-0.5 text-base font-semibold tracking-tight text-white">
                连接排障
              </h3>
              <p className="text-[12px] leading-snug text-slate-400">
                观察活动连接，并按需关闭单个或全部连接。
              </p>
            </div>
            <div className="my-2 flex flex-1 items-center justify-center">
              <div className="audit-pulse scale-100" />
            </div>
            <div className="relative z-10 rounded-xl border border-red-500/20 bg-red-500/10 p-2 text-center backdrop-blur-md">
              <strong className="block text-sm font-bold leading-none text-red-400">
                128 Active
              </strong>
            </div>
          </article>

          {/* 3. 规则视图 3×2 */}
          <article
            className={`${bentoCard} group md:col-span-1 md:row-span-2 lg:col-span-3 lg:col-start-6 lg:row-span-2 lg:row-start-1`}
          >
            <div
              aria-hidden="true"
              className="pointer-events-none absolute -bottom-16 -right-16 size-56 rounded-full bg-indigo-400/10 blur-[72px]"
            />
            <div className="relative z-10 shrink-0">
              <h3 className="mb-0.5 text-base font-semibold tracking-tight text-white">
                规则视图
              </h3>
              <p className="text-[12px] leading-snug text-slate-400">
                快速查看规则总数、命中分布和常用规则类型。
              </p>
            </div>
            <div className="relative z-10 mt-2.5 flex min-h-0 flex-1 flex-col gap-2">
              <div className="flex min-h-0 flex-1 flex-col justify-center rounded-2xl border border-white/10 bg-black/30 p-3">
                <div className="flex items-end justify-between gap-3">
                  <div>
                    <strong className="text-3xl font-black leading-none tracking-tighter text-white sm:text-4xl">
                      4,285
                    </strong>
                    <div className="mt-1.5 text-[10px] font-semibold uppercase tracking-[0.18em] text-slate-500">
                      规则总数
                    </div>
                  </div>
                  <div
                    className="rule-stack flex h-14 w-[4.5rem] shrink-0 items-end gap-1 opacity-80"
                    aria-hidden="true"
                  >
                    <span />
                    <span />
                    <span />
                    <span />
                    <span />
                  </div>
                </div>
              </div>
              <div className="grid shrink-0 grid-cols-1 gap-1.5 sm:grid-cols-3">
                <div className="rounded-xl border border-white/[0.08] bg-white/[0.03] p-2">
                  <div className="flex items-center justify-between gap-1 text-[9px] text-slate-500">
                    <span className="flex items-center gap-1.5">
                      <span className="size-1.5 rounded-full bg-emerald-400" />
                      DIRECT
                    </span>
                    <span className="text-[10px] font-bold text-white">
                      1.2k
                    </span>
                  </div>
                  <div className="mt-1.5 h-1.5 w-full overflow-hidden rounded-full bg-white/5">
                    <div
                      className="h-full rounded-full bg-emerald-400"
                      style={{ width: '28%' }}
                    />
                  </div>
                </div>
                <div className="rounded-xl border border-white/[0.08] bg-white/[0.03] p-2">
                  <div className="flex items-center justify-between gap-1 text-[9px] text-slate-500">
                    <span className="flex items-center gap-1.5">
                      <span className="size-1.5 rounded-full bg-sky-400" />
                      PROXY
                    </span>
                    <span className="text-[10px] font-bold text-white">
                      2.8k
                    </span>
                  </div>
                  <div className="mt-1.5 h-1.5 w-full overflow-hidden rounded-full bg-white/5">
                    <div
                      className="h-full rounded-full bg-sky-400"
                      style={{ width: '65%' }}
                    />
                  </div>
                </div>
                <div className="rounded-xl border border-white/[0.08] bg-white/[0.03] p-2">
                  <div className="flex items-center justify-between gap-1 text-[9px] text-slate-500">
                    <span className="flex items-center gap-1.5">
                      <span className="size-1.5 rounded-full bg-red-400" />
                      REJECT
                    </span>
                    <span className="text-[10px] font-bold text-white">
                      285
                    </span>
                  </div>
                  <div className="mt-1.5 h-1.5 w-full overflow-hidden rounded-full bg-white/5">
                    <div
                      className="h-full rounded-full bg-red-400"
                      style={{ width: '7%' }}
                    />
                  </div>
                </div>
              </div>
              <div className="flex shrink-0 flex-wrap gap-1.5">
                {['DOMAIN-SUFFIX', 'IP-CIDR', 'GEOIP', 'MATCH'].map((tag) => (
                  <span
                    key={tag}
                    className="rounded border border-white/10 bg-white/5 px-1.5 py-0.5 font-mono text-[9px] text-white"
                  >
                    {tag}
                  </span>
                ))}
              </div>
            </div>
          </article>

          {/* 4. 运行模式 2×2 */}
          <article
            className={`${bentoCard} md:col-span-1 md:row-span-2 lg:col-span-2 lg:col-start-1 lg:row-span-2 lg:row-start-3`}
          >
            <div
              aria-hidden="true"
              className="pointer-events-none absolute -right-10 -top-10 size-40 rounded-full bg-emerald-400/10 blur-[56px]"
            />
            <div className="relative z-10 shrink-0">
              <div className="mb-1.5 inline-flex items-center rounded-full border border-white/10 bg-white/5 px-2 py-0.5 text-[10px] font-bold uppercase tracking-[0.18em] text-slate-500">
                模式
              </div>
              <h3 className="mb-0.5 text-base font-semibold tracking-tight text-white">
                运行模式
              </h3>
              <p className="text-[12px] leading-snug text-slate-400">
                菜单栏一键切换 Rule / Global / Direct，也可用快捷键直达。
              </p>
            </div>
            <div className="relative z-10 mt-2.5 flex min-h-0 flex-1 flex-col gap-1.5">
              <div className="flex min-h-0 flex-1 items-center rounded-xl border border-sky-400/25 bg-sky-400/10 px-3 py-2 shadow-[0_0_24px_rgba(56,189,248,0.08)]">
                <div className="flex w-full items-center justify-between gap-3">
                  <div>
                    <div className="text-[11px] font-bold uppercase tracking-[0.18em] text-sky-300">
                      RULE
                    </div>
                    <div className="mt-0.5 text-[13px] font-medium text-white">
                      规则匹配
                    </div>
                  </div>
                  <div className="flex shrink-0 items-center gap-1.5">
                    <span className="rounded-full border border-sky-400/30 bg-black/30 px-2 py-0.5 text-[10px] font-bold uppercase tracking-[0.16em] text-sky-300">
                      当前
                    </span>
                    <ShortcutKey>⌃⌘1</ShortcutKey>
                  </div>
                </div>
              </div>
              <div className="flex min-h-0 flex-1 items-center rounded-xl border border-white/10 bg-white/[0.03] px-3 py-2">
                <div className="flex w-full items-center justify-between gap-3">
                  <div>
                    <div className="text-[11px] font-bold uppercase tracking-[0.18em] text-white">
                      GLOBAL
                    </div>
                    <div className="mt-0.5 text-[13px] font-medium text-white">
                      全局代理
                    </div>
                  </div>
                  <ShortcutKey>⌃⌘2</ShortcutKey>
                </div>
              </div>
              <div className="flex min-h-0 flex-1 items-center rounded-xl border border-white/10 bg-white/[0.03] px-3 py-2">
                <div className="flex w-full items-center justify-between gap-3">
                  <div>
                    <div className="text-[11px] font-bold uppercase tracking-[0.18em] text-white">
                      DIRECT
                    </div>
                    <div className="mt-0.5 text-[13px] font-medium text-white">
                      全局直连
                    </div>
                  </div>
                  <ShortcutKey>⌃⌘3</ShortcutKey>
                </div>
              </div>
            </div>
          </article>

          {/* 5. 节点切换 2×2 */}
          <article
            className={`${bentoCard} md:col-span-1 md:row-span-2 lg:col-span-2 lg:col-start-3 lg:row-span-2 lg:row-start-3`}
          >
            <div className="mb-2 flex shrink-0 items-center justify-between gap-2">
              <h3 className="text-base font-semibold tracking-tight text-white">
                节点切换
              </h3>
              <ShortcutKey>⌘⌥1</ShortcutKey>
            </div>
            <div className="flex min-h-0 flex-1 flex-col gap-1">
              {[
                { name: 'HK-Premium', ms: '24ms', active: true },
                { name: 'TW-Taipei', ms: '31ms', active: false },
                { name: 'SG-Direct', ms: '48ms', active: false },
                { name: 'KR-Seoul', ms: '56ms', active: false },
                { name: 'JP-Low', ms: '89ms', active: false },
                { name: 'MY-Burst', ms: '112ms', active: false },
                { name: 'US-Global', ms: '162ms', active: false },
                { name: 'DE-Edge', ms: '189ms', active: false },
              ].map((node, i) => (
                <div
                  key={node.name}
                  className={
                    node.active
                      ? 'flex min-h-0 flex-1 items-center justify-between rounded-lg border border-emerald-400/20 bg-emerald-400/10 px-2.5'
                      : 'flex min-h-0 flex-1 items-center justify-between rounded-lg border border-white/5 bg-white/5 px-2.5'
                  }
                  style={
                    node.active
                      ? undefined
                      : { opacity: Math.max(0.65, 0.85 - i * 0.03) }
                  }
                >
                  <div className="flex items-center gap-2 overflow-hidden">
                    <span
                      className={
                        node.active
                          ? 'size-1.5 shrink-0 rounded-full bg-emerald-400 shadow-[0_0_8px_rgba(52,211,153,0.7)]'
                          : 'size-1.5 shrink-0 rounded-full bg-white/20'
                      }
                    />
                    <span className="truncate text-xs font-medium text-white">
                      {node.name}
                    </span>
                  </div>
                  <span
                    className={
                      node.active
                        ? 'shrink-0 text-[10px] font-bold text-emerald-300'
                        : 'shrink-0 text-[10px] font-bold text-slate-500'
                    }
                  >
                    {node.ms}
                  </span>
                </div>
              ))}
            </div>
          </article>

          {/* 6. 系统代理 1×1 */}
          <article
            className={`${bentoCard} justify-between md:col-span-1 md:row-span-1 lg:col-span-1 lg:col-start-5 lg:row-span-1 lg:row-start-3`}
          >
            <h3 className="text-base font-semibold tracking-tight text-white">
              系统代理
            </h3>
            <div className="mt-auto flex items-end justify-between">
              <span className="text-[11px] font-bold uppercase tracking-widest text-emerald-300">
                已启用
              </span>
              <div
                className="proxy-toggle"
                aria-hidden="true"
              />
            </div>
          </article>

          {/* 7. TUN 与权限 1×1 */}
          <article
            className={`${bentoCard} items-center justify-center text-center md:col-span-1 md:row-span-1 lg:col-span-1 lg:col-start-6 lg:row-span-1 lg:row-start-3`}
          >
            <div className="relative mb-3 inline-flex size-12 items-center justify-center rounded-full border border-emerald-400/20 bg-emerald-400/10">
              <div className="absolute inset-0 rounded-full bg-emerald-400/20 blur-md" />
              <ShieldCheck className="relative size-5 text-emerald-300" />
            </div>
            <h3 className="text-[13px] font-semibold tracking-tight text-white">
              TUN 与权限
            </h3>
          </article>

          {/* 8. 日志检索 2×1 */}
          <article
            className={`${bentoCard} justify-between md:col-span-2 md:row-span-1 lg:col-span-2 lg:col-start-7 lg:row-span-1 lg:row-start-3`}
          >
            <div className="mb-2 flex items-center justify-between">
              <h3 className="text-[13px] font-semibold tracking-tight text-white">
                日志检索
              </h3>
              <div className="flex items-center gap-1.5 rounded-lg border border-white/10 bg-white/5 px-2 py-1 font-mono text-[10px] text-slate-500">
                <span className="opacity-70">⌕</span>
                <span>筛选: mihomo</span>
              </div>
            </div>
            <div className="mt-auto rounded-xl border border-white/5 bg-black/50 p-2.5">
              <div className="grid gap-0.5 font-mono text-[10px] leading-tight opacity-80 sm:text-[11px]">
                <span className="text-emerald-300/90">
                  14:22:01 connected HK-Premium-01
                </span>
                <span className="text-slate-500">
                  14:22:05 rule matched api.github.com
                </span>
                <span className="text-rose-300/85">
                  14:22:10 latency spike detected
                </span>
              </div>
            </div>
          </article>

          {/* 9+10. 配置导入 + 内核更换 2×1 */}
          <article
            className={`${bentoCard} justify-between md:col-span-2 md:row-span-1 lg:col-span-2 lg:col-start-5 lg:row-span-1 lg:row-start-4`}
          >
            <div
              aria-hidden="true"
              className="pointer-events-none absolute -right-8 -top-8 size-28 rounded-full bg-sky-400/10 blur-[44px]"
            />
            <div className="relative z-10 flex h-full min-h-0 flex-col gap-2">
              <div className="flex shrink-0 items-start justify-between gap-3">
                <div className="min-w-0">
                  <h3 className="text-[13px] font-semibold tracking-tight text-white">
                    配置与内核
                  </h3>
                  <p className="mt-0.5 text-[10px] leading-snug text-slate-500">
                    导入配置，并在 mihomo / smart 间切换。
                  </p>
                </div>
                <div className="flex shrink-0 items-center gap-1.5">
                  <span className="rounded-full border border-indigo-400/20 bg-indigo-400/10 px-2.5 py-1 text-[10px] font-medium text-indigo-200">
                    本地
                  </span>
                  <span className="rounded-full border border-white/10 bg-white/5 px-2.5 py-1 text-[10px] font-medium text-white">
                    远程
                  </span>
                </div>
              </div>
              <div className="grid min-h-0 flex-1 grid-cols-2 gap-1.5">
                <div className="flex items-center justify-between gap-2 rounded-xl border border-sky-400/20 bg-sky-400/10 px-2.5 py-2 shadow-[0_0_18px_rgba(56,189,248,0.08)]">
                  <div className="flex min-w-0 items-center gap-2">
                    <div className="flex size-7 shrink-0 items-center justify-center rounded-lg border border-sky-400/20 bg-black/30 text-[10px] font-black uppercase tracking-[0.12em] text-sky-300">
                      M
                    </div>
                    <div className="min-w-0">
                      <div className="truncate font-mono text-[12px] font-semibold leading-none text-white">
                        mihomo
                      </div>
                      <div className="mt-1 text-[9px] uppercase tracking-[0.14em] text-sky-300">
                        当前
                      </div>
                    </div>
                  </div>
                  <span className="size-2 shrink-0 rounded-full bg-sky-400 shadow-[0_0_10px_rgba(56,189,248,0.8)]" />
                </div>
                <div className="flex items-center justify-between gap-2 rounded-xl border border-white/10 bg-white/[0.03] px-2.5 py-2">
                  <div className="flex min-w-0 items-center gap-2">
                    <div className="flex size-7 shrink-0 items-center justify-center rounded-lg border border-white/10 bg-black/30 text-[10px] font-black uppercase tracking-[0.12em] text-white">
                      S
                    </div>
                    <div className="min-w-0">
                      <div className="truncate font-mono text-[12px] font-semibold leading-none text-white">
                        smart
                      </div>
                      <div className="mt-1 text-[9px] uppercase tracking-[0.14em] text-slate-500">
                        可切换
                      </div>
                    </div>
                  </div>
                  <span className="size-2 shrink-0 rounded-full bg-white/25" />
                </div>
              </div>
              <div className="flex shrink-0 items-center justify-between gap-2 rounded-xl border border-white/10 bg-black/30 px-2.5 py-1.5">
                <span className="text-[9px] font-semibold uppercase tracking-[0.16em] text-slate-500">
                  切换后重启
                </span>
                <span className="text-[10px] font-bold text-sky-300">重启</span>
              </div>
            </div>
          </article>

          {/* 11. 远程管理 2×1 */}
          <article
            className={`${bentoCard} justify-between md:col-span-2 md:row-span-1 lg:col-span-2 lg:col-start-7 lg:row-span-1 lg:row-start-4`}
          >
            <div
              aria-hidden="true"
              className="pointer-events-none absolute -bottom-10 -right-10 size-40 rounded-full bg-emerald-500/10 blur-[50px]"
            />
            <div className="relative z-10 flex h-full flex-col gap-2.5">
              <div>
                <h3 className="mb-0.5 text-base font-semibold tracking-tight text-white">
                  远程管理
                </h3>
                <p className="max-w-none text-[11px] leading-snug text-slate-400">
                  轻松接管局域网或云端服务端。
                </p>
              </div>
              <div className="mt-auto flex w-full flex-col gap-2 rounded-xl border border-white/10 bg-white/5 p-2.5">
                <div className="flex items-center justify-between gap-3 rounded-lg border border-emerald-500/20 bg-emerald-500/10 px-2.5 py-2">
                  <div className="flex min-w-0 items-center gap-2.5">
                    <div className="flex size-8 shrink-0 items-center justify-center rounded-lg border border-white/10 bg-black/40">
                      <Server className="size-4 text-emerald-400" />
                    </div>
                    <div className="min-w-0">
                      <div className="truncate font-mono text-[12px] font-medium leading-none text-white">
                        192.168.31.10:9090
                      </div>
                      <div className="mt-1 truncate text-[10px] text-slate-500">
                        Home NAS / Docker
                      </div>
                    </div>
                  </div>
                  <span
                    className="size-2.5 shrink-0 rounded-full bg-emerald-400 shadow-[0_0_10px_rgba(52,211,153,0.8)]"
                    aria-label="Remote host online"
                  />
                </div>
                <div className="flex items-center justify-between gap-3 rounded-lg border border-red-500/20 bg-red-500/10 px-2.5 py-2">
                  <div className="flex min-w-0 items-center gap-2.5">
                    <div className="flex size-8 shrink-0 items-center justify-center rounded-lg border border-white/10 bg-black/40">
                      <Server className="size-4 text-red-400" />
                    </div>
                    <div className="min-w-0">
                      <div className="truncate font-mono text-[12px] font-medium leading-none text-white">
                        47.76.120.8:9090
                      </div>
                      <div className="mt-1 truncate text-[10px] text-slate-500">
                        Singapore VPS / mihomo
                      </div>
                    </div>
                  </div>
                  <span
                    className="size-2.5 shrink-0 rounded-full bg-red-400 shadow-[0_0_10px_rgba(248,113,113,0.7)]"
                    aria-label="Remote host offline"
                  />
                </div>
              </div>
            </div>
          </article>
        </div>

        <div className="mt-5 flex flex-wrap items-center gap-x-2.5 gap-y-1.5 border-t border-white/[0.06] pt-4 text-[11px] text-slate-500">
          <span className="inline-flex items-center gap-1 font-medium text-slate-400">
            <Settings2 className="size-3" />
            另含
          </span>
          {[
            'SSID 策略',
            '快捷键',
            '状态栏样式',
            '面板固定',
            '开机/内核自启',
            '端口编辑',
            'Geo / 缓存清理',
            '终端代理命令',
            '外观与语言',
          ].map((tag) => (
            <span
              key={tag}
              className="rounded-md border border-white/[0.06] bg-white/[0.03] px-2 py-0.5 text-slate-400"
            >
              {tag}
            </span>
          ))}
          <Link
            href="/docs/troubleshooting"
            className="ml-auto font-medium text-sky-300/90 transition hover:text-sky-200"
          >
            排障文档 →
          </Link>
        </div>
      </section>

      {/* Quick start */}
      <section
        id="quick-start"
        className="relative scroll-mt-28 border-y border-white/[0.06] py-20 lg:py-24"
      >
        <div className="mx-auto max-w-[1200px] px-6 sm:px-8">
          <div className="mb-12 flex flex-col items-start justify-between gap-6 lg:mb-14 lg:flex-row lg:items-end">
            <div className="max-w-xl">
              <p className="text-xs font-semibold tracking-[0.16em] text-sky-300/90">
                首次接管流量
              </p>
              <h2 className="mt-3 text-3xl font-semibold tracking-[-0.03em] text-white sm:text-4xl">
                快速开始
              </h2>
              <p className="mt-3 text-sm leading-6 text-slate-400">
                第一次接管流量，按下面六步顺序操作即可。完整说明见文档。
              </p>
            </div>
            <Link
              href="/docs/quick-start"
              className="inline-flex items-center gap-2 rounded-xl border border-sky-400/20 bg-sky-400/10 px-4 py-2.5 text-sm font-semibold text-sky-200 transition hover:bg-sky-400/15"
            >
              阅读完整快速开始
              <ArrowRight className="size-4" />
            </Link>
          </div>

          <ol className="grid gap-3 md:grid-cols-2 xl:grid-cols-3">
            {quickSteps.map((step, index) => (
              <li
                key={step.title}
                className="relative flex flex-col rounded-2xl border border-white/[0.08] bg-black/25 p-5 backdrop-blur-sm"
              >
                <div className="mb-4 flex items-center gap-3">
                  <span className="flex size-8 items-center justify-center rounded-full border border-sky-400/25 bg-sky-400/10 font-mono text-xs font-bold text-sky-300">
                    {String(index + 1).padStart(2, '0')}
                  </span>
                  <h3 className="text-sm font-semibold text-white">
                    {step.title}
                  </h3>
                </div>
                <p className="text-sm leading-6 text-slate-400">{step.body}</p>
              </li>
            ))}
          </ol>
        </div>
      </section>

      {/* Footer */}
      <footer className="relative border-t border-white/[0.06]">
        <div className="mx-auto flex max-w-[1200px] flex-col gap-10 px-6 py-12 sm:px-8 lg:flex-row lg:items-start lg:justify-between">
          <div className="max-w-xs">
            <div className="flex items-center gap-2.5 font-semibold text-white">
              <Image
                src="/clashbar-logo.png"
                alt=""
                width={28}
                height={28}
              />
              ClashBar
            </div>
            <p className="mt-3 text-sm leading-6 text-slate-500">
              面向 macOS 的原生菜单栏 mihomo 客户端。轻量、开源、专注日常使用。
            </p>
          </div>
          <div className="grid grid-cols-2 gap-10 sm:grid-cols-3 sm:gap-16">
            <FooterCol
              title="产品"
              links={[
                { label: '功能', href: '#features' },
                { label: '快速开始', href: '#quick-start' },
                {
                  label: '下载',
                  href: 'https://github.com/Sitoi/ClashBar/releases',
                  external: true,
                },
              ]}
            />
            <FooterCol
              title="文档"
              links={[
                { label: '文档首页', href: '/docs' },
                { label: '快速开始', href: '/docs/quick-start' },
                { label: '功能总览', href: '/docs/features' },
                { label: '日常使用', href: '/docs/daily-use' },
                { label: '常见问题', href: '/docs/troubleshooting' },
                { label: '关于', href: '/docs/about' },
              ]}
            />
            <FooterCol
              title="社区"
              links={[
                {
                  label: 'GitHub',
                  href: 'https://github.com/Sitoi/ClashBar',
                  external: true,
                },
                {
                  label: 'Releases',
                  href: 'https://github.com/Sitoi/ClashBar/releases',
                  external: true,
                },
                {
                  label: 'Telegram',
                  href: 'https://t.me/clashbars',
                  external: true,
                },
                {
                  label: '问题反馈',
                  href: 'https://github.com/Sitoi/ClashBar/issues',
                  external: true,
                },
              ]}
            />
          </div>
        </div>
        <div className="border-t border-white/[0.04]">
          <p className="mx-auto max-w-[1200px] px-6 py-6 text-center text-xs text-slate-600 sm:px-8 sm:text-left">
            © 2026 ClashBar. 开源协议为 GPL-3.0。
          </p>
        </div>
      </footer>
    </main>
  )
}

function SectionHeading({
  eyebrow,
  title,
  description,
}: {
  eyebrow: string
  title: string
  description: string
}) {
  return (
    <div className="mx-auto mb-12 max-w-2xl text-center lg:mb-14">
      <p className="text-xs font-semibold tracking-[0.16em] text-sky-300/90">
        {eyebrow}
      </p>
      <h2 className="mt-3 text-3xl font-semibold tracking-[-0.03em] text-white sm:text-4xl">
        {title}
      </h2>
      <p className="mt-3.5 text-sm leading-6 text-slate-400 sm:text-[15px]">
        {description}
      </p>
    </div>
  )
}

function FooterCol({
  title,
  links,
}: {
  title: string
  links: { label: string; href: string; external?: boolean }[]
}) {
  return (
    <div>
      <p className="text-xs font-semibold uppercase tracking-[0.14em] text-slate-500">
        {title}
      </p>
      <ul className="mt-4 space-y-2.5">
        {links.map((link) => (
          <li key={link.label}>
            {link.external ? (
              <a
                href={link.href}
                className="text-sm text-slate-400 transition hover:text-white"
              >
                {link.label}
              </a>
            ) : link.href.startsWith('/') ? (
              <Link
                href={link.href}
                className="text-sm text-slate-400 transition hover:text-white"
              >
                {link.label}
              </Link>
            ) : (
              <a
                href={link.href}
                className="text-sm text-slate-400 transition hover:text-white"
              >
                {link.label}
              </a>
            )}
          </li>
        ))}
      </ul>
    </div>
  )
}
