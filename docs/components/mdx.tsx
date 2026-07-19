import defaultMdxComponents from 'fumadocs-ui/mdx';
import type { MDXComponents } from 'mdx/types';
import type { ComponentPropsWithoutRef } from 'react';

function Kbd(props: ComponentPropsWithoutRef<'kbd'>) {
  const { className, ...rest } = props;
  return <kbd className={['clashbar-kbd', className].filter(Boolean).join(' ')} {...rest} />;
}

export function getMDXComponents(components?: MDXComponents) {
  return {
    ...defaultMdxComponents,
    kbd: Kbd,
    ...components,
  } satisfies MDXComponents;
}

export const useMDXComponents = getMDXComponents;

declare global {
  type MDXProvidedComponents = ReturnType<typeof getMDXComponents>;
}
