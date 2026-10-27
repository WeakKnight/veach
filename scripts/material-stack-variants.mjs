import { createHash } from 'node:crypto';

export function sourceChecksum(source) {
	let hash = 2166136261;
	for (let i = 0; i < source.length; i++) hash = Math.imul(hash ^ source.charCodeAt(i), 16777619) >>> 0;
	return hash;
}

function edit(before, after, offset) {
	let prefix = 0, suffix = 0;
	while (prefix < before.length && prefix < after.length && before[prefix] === after[prefix]) prefix++;
	while (suffix < before.length - prefix && suffix < after.length - prefix && before.at(-suffix - 1) === after.at(-suffix - 1)) suffix++;
	return [offset + prefix, before.slice(prefix, before.length - suffix), after.slice(prefix, after.length - suffix)];
}

// Patience anchors preserve unchanged shader regions even when specialization removes
// whole functions. A single prefix/suffix edit would embed almost both complete modules.
function changedRanges(before, after) {
	const ranges = [];
	function visit(a0, a1, b0, b1) {
		while (a0 < a1 && b0 < b1 && before[a0] === after[b0]) { a0++; b0++; }
		while (a0 < a1 && b0 < b1 && before[a1 - 1] === after[b1 - 1]) { a1--; b1--; }
		if (a0 === a1 && b0 === b1) return;
		const unique = (lines, start, end) => {
			const positions = new Map();
			for (let i = start; i < end; i++) positions.set(lines[i], positions.has(lines[i]) ? -1 : i);
			return positions;
		};
		const a = unique(before, a0, a1), b = unique(after, b0, b1);
		const pairs = [...a].filter(([line, i]) => i >= 0 && (b.get(line) ?? -1) >= 0).map(([line, i]) => [i, b.get(line)]);
		// Longest increasing subsequence selects anchors without crossing/reordering edits.
		const tails = [], previous = [];
		for (let i = 0; i < pairs.length; i++) {
			let lo = 0, hi = tails.length;
			while (lo < hi) {
				const mid = (lo + hi) >>> 1;
				if (pairs[tails[mid]][1] < pairs[i][1]) lo = mid + 1;
				else hi = mid;
			}
			previous[i] = lo ? tails[lo - 1] : -1;
			tails[lo] = i;
		}
		if (!tails.length) { ranges.push([a0, a1, b0, b1]); return; }
		const anchors = [];
		for (let i = tails.at(-1); i >= 0; i = previous[i]) anchors.push(pairs[i]);
		for (const [ai, bi] of anchors.reverse()) {
			visit(a0, ai, b0, bi);
			a0 = ai + 1; b0 = bi + 1;
		}
		visit(a0, a1, b0, b1);
	}
	visit(0, before.length, 0, after.length);
	return ranges;
}

// Lossless encoding of actual Slang output, not a hand-maintained rewrite of WGSL logic.
export function encodeVariant(base, variant) {
	// Preserve terminators: an EOF line and an otherwise equal newline-terminated
	// line are different anchors, including when the variant adds a trailing newline.
	const before = base.match(/[^\n]*\n|[^\n]+$/g) ?? [], after = variant.match(/[^\n]*\n|[^\n]+$/g) ?? [];
	const edits = [];
	if (before.length === after.length) {
		let offset = 0;
		for (let i = 0; i < before.length; i++) {
			if (before[i] !== after[i]) edits.push(edit(before[i], after[i], offset));
			offset += before[i].length;
		}
	} else {
		const offsets = (lines, size) => {
			const result = [0];
			for (const line of lines) result.push(Math.min(size, result.at(-1) + line.length));
			return result;
		};
		const a = offsets(before, base.length), b = offsets(after, variant.length);
		for (const [a0, a1, b0, b1] of changedRanges(before, after))
			edits.push(edit(base.slice(a[a0], a[a1]), variant.slice(b[b0], b[b1]), a[a0]));
	}
	let cursor = 0, restored = '';
	for (const [offset, oldText, newText] of edits) {
		if (base.slice(offset, offset + oldText.length) !== oldText) throw new Error('Invalid generated shader edit');
		restored += base.slice(cursor, offset) + newText;
		cursor = offset + oldText.length;
	}
	restored += base.slice(cursor);
	if (restored !== variant) throw new Error('Shader specialization encoding differs from Slang output');
	// Runtime verifies the whole base fingerprint, so repeating deleted source text
	// in the bundle is redundant. Validate the text above, then retain only its length.
	return { sha256: createHash('sha256').update(variant).digest('hex'),
		edits: edits.map(([offset, oldText, newText]) => [offset, oldText.length, newText]) };
}
