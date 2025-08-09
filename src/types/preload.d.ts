export type FsStat = {
  isFile: boolean;
  isDirectory: boolean;
  size: number;
  mtimeMs: number;
  birthtimeMs: number;
};

export interface FsApi {
  readTextFile: (filePath: string, encoding?: string) => Promise<string>;
  writeTextFile: (filePath: string, data: string, encoding?: string) => Promise<void>;
  readdir: (dirPath: string) => Promise<string[]>;
  mkdir: (dirPath: string) => Promise<void>;
  unlink: (filePath: string) => Promise<void>;
  stat: (filePath: string) => Promise<FsStat>;
}

declare global {
  interface Window {
    fs: FsApi;
  }
}

export {}; 