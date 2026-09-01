import data from '@/data/changelog.generated.json';
import type { ChangelogData } from '@/lib/changelog';
import { ChangelogTimeline } from './timeline';

/**
 * Server entry used from MDX. Loads the build-generated JSON and renders the client timeline.
 * Soft-fail data (ok: false) is handled inside ChangelogTimeline.
 */
export function ChangelogTimelineBlock() {
  return <ChangelogTimeline data={data as ChangelogData} />;
}
