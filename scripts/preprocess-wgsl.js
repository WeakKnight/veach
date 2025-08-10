const fs = require('fs');
const path = require('path');

/**

预处理 WGSL 源码：解析 #import "xxx" 并递归展开。
@param {string} entryPath 入口 wgsl 文件绝对路径
@param {object} options
@param {string[]} options.includeDirs 额外搜索目录
@returns {string} 预处理后的代码
*/
function preprocessWGSL(entryPath, options = {}) {
	const { includeDirs = [] } = options;
	const defaultIncludeDirs = [
		path.dirname(path.resolve(entryPath)),
		path.resolve(process.cwd(), 'src', 'shaders'),
		path.resolve(process.cwd(), 'shaders'),
		process.cwd(),
	];
	// 去重并归一化
	const searchDirs = Array.from(new Set([...defaultIncludeDirs, ...includeDirs.map(d => path.resolve(d))]));

	const visited = new Map(); // filePath -> expanded code
	const stack = []; // include 栈用于循环依赖提示
	function resolveImport(specifier, fromFile) {
		// 去掉引号（允许 "a/b.wgsl" 或 <a/b.wgsl>）
		specifier = specifier.replace(/^["'<]+|[">']+$/g, '');

		// 相对 / 绝对
		if (specifier.startsWith('.') || specifier.startsWith('/')) {
			const p = path.resolve(path.dirname(fromFile), specifier);
			if (fs.existsSync(p)) return p;
		} else {
			// 在 searchDirs 中找（自动包含 entry 所在目录、src/shaders、shaders、项目根）
			for (const dir of searchDirs) {
				const p = path.resolve(dir, specifier);
				if (fs.existsSync(p)) return p;
			}
		}
		throw new Error(`Cannot resolve import "${specifier}" from ${fromFile}`);
	}

	function expand(filePath) {
		const absPath = path.resolve(filePath);

		if (visited.has(absPath)) {
			return visited.get(absPath);
		}
		if (stack.includes(absPath)) {
			const cycle = [...stack, absPath].map(p => path.relative(process.cwd(), p)).join(' -> ');
			throw new Error(`Cyclic #import detected: ${cycle}`);
		}

		stack.push(absPath);
		const src = fs.readFileSync(absPath, 'utf8');

		const lines = src.split(/\r?\n/);
		const out = [];

		out.push(`// >>>>> BEGIN ${path.relative(process.cwd(), absPath)}`);
		for (let i = 0; i < lines.length; i++) {
			const line = lines[i];

			// 匹配：#import "xxx"
			const m = /^\s*#import\s+(.+?)\s*$/.exec(line);
			if (m) {
				const spec = m[1].trim();
				const importedPath = resolveImport(spec, absPath);
				const expanded = expand(importedPath);
				out.push(expanded);
			} else {
				out.push(line);
			}
		}
		out.push(`// <<<<< END   ${path.relative(process.cwd(), absPath)}`);

		stack.pop();
		const code = out.join('\n');
		visited.set(absPath, code);
		return code;
	}

	return expand(entryPath);
}

/**
 * 递归列出目录下所有 .wgsl 文件
 * @param {string} dir
 * @returns {string[]}
 */
function listWgslFiles(dir) {
	const results = [];
	if (!fs.existsSync(dir)) return results;
	const entries = fs.readdirSync(dir, { withFileTypes: true });
	for (const entry of entries) {
		const full = path.join(dir, entry.name);
		if (entry.isDirectory()) {
			results.push(...listWgslFiles(full));
		} else if (entry.isFile() && entry.name.toLowerCase().endsWith('.wgsl')) {
			results.push(full);
		}
	}
	return results;
}

/**
 * 批量处理目录下的 .wgsl 并输出到目标目录（保持相对结构）
 * @param {string} srcDir 源目录（如 src/shaders）
 * @param {string} outDir 目标目录（如 assets/shaders）
 * @param {string[]} includeDirs 额外 include 目录
 */
function preprocessDir(srcDir, outDir, includeDirs = []) {
	const absSrc = path.resolve(srcDir);
	const absOut = path.resolve(outDir);
	const files = listWgslFiles(absSrc);
	for (const file of files) {
		const code = preprocessWGSL(file, { includeDirs: [absSrc, ...includeDirs] });
		const rel = path.relative(absSrc, file);
		const outPath = path.join(absOut, rel);
		fs.mkdirSync(path.dirname(outPath), { recursive: true });
		fs.writeFileSync(outPath, code, 'utf8');
		// eslint-disable-next-line no-console
		console.log('Wrote:', path.relative(process.cwd(), outPath));
	}
}

// CLI（无参数，固定批处理逻辑）
if (require.main === module) {
	const srcDefault = fs.existsSync(path.resolve(process.cwd(), 'src', 'shaders'))
		? path.resolve(process.cwd(), 'src', 'shaders')
		: path.resolve(process.cwd(), 'shaders');
	const outDefault = path.resolve(process.cwd(), 'assets', 'shaders');

	preprocessDir(srcDefault, outDefault, []);
}

module.exports = { preprocessWGSL, preprocessDir };