// Compiles pipelines with createComputePipelineAsync / createRenderPipelineAsync, so they compile in
// parallel and off the main thread, and reports progress. Without a browser pipeline cache the path
// tracer alone takes seconds; the renderer is handed out only once everything has compiled.
export class PipelineCompiler {
	private readonly jobs: { label: string; weight: number; done: boolean; promise: Promise<unknown> }[] = [];
	private onChange: (() => void) | null = null;

	constructor(private readonly device: GPUDevice) {}

	// weight: share of the total compile time, for progress only.
	compute(descriptor: GPUComputePipelineDescriptor, weight = 1): Promise<GPUComputePipeline> {
		return this.track(descriptor.label ?? 'compute', weight, this.device.createComputePipelineAsync(descriptor));
	}

	render(descriptor: GPURenderPipelineDescriptor, weight = 1): Promise<GPURenderPipeline> {
		return this.track(descriptor.label ?? 'render', weight, this.device.createRenderPipelineAsync(descriptor));
	}

	private track<T>(label: string, weight: number, promise: Promise<T>): Promise<T> {
		const job = { label, weight, done: false, promise };
		this.jobs.push(job);
		promise.then(
			() => {
				job.done = true;
				this.onChange?.();
			},
			() => {},
		);
		return promise;
	}

	// Resolves once every pipeline started so far has compiled (rejects with the first failure).
	// onProgress gets the completed share of the weights and the labels still compiling.
	async wait(onProgress?: (fraction: number, pending: string[]) => void): Promise<void> {
		const report = () => {
			const total = this.jobs.reduce((s, j) => s + j.weight, 0);
			const done = this.jobs.reduce((s, j) => s + (j.done ? j.weight : 0), 0);
			onProgress?.(total > 0 ? done / total : 1, this.jobs.filter((j) => !j.done).map((j) => j.label));
		};
		this.onChange = report;
		report();
		try {
			await Promise.all(this.jobs.map((j) => j.promise));
		} finally {
			this.onChange = null;
		}
	}
}
