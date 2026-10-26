// Optimization of lowered graphs: constant folding, identities and merging (through GraphBuilder),
// inactive OpenPBR lobes and default-valued surface inputs removed, then dead nodes.
import { GraphBuilder, constantOf, isConnection, isConstant, toArg, type Arg, type GraphNode, type Input, type MaterialGraph } from './Graph';
import { OPEN_PBR_SURFACE } from './NodeDefs';

type Args = Record<string, Arg | undefined>;

// Inputs that have no effect when the lobe weight is the constant 0.
const LOBES: [string, string[]][] = [
	['transmission_weight', ['transmission_color', 'transmission_depth', 'transmission_scatter', 'transmission_scatter_anisotropy', 'transmission_dispersion_scale', 'transmission_dispersion_abbe_number']],
	['subsurface_weight', ['subsurface_color', 'subsurface_radius', 'subsurface_radius_scale', 'subsurface_scatter_anisotropy']],
	['coat_weight', ['coat_color', 'coat_roughness', 'coat_roughness_anisotropy', 'coat_ior', 'coat_darkening', 'geometry_coat_normal', 'geometry_coat_tangent']],
	['fuzz_weight', ['fuzz_color', 'fuzz_roughness']],
	['thin_film_weight', ['thin_film_thickness', 'thin_film_ior']],
	['emission_luminance', ['emission_color']],
	['specular_roughness_anisotropy', ['geometry_tangent']],
	['coat_roughness_anisotropy', ['geometry_coat_tangent']],
];

function isWeightZero(inputs: Args, name: string): boolean {
	const value = inputs[name];
	return value === undefined ? isConstant(OPEN_PBR_SURFACE[name].default, 0) : isConstant(value, 0);
}

function pruneSurface(inputs: Args): Args {
	const out: Args = { ...inputs };
	if (isConstant(out.emission_color, 0)) {
		delete out.emission_luminance;
	}
	for (const [weight, dependents] of LOBES) {
		if (isWeightZero(out, weight)) {
			delete out[weight];
			dependents.forEach((name) => delete out[name]);
		}
	}
	for (const [name, arg] of Object.entries(out)) {
		const def = OPEN_PBR_SURFACE[name];
		if (!def) {
			throw new Error(`material graph: open_pbr_surface has no input ${name}`);
		}
		const value = constantOf(arg);
		if (arg === undefined || (value && def.default && value.length === def.default.length && value.every((v, i) => v === def.default![i]))) {
			delete out[name];
		}
	}
	return out;
}

// Keeps the nodes the surface depends on, in order.
function removeDeadNodes(nodes: GraphNode[], surface: number): { nodes: GraphNode[]; surface: number } {
	const live = new Array<boolean>(nodes.length).fill(false);
	live[surface] = true;
	for (let i = surface; i >= 0; i--) {
		if (live[i]) {
			for (const input of Object.values(nodes[i].inputs)) {
				if (isConnection(input)) {
					live[input.node] = true;
				}
			}
		}
	}
	const remap = new Array<number>(nodes.length).fill(-1);
	const out: GraphNode[] = [];
	nodes.forEach((node, i) => {
		if (!live[i]) {
			return;
		}
		const inputs: Record<string, Input> = {};
		for (const [name, input] of Object.entries(node.inputs)) {
			inputs[name] = isConnection(input) ? { node: remap[input.node], output: input.output } : input;
		}
		remap[i] = out.push({ ...node, inputs }) - 1;
	});
	return { nodes: out, surface: remap[surface] };
}

export function optimizeGraph(graph: MaterialGraph): MaterialGraph {
	const surfaceNode = graph.nodes[graph.surface];
	if (surfaceNode?.category !== 'open_pbr_surface') {
		throw new Error('material graph: optimize expects a lowered graph');
	}
	const b = new GraphBuilder();
	const mapped: Arg[] = [];
	let surface = -1;
	graph.nodes.forEach((node, index) => {
		const i: Args = {};
		for (const [name, input] of Object.entries(node.inputs)) {
			if (isConnection(input) && input.output !== 'out') {
				throw new Error('material graph: optimize expects single-output nodes');
			}
			i[name] = isConnection(input) ? mapped[input.node] : toArg(input);
		}
		if (index === graph.surface) {
			const c = b.node('open_pbr_surface', 'surfaceshader', pruneSurface(i));
			surface = c.node;
			mapped.push(c);
		} else {
			mapped.push(b.replay(node.category, node.type, i));
		}
	});
	return { ...graph, ...removeDeadNodes(b.nodes, surface) };
}
