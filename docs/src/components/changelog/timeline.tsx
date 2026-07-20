'use client';

import { useMemo, useState } from 'react';
import {
  CHANGELOG_CATEGORIES,
  CHANGELOG_CATEGORY_META,
  countFilteredItems,
  githubReleaseUrl,
  githubReleasesUrl,
  type ChangelogCategory,
  type ChangelogData,
  type ChangelogRelease,
} from '@/lib/changelog';
import { cn } from '@/lib/cn';
import { ChangelogItemText } from './item-text';

type Props = {
  data: ChangelogData;
};

export function ChangelogTimeline({ data }: Props) {
  const [active, setActive] = useState<Set<ChangelogCategory>>(
    () => new Set(CHANGELOG_CATEGORIES),
  );
  const [openVersions, setOpenVersions] = useState<Set<string>>(() => {
    const first = data.releases[0]?.version;
    return first ? new Set([first]) : new Set();
  });

  const visibleReleases = useMemo(() => {
    if (active.size === 0) return [];
    if (active.size === CHANGELOG_CATEGORIES.length) {
      return data.releases;
    }
    return data.releases.filter(
      (release) => countFilteredItems(release, active) > 0,
    );
  }, [data.releases, active]);

  if (!data.ok || data.releases.length === 0) {
    return <ChangelogFallback error={data.error} />;
  }

  const toggleCategory = (key: ChangelogCategory) => {
    setActive((prev) => {
      const next = new Set(prev);
      if (next.has(key)) next.delete(key);
      else next.add(key);
      return next;
    });
  };

  const toggleVersion = (version: string) => {
    setOpenVersions((prev) => {
      const next = new Set(prev);
      if (next.has(version)) next.delete(version);
      else next.add(version);
      return next;
    });
  };

  return (
    <div className="not-prose mt-6 flex flex-col gap-6">
      <div className="flex flex-wrap items-center gap-2">
        <span className="mr-1 text-sm text-fd-muted-foreground">筛选</span>
        {CHANGELOG_CATEGORIES.map((key) => {
          const meta = CHANGELOG_CATEGORY_META[key];
          const on = active.has(key);

          return (
            <button
              key={key}
              type="button"
              aria-pressed={on}
              onClick={() => toggleCategory(key)}
              className={cn(
                'inline-flex items-center gap-1.5 rounded-full border px-3 py-1 text-xs font-medium transition-colors',
                on
                  ? categoryChipOn(key)
                  : 'border-fd-border bg-fd-secondary/40 text-fd-muted-foreground hover:bg-fd-accent hover:text-fd-accent-foreground',
              )}
            >
              <span
                className={cn(
                  'size-1.5 rounded-full',
                  categoryDot(key),
                  !on && 'opacity-40',
                )}
              />
              {meta.label}
            </button>
          );
        })}
      </div>

      <ol className="relative m-0 flex list-none flex-col gap-3 p-0">
        {visibleReleases.map((release, index) => {
          const open = openVersions.has(release.version);
          return (
            <ReleaseCard
              key={release.version}
              release={release}
              open={open}
              isLatest={index === 0 && release === data.releases[0]}
              active={active}
              onToggle={() => toggleVersion(release.version)}
            />
          );
        })}
      </ol>

      {visibleReleases.length === 0 ? (
        <p className="rounded-xl border border-dashed border-fd-border px-4 py-8 text-center text-sm text-fd-muted-foreground">
          当前筛选下没有匹配的更新条目。
        </p>
      ) : null}
    </div>
  );
}

function ChangelogFallback({ error }: { error?: string }) {
  return (
    <div className="not-prose mt-6 rounded-xl border border-fd-border bg-fd-secondary/30 p-6">
      <p className="m-0 text-sm font-medium text-fd-foreground">
        暂时无法加载更新日志
      </p>
      <p className="mt-2 text-sm text-fd-muted-foreground">
        {error
          ? `原因：${error}`
          : '构建时未能解析仓库根目录的 CHANGELOG.md。'}
        请前往 GitHub Releases 查看完整变更说明。
      </p>
      <a
        href={githubReleasesUrl()}
        target="_blank"
        rel="noreferrer"
        className="mt-4 inline-flex text-sm font-medium text-fd-primary underline-offset-4 hover:underline"
      >
        打开 GitHub Releases →
      </a>
    </div>
  );
}

