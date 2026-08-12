# SwitchCraft Container Image

## Source Repository
- **Repository**: https://github.com/bjing2016/switchcraft.git
- **Ref**: `67ffc0d`
- **Runtime**: Python 3.10 on NVIDIA CUDA 12.6

## Description
SwitchCraft is a framework for designing state-switching proteins via gradient-based
optimization through an AF3-style co-folding model (Boltz-1). Given a multistate design
objective, SwitchCraft constructs and optimizes a compositional loss function to design a
sequence that exhibits the desired multistate behavior.

Paper: **SwitchCraft: A Programmatic Framework for Designing State Switching Proteins**
(Jing, Bafna, Parsan, Ni, Kwabi-Addo, Bryson, Klivans, Berger — ICML 2026).
Preprint: https://arxiv.org/abs/2605.31236

## Model Weights
By default this image **includes** the required model weights, so it runs out of the box:

- `boltz/ccd.pkl` — CCD ligand database
- `boltz/boltz1_conf.ckpt` — Boltz-1 structure model checkpoint
- `LigandMPNN/model_params/` — LigandMPNN weights (only needed for `--ligandmpnn_seqs`)

Weights are stored under `/models/switchcraft/` and symlinked into the repo tree at
`/app/boltz/` and `/app/LigandMPNN/`, where the source code expects them.

> To build a smaller (~3.5 GB lighter) image without weights, pass
> `--build-arg DOWNLOAD_WEIGHTS=false`. You must then bind-mount `boltz1_conf.ckpt`
> (and, for LigandMPNN redesign, the model params) at runtime — see below.

## Usage

The application lives in `/app` (the image `WORKDIR`) and the default `CMD` prints help.
Output is written to `/output`, which is created during the build.

### Apptainer / Singularity (GPU)

Use `--pwd /app` so relative paths in the repo resolve, and `--nv` to expose the GPU:

```bash
apptainer run --nv --pwd /app \
    --bind "$(pwd)/output":/output \
    switchcraft_67ffc0d.sif \
    python3 switchcraft.py --config tasks/pos_allostery.yaml --out /output --verbose
```

> Note: Apptainer bind-mounts your current working directory and `$HOME` by default. If you
> omit `--pwd /app`, the working directory inside the container becomes your host CWD and the
> repo files under `/app` (`tasks/`, `motifs/`, `boltz/`) will not be found.

### Docker (GPU)

```bash
docker run --rm --gpus all \
    -v "$(pwd)/output":/output \
    -w /app \
    switchcraft:67ffc0d \
    python3 switchcraft.py --config tasks/pos_allostery.yaml --out /output --verbose
```

### Running a weights-free (slim) build

If you built with `--build-arg DOWNLOAD_WEIGHTS=false`, bind-mount the checkpoint:

```bash
apptainer run --nv --pwd /app \
    --bind /path/to/boltz1_conf.ckpt:/app/boltz/boltz1_conf.ckpt \
    --bind "$(pwd)/output":/output \
    switchcraft_67ffc0d_slim.sif \
    python3 switchcraft.py --config tasks/pos_allostery.yaml --out /output --verbose
```

The Boltz-1 checkpoint can be downloaded from
https://huggingface.co/boltz-community/boltz-1/resolve/main/boltz1_conf.ckpt

## Example Tasks
Template configs live in `tasks/` inside the image:

| Config | Description |
| --- | --- |
| `pos_allostery.yaml` | Motif absent when apo, formed when ligand binds (quick start) |
| `neg_allostery.yaml` | Motif active when apo, disrupted when ligand binds |
| `induced_binding.yaml` | Target binding switched on by an effector ligand |
| `ligand_discrimination.yaml` | Different conformations for different ligands |
| `motif_switching.yaml` | Motif 1 active apo, motif 2 active holo |

Motif PDBs are provided under `motifs/` (e.g. `1prw` used by the allostery examples).

### Output
For each design, written to `<out>/<motif>/design<N>/`:
- `state<i>_sample<j>.pdb` / `.cif` — predicted structures (5 diffusion samples per state)
- `state<i>.pkl` — raw model output (pLDDT, pTM, iP TM, PAE, PDE, etc.)
- `<motif>_spec.pkl` — motif specification used for evaluation

## Resource Notes
- Requires an NVIDIA GPU with CUDA 12.x support. A single design optimization typically uses
  ~6 GB of GPU memory and takes several minutes (depending on scaffold length and recycle count).
- Pass `--ligandmpnn_seqs N` (N > 0) to additionally run LigandMPNN sequence redesign.

## Citation
Bowen Jing, Mihir Bafna, Anisha Parsan, Heyuan Michael Ni, David Kwabi-Addo, Bryan Bryson,
Adam Klivans, Bonnie Berger. *SwitchCraft: A Programmatic Framework for Designing State
Switching Proteins.* ICML 2026.

## License
MIT (see the SwitchCraft repository). Separate licenses may apply to third-party source code
(Boltz, LigandMPNN) and to the bundled model weights.
