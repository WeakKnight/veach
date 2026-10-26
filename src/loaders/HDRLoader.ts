// Radiance .hdr (RGBE) loader, supporting flat and new-style RLE scanlines.
export interface HDRImage {
	width: number;
	height: number;
	data: Float32Array; // rgba, linear, row 0 = top
}

export function parseHDR(buffer: ArrayBuffer): HDRImage {
	const bytes = new Uint8Array(buffer);
	let pos = 0;
	const readLine = () => {
		let s = '';
		while (pos < bytes.length && bytes[pos] !== 0x0a) {
			s += String.fromCharCode(bytes[pos++]);
		}
		pos++;
		return s;
	};

	const magic = readLine();
	if (!magic.startsWith('#?')) {
		throw new Error('HDR: bad magic');
	}
	let format = '';
	for (let line = readLine(); line.length > 0; line = readLine()) {
		if (line.startsWith('FORMAT=')) {
			format = line.slice(7).trim();
		}
		if (pos >= bytes.length) {
			throw new Error('HDR: truncated header');
		}
	}
	if (format && format !== '32-bit_rle_rgbe') {
		throw new Error(`HDR: unsupported format ${format}`);
	}
	const res = readLine().trim().match(/^([-+])Y\s+(\d+)\s+([-+])X\s+(\d+)$/);
	if (!res) {
		throw new Error('HDR: unsupported resolution line');
	}
	const flipY = res[1] === '+';
	const flipX = res[3] === '-';
	const height = parseInt(res[2], 10);
	const width = parseInt(res[4], 10);

	const rgbe = new Uint8Array(width * height * 4);
	const scanline = new Uint8Array(width * 4);
	for (let y = 0; y < height; y++) {
		if (width >= 8 && width < 32768 && bytes[pos] === 2 && bytes[pos + 1] === 2 && ((bytes[pos + 2] << 8) | bytes[pos + 3]) === width) {
			pos += 4;
			for (let c = 0; c < 4; c++) {
				let x = 0;
				while (x < width) {
					let count = bytes[pos++];
					if (count > 128) {
						count -= 128;
						const value = bytes[pos++];
						for (let i = 0; i < count && x < width; i++) {
							scanline[(x++) * 4 + c] = value;
						}
					} else {
						for (let i = 0; i < count && x < width; i++) {
							scanline[(x++) * 4 + c] = bytes[pos++];
						}
					}
				}
			}
		} else {
			// flat (or old-style RLE, treated as flat)
			scanline.set(bytes.subarray(pos, pos + width * 4));
			pos += width * 4;
		}
		if (pos > bytes.length) {
			throw new Error('HDR: truncated data');
		}
		rgbe.set(scanline, y * width * 4);
	}

	const data = new Float32Array(width * height * 4);
	for (let y = 0; y < height; y++) {
		const dstY = flipY ? height - 1 - y : y;
		for (let x = 0; x < width; x++) {
			const dstX = flipX ? width - 1 - x : x;
			const s = (y * width + x) * 4;
			const d = (dstY * width + dstX) * 4;
			const e = rgbe[s + 3];
			const f = e ? Math.pow(2, e - 136) : 0; // 2^(e - 128) / 256
			data[d] = rgbe[s] * f;
			data[d + 1] = rgbe[s + 1] * f;
			data[d + 2] = rgbe[s + 2] * f;
			data[d + 3] = 1;
		}
	}
	return { width, height, data };
}

export async function loadHDR(url: string): Promise<HDRImage> {
	const res = await fetch(url);
	if (!res.ok) {
		throw new Error(`Failed to fetch ${url}: ${res.status}`);
	}
	return parseHDR(await res.arrayBuffer());
}
