export function sourceChecksum(source: string): number;
export function encodeVariant(base: string, variant: string): {
	sha256: string;
	edits: [number, number, string][];
};