function ReleaseCard({
  release,
  open,
  isLatest,
  active,
  onToggle,
}: {
  release: ChangelogRelease;
  open: boolean;
  isLatest: boolean;
  active: ReadonlySet<ChangelogCategory>;
  onToggle: () => void;
}) {
  const itemCount = countFilteredItems(release, active);
  const panelId = `changelog-${release.version}`;

  return (
    <li className="rounded-xl border border-fd-border bg-fd-card/40">
      <div className="flex items-start gap-3 px-4 py-3.5">
        <button
          type="button"
          aria-expanded={open}
          aria-controls={panelId}
          onClick={onToggle}
          className="mt-0.5 flex size-7 shrink-0 items-center justify-center rounded-md border border-fd-border bg-fd-secondary/50 text-fd-muted-foreground transition-colors hover:bg-fd-accent hover:text-fd-accent-foreground"
        >
          <Chevron open={open} />
        </button>

        <div className="min-w-0 flex-1">
          <div className="flex flex-wrap items-center gap-2">
            <a
              href={githubReleaseUrl(release.version)}
              target="_blank"
              rel="noreferrer"
              className="font-mono text-base font-semibold tracking-tight text-fd-foreground underline-offset-4 hover:underline"
            >
              {release.version}
            </a>
            {isLatest ? (
              <span className="rounded-full bg-emerald-500/15 px-2 py-0.5 text-[11px] font-medium text-emerald-600 dark:text-emerald-400">
                最新
              </span>
            ) : null}
            <span className="text-xs text-fd-muted-foreground">
              {itemCount} 条更新
            </span>
          </div>

          {!open && release.summary ? (
            <p className="mt-1.5 line-clamp-2 text-sm leading-6 text-fd-muted-foreground">
              <ChangelogItemText text={release.summary} />
            </p>
          ) : null}
        </div>
      </div>

      {open ? (
        <div
          id={panelId}
          className="border-t border-fd-border px-4 pb-4 pt-3 sm:px-5"
        >
          {release.summary ? (
            <p className="mb-4 text-sm leading-7 text-fd-muted-foreground">
              <ChangelogItemText text={release.summary} />
            </p>
          ) : null}

          <div className="flex flex-col gap-4">
            {CHANGELOG_CATEGORIES.map((key) => {
              if (!active.has(key)) return null;
              const items = release.categories[key];
              if (items.length === 0) return null;
              const meta = CHANGELOG_CATEGORY_META[key];
              return (
                <section key={key}>
                  <h3 className="mb-2 flex items-center gap-2 text-sm font-semibold text-fd-foreground">
                    <span
                      className={cn('size-1.5 rounded-full', categoryDot(key))}
                    />
                    {meta.label}
                    <span className="font-normal text-fd-muted-foreground">
                      {items.length}
                    </span>
                  </h3>
                  <ul className="m-0 flex list-none flex-col gap-2 p-0">
                    {items.map((item, i) => (
                      <li
                        key={`${key}-${i}`}
                        className="relative rounded-lg border border-fd-border/70 bg-fd-background/60 px-3 py-2.5 pl-3 text-sm leading-6 text-fd-foreground/90"
                      >
                        <ChangelogItemText text={item.text} />
                      </li>
                    ))}
                  </ul>
                </section>
              );
            })}
          </div>
        </div>
      ) : null}
    </li>
  );
}

function Chevron({ open }: { open: boolean }) {
  return (
    <svg
      viewBox="0 0 16 16"
      className={cn(
        'size-3.5 transition-transform duration-150',
        open && 'rotate-90',
      )}
      aria-hidden
    >
      <path
        d="M6 3.5 11 8l-5 4.5"
        fill="none"
        stroke="currentColor"
        strokeWidth="1.6"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
}

function categoryDot(key: ChangelogCategory): string {
  switch (key) {
    case 'feature':
      return 'bg-emerald-500';
    case 'improve':
      return 'bg-sky-500';
    case 'fix':
      return 'bg-rose-500';
  }
}

function categoryChipOn(key: ChangelogCategory): string {
  switch (key) {
    case 'feature':
      return 'border-emerald-500/30 bg-emerald-500/10 text-emerald-700 dark:text-emerald-300';
    case 'improve':
      return 'border-sky-500/30 bg-sky-500/10 text-sky-700 dark:text-sky-300';
    case 'fix':
      return 'border-rose-500/30 bg-rose-500/10 text-rose-700 dark:text-rose-300';
  }
}
