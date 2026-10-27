// List scheduling for a pure expression DAG. Texture nodes additionally retain their
// original order because stochastic mip sampling consumes per-path random state.
export function scheduleInstructions(
	order: readonly number[], dependencies: ReadonlyMap<number, ReadonlySet<number>>,
	outputs: ReadonlySet<number>, textures: ReadonlySet<number>,
): number[] {
	if (order.length < 2) return [...order];
	const uses = new Map<number, number>();
	for (const operands of dependencies.values()) for (const n of operands) uses.set(n, (uses.get(n) ?? 0) + 1);
	for (const n of outputs) uses.set(n, (uses.get(n) ?? 0) + 1);
	const remaining = new Map(uses), depth = new Map<number, number>();
	const waiting = new Map<number, number>(), consumers = new Map<number, number[]>();
	let previousTexture: number | undefined;
	for (const n of order) {
		const operands = dependencies.get(n)!;
		depth.set(n, 1 + Math.max(0, ...[...operands].map(d => depth.get(d)!)));
		const required = new Set(operands);
		if (textures.has(n)) {
			if (previousTexture !== undefined) required.add(previousTexture);
			previousTexture = n;
		}
		waiting.set(n, required.size);
		for (const d of required) {
			const list = consumers.get(d) ?? [];
			list.push(n); consumers.set(d, list);
		}
	}
	const ready = new Set(order.filter(n => waiting.get(n) === 0)), scheduled: number[] = [];
	while (ready.size) {
		let best = -1, bestFree = -1;
		for (const n of ready) {
			const freed = [...dependencies.get(n)!].filter(d => remaining.get(d) === 1).length;
			if (freed > bestFree || (freed === bestFree && (depth.get(n)! > (depth.get(best) ?? -1)
				|| (depth.get(n) === depth.get(best) && n < best)))) {
				best = n; bestFree = freed;
			}
		}
		ready.delete(best); scheduled.push(best);
		for (const d of dependencies.get(best)!) remaining.set(d, remaining.get(d)! - 1);
		for (const n of consumers.get(best) ?? []) {
			const count = waiting.get(n)! - 1;
			waiting.set(n, count);
			if (count === 0) ready.add(n);
		}
	}
	if (scheduled.length !== order.length) throw new Error('Material scheduling dependency cycle');
	const peak = (sequence: readonly number[]) => {
		const remaining = new Map(uses);
		let live = 0, maximum = 0;
		for (const n of sequence) {
			// The interpreter reads all operands before writing the result, so its slot
			// allocator can reuse a dying operand in this same instruction.
			for (const d of dependencies.get(n)!) {
				const count = remaining.get(d)! - 1;
				remaining.set(d, count);
				if (count === 0) live--;
			}
			live++; maximum = Math.max(maximum, live);
		}
		return maximum;
	};
	// Preserve original bytecode ordering unless the simulated allocator improves.
	return peak(scheduled) < peak(order) ? scheduled : [...order];
}
