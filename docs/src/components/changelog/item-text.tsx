import { Fragment, type ReactNode } from 'react';
import { githubIssueUrl } from '@/lib/changelog';

/**
 * Render a changelog item string with:
 * - **bold** → <strong>
 * - [label](url) → external link
 * - #123 → GitHub issue link
 * Plain text otherwise (no raw HTML).
 */
export function ChangelogItemText({ text }: { text: string }) {
  return <>{renderInline(text)}</>;
}

function renderInline(text: string): ReactNode[] {
  // Order: links first (may contain bold-looking text), then bold, then issues.
  const linkParts = text.split(/(\[[^\]]+\]\(https?:\/\/[^)]+\))/g);
  const nodes: ReactNode[] = [];

  linkParts.forEach((part, linkIndex) => {
    if (!part) return;
    const linkMatch = part.match(/^\[([^\]]+)\]\((https?:\/\/[^)]+)\)$/);
    if (linkMatch) {
      nodes.push(
        <a
          key={`l-${linkIndex}`}
          href={linkMatch[2]}
          target="_blank"
          rel="noreferrer"
          className="font-medium text-fd-primary underline-offset-2 hover:underline"
        >
          {linkMatch[1]}
        </a>,
      );
      return;
    }
    nodes.push(
      <Fragment key={`p-${linkIndex}`}>
        {renderBoldAndIssues(part, `p-${linkIndex}`)}
      </Fragment>,
    );
  });

  return nodes;
}

function renderBoldAndIssues(text: string, keyPrefix: string): ReactNode[] {
  const boldParts = text.split(/(\*\*[^*]+\*\*)/g);
  const nodes: ReactNode[] = [];

  boldParts.forEach((part, boldIndex) => {
    if (!part) return;
    if (part.startsWith('**') && part.endsWith('**') && part.length > 4) {
      const inner = part.slice(2, -2);
      nodes.push(
        <strong
          key={`${keyPrefix}-b-${boldIndex}`}
          className="font-semibold text-fd-foreground"
        >
          {linkifyIssues(inner, `${keyPrefix}-b-${boldIndex}`)}
        </strong>,
      );
      return;
    }
    nodes.push(
      <Fragment key={`${keyPrefix}-t-${boldIndex}`}>
        {linkifyIssues(part, `${keyPrefix}-t-${boldIndex}`)}
      </Fragment>,
    );
  });

  return nodes;
}

function linkifyIssues(text: string, keyPrefix: string): ReactNode[] {
  const parts = text.split(/(#\d+)/g);
  return parts.map((part, index) => {
    const match = part.match(/^#(\d+)$/);
    if (!match) {
      return <Fragment key={`${keyPrefix}-${index}`}>{part}</Fragment>;
    }
    const issue = Number(match[1]);
    return (
      <a
        key={`${keyPrefix}-${index}`}
        href={githubIssueUrl(issue)}
        target="_blank"
        rel="noreferrer"
        className="font-medium text-fd-primary underline-offset-2 hover:underline"
      >
        #{issue}
      </a>
    );
  });
}
