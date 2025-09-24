import { app, BrowserWindow, ipcMain } from 'electron';
import path from 'node:path';
import started from 'electron-squirrel-startup';
import * as fs from 'node:fs/promises';

// Handle creating/removing shortcuts on Windows when installing/uninstalling.
if (started) {
  app.quit();
}

// Minimal fs IPC handlers
ipcMain.handle('fs:readTextFile', async (_event, filePath: string, encoding: BufferEncoding = 'utf8') => {
  return fs.readFile(filePath, { encoding });
});

ipcMain.handle('fs:writeTextFile', async (_event, filePath: string, data: string, encoding: BufferEncoding = 'utf8') => {
  await fs.writeFile(filePath, data, { encoding });
});

ipcMain.handle('fs:readdir', async (_event, dirPath: string) => {
  return fs.readdir(dirPath);
});

ipcMain.handle('fs:mkdir', async (_event, dirPath: string) => {
  await fs.mkdir(dirPath, { recursive: true });
});

ipcMain.handle('fs:unlink', async (_event, filePath: string) => {
  await fs.unlink(filePath);
});

ipcMain.handle('fs:stat', async (_event, filePath: string) => {
  const s = await fs.stat(filePath);
  return {
    isFile: s.isFile(),
    isDirectory: s.isDirectory(),
    size: s.size,
    mtimeMs: s.mtimeMs,
    birthtimeMs: s.birthtimeMs,
  };
});

// 新增：读取二进制文件
ipcMain.handle('fs:readBinaryFile', async (_event, filePath: string) => {
  const buffer = await fs.readFile(filePath);
  return buffer.buffer.slice(buffer.byteOffset, buffer.byteOffset + buffer.byteLength);
});

// 新增：写入二进制文件
ipcMain.handle('fs:writeBinaryFile', async (_event, filePath: string, data: ArrayBuffer) => {
  const buffer = Buffer.from(data);
  await fs.writeFile(filePath, buffer);
});

const createWindow = () => {
  // Create the browser window.
  const mainWindow = new BrowserWindow({
    width: 1280,
    height: 720,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
    },
  });

  // and load the index.html of the app.
  if (MAIN_WINDOW_VITE_DEV_SERVER_URL) {
    mainWindow.loadURL(MAIN_WINDOW_VITE_DEV_SERVER_URL);
  } else {
    mainWindow.loadFile(path.join(__dirname, `../renderer/${MAIN_WINDOW_VITE_NAME}/index.html`));
  }

  // Open the DevTools.
  mainWindow.webContents.openDevTools();
};

// This method will be called when Electron has finished
// initialization and is ready to create browser windows.
// Some APIs can only be used after this event occurs.
app.on('ready', createWindow);

// Quit when all windows are closed, except on macOS. There, it's common
// for applications and their menu bar to stay active until the user quits
// explicitly with Cmd + Q.
app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit();
  }
});

app.on('activate', () => {
  // On OS X it's common to re-create a window in the app when the
  // dock icon is clicked and there are no other windows open.
  if (BrowserWindow.getAllWindows().length === 0) {
    createWindow();
  }
});

// In this file you can include the rest of your app's specific main process
// code. You can also put them in separate files and import them here.
