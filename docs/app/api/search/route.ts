import { source } from '@/lib/source';
import { createFromSource } from 'fumadocs-core/search/server';

// Orama does not ship a Chinese stemmer; omit `language` so indexing works on Workers.
export const { GET } = createFromSource(source);
