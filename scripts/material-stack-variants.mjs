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

// Lossless encoding of actual Slang output, not a hand-maintained rewrite of WGSL logic.
export function encodeVariant(base, variant) {
	const before = base.split('\n'), after = variant.split('\n');
	const edits = [];
	if (before.length === after.length) {
		let offset = 0;
		for (let i = 0; i < before.length; i++) {
			if (before[i] !== after[i]) edits.push(edit(before[i], after[i], offset));
			offset += before[i].length + 1;
		}
	} else if (base !== variant) edits.push(edit(base, variant, 0));
	let cursor = 0, restored = '';
	for (const [offset, oldText, newText] of edits) {
		if (base.slice(offset, offset + oldText.length) !== oldText) throw new Error('Invalid generated shader edit');
		restored += base.slice(cursor, offset) + newText;
		cursor = offset + oldText.length;
	}
	restored += base.slice(cursor);
	if (restored !== variant) throw new Error('Shader specialization encoding differs from Slang output');
	return { sha256: createHash('sha256').update(variant).digest('hex'), edits };
}
