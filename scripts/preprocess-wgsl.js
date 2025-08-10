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
	const visited = new Map(); // filePath -> expanded code
	const stack = []; // include 栈用于循环依赖提示
	function resolveImport(specifier, fromFile) {
		// 去掉引号（允许 "a/b.wgsl" 或 <a/b.wgsl>）
		specifier = specifier.replace(/^["'<]+|[">']+$/g, '');


		// 相对 / 绝对
		if (specifier.startsWith('.') || specifier.startsWith('/')) {
			const p = path.resolve(path.dirname(fromFile), specifier);
			console.log(p);
			if (fs.existsSync(p)) return p;
		} else {
			// 在 includeDirs 中找
			for (const dir of includeDirs) {
				const p = path.resolve(dir, specifier);
				console.log(p);
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

// CLI 示例
if (require.main === module) {
	const entry = process.argv[2];
	if (!entry) {
		console.error('Usage: node preprocess-wgsl.js <entry.wgsl> [out.wgsl] [includeDir1,includeDir2,...]');
		process.exit(1);
	}
	const out = process.argv[3] || null;
	const includeArg = process.argv[4] || '';
	const includeDirs = includeArg ? includeArg.split(',').map(p => path.resolve(p)) : [];

	const code = preprocessWGSL(path.resolve(entry), { includeDirs });
	if (out) {
		fs.mkdirSync(path.dirname(out), { recursive: true });
		fs.writeFileSync(out, code, 'utf8');
		console.log('Wrote:', out);
	} else {
		process.stdout.write(code);
	}
}

module.exports = { preprocessWGSL };