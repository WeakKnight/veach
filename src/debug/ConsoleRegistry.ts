/** DOM-free console: typed commands only, never JavaScript evaluation. */
export interface ConsoleResult { ok: boolean; lines: string[]; clear?: boolean }
export interface ConsoleEntry {
	name: string;
	help: string;
	usage?: string;
	choices?: readonly string[];
	get?: () => unknown;
	set?: (input: string) => void | Promise<void>;
	run?: (input: string) => unknown | Promise<unknown>;
}
export type ConsoleExecutor = (action: () => Promise<ConsoleResult>) => Promise<ConsoleResult>;
export const formatConsoleValue = (value: unknown): string => typeof value === 'string' ? value : JSON.stringify(value) ?? '—';

export class ConsoleRegistry {
	private readonly entries = new Map<string, ConsoleEntry>();
	private queue: Promise<unknown> = Promise.resolve();
	constructor(private readonly executor?: ConsoleExecutor) {}

	register(entry: ConsoleEntry): void {
		const key = entry.name.toLowerCase();
		if (!/^r\.[a-z0-9.]+$/i.test(entry.name) || this.entries.has(key)) throw new Error(`Invalid or duplicate command: ${entry.name}`);
		this.entries.set(key, entry);
	}
	list(filter = ''): ConsoleEntry[] {
		const query = filter.toLowerCase().replace(/\*$/, '');
		return [...this.entries.values()].filter(e => e.name.toLowerCase().includes(query) || e.help.toLowerCase().includes(query)).sort((a, b) => a.name.localeCompare(b.name));
	}
	complete(input: string): string[] {
		const text = input.trimStart(), match = /^(\S+)(?:\s+|=)(.*)$/.exec(text);
		if (match) {
			const entry = this.entries.get(match[1].toLowerCase());
			return (entry?.choices ?? []).filter(v => v.toLowerCase().startsWith(match[2].toLowerCase())).map(v => `${entry!.name} ${v}`);
		}
		return [...['help', 'list', 'find', 'clear'], ...this.list().map(e => e.name)].filter(n => n.toLowerCase().startsWith(text.toLowerCase()));
	}
	execute(line: string): Promise<ConsoleResult> {
		const task = this.queue.then(async () => {
			try { return await (this.executor ? this.executor(() => this.evaluate(line)) : this.evaluate(line)); }
			catch (error) { return { ok: false, lines: [error instanceof Error ? error.message : String(error)] }; }
		});
		this.queue = task;
		return task;
	}
	private async evaluate(line: string): Promise<ConsoleResult> {
		const match = /^([^\s=]+)(?:\s*=\s*|\s+)?(.*)$/.exec(line.trim());
		if (!match) return { ok: true, lines: [] };
		let [, name, input] = match;
		input = input.trim();
		if (name.toLowerCase() === 'clear') return { ok: true, lines: [], clear: true };
		if (['help', 'list', 'find'].includes(name.toLowerCase())) {
			return { ok: true, lines: [
				'name → query · name value / name=value → set · name ? → help · Tab → complete · ↑↓ → history',
				...this.list(input).map(e => `${e.name}${e.get ? ` = ${formatConsoleValue(e.get())}` : ' [command]'} — ${e.help}`),
			] };
		}
		if (name.endsWith('?')) { name = name.slice(0, -1); input = '?'; }
		const entry = this.entries.get(name.toLowerCase());
		if (!entry) throw new Error(`Unknown command: ${name}. Use list ${name} or help.`);
		if (input === '?') return { ok: true, lines: [entry.name, entry.help, entry.usage ?? entry.choices?.join(' | ') ?? (entry.set ? 'name value' : 'Read only / command')] };
		if (entry.run) return { ok: true, lines: [`${entry.name}: ${formatConsoleValue(await entry.run(input))}`] };
		if (input) {
			if (!entry.set) throw new Error(`${entry.name} is read only.`);
			await entry.set(input);
		}
		return { ok: true, lines: [`${entry.name} = ${formatConsoleValue(entry.get?.())}`] };
	}
}

export interface ConsoleValueType<T> { parse: (text: string) => T; usage: string; choices?: readonly string[] }
export function consoleNumber(min: number, max: number, integer = false): ConsoleValueType<number> {
	const usage = `${integer ? 'integer' : 'number'} ${min}..${max}`;
	return { usage, parse(text) {
		if (!/^[+-]?(?:\d+\.?\d*|\.\d+)(?:e[+-]?\d+)?$/i.test(text)) throw new Error(`Expected ${usage}`);
		const n = Number(text);
		if (!Number.isFinite(n) || n < min || n > max || (integer && !Number.isInteger(n))) throw new Error(`Expected ${usage}`);
		return n;
	} };
}
export const consoleBoolean: ConsoleValueType<boolean> = {
	usage: '0 / 1 / false / true / off / on', choices: ['0', '1'], parse(text) {
		if (/^(1|true|on)$/i.test(text)) return true;
		if (/^(0|false|off)$/i.test(text)) return false;
		throw new Error('Expected 0 / 1 / false / true / off / on');
	},
};
export function consoleEnum<T extends string | number>(values: Record<string, T>): ConsoleValueType<T> {
	const entries = Object.entries(values);
	return { usage: entries.map(([k, v]) => k === v ? k : `${k}=${v}`).join(' | '), choices: Object.keys(values), parse(text) {
		const value = entries.find(([k, v]) => k.toLowerCase() === text.toLowerCase() || String(v).toLowerCase() === text.toLowerCase());
		if (!value) throw new Error(`Expected ${Object.keys(values).join(' / ')}`);
		return value[1];
	} };
}
export const consoleVector: ConsoleValueType<[number, number, number]> = {
	usage: 'R G B or [R,G,B], finite nonnegative values', parse(text) {
		const values: unknown = text.startsWith('[') ? JSON.parse(text) : text.split(/[\s,]+/).map(v => Number(v));
		if (!Array.isArray(values) || values.length !== 3 || !values.every(v => typeof v === 'number' && Number.isFinite(v) && v >= 0 && v <= 1e6)) throw new Error('Expected three finite nonnegative color values');
		return values as [number, number, number];
	},
};
