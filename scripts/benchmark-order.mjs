// Every variant occupies each measurement position once per complete cycle.
// Reverse alternate cycles to counter the direction of neighboring variants.
export function balancedMeasurementOrder(variants, repeat) {
	if (!variants.length || !Number.isSafeInteger(repeat) || repeat < 0) throw new Error('Invalid measurement order');
	const offset = repeat % variants.length;
	const ordered = [...variants.slice(offset), ...variants.slice(0, offset)];
	return Math.floor(repeat / variants.length) % 2 === 0 ? ordered : ordered.reverse();
}
