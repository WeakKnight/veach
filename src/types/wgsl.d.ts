declare module '*.wgsl' {
  const content: string;
  export default content;
}

declare module '*.wgsl?raw' {
  const content: string;
  export default content;
}

// vite-slang plugin types
declare module '*.slang' {
  const code: string;
  const reflection: {
    entryPoints: Array<{
      name: string;
      stage: 'vertex' | 'fragment' | 'compute';
    }>;
    bindings: Array<{
      name: string;
      type: string;
      binding: number;
      group: number;
    }>;
  };
  export default code;
  export { code, reflection };
} 