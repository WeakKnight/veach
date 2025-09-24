import { contextBridge, ipcRenderer } from 'electron';

contextBridge.exposeInMainWorld('fs', {
  readTextFile: (filePath: string, encoding: string = 'utf8') =>
    ipcRenderer.invoke('fs:readTextFile', filePath, encoding) as Promise<string>,

  writeTextFile: (filePath: string, data: string, encoding: string = 'utf8') =>
    ipcRenderer.invoke('fs:writeTextFile', filePath, data, encoding) as Promise<void>,

  readdir: (dirPath: string) =>
    ipcRenderer.invoke('fs:readdir', dirPath) as Promise<string[]>,

  mkdir: (dirPath: string) =>
    ipcRenderer.invoke('fs:mkdir', dirPath) as Promise<void>,

  unlink: (filePath: string) =>
    ipcRenderer.invoke('fs:unlink', filePath) as Promise<void>,

  stat: (filePath: string) =>
    ipcRenderer.invoke('fs:stat', filePath) as Promise<{
      isFile: boolean;
      isDirectory: boolean;
      size: number;
      mtimeMs: number;
      birthtimeMs: number;
    }>,

  // 新增：读取二进制文件
  readBinaryFile: (filePath: string) =>
    ipcRenderer.invoke('fs:readBinaryFile', filePath) as Promise<ArrayBuffer>,

  // 新增：写入二进制文件
  writeBinaryFile: (filePath: string, data: ArrayBuffer) =>
    ipcRenderer.invoke('fs:writeBinaryFile', filePath, data) as Promise<void>,
});
