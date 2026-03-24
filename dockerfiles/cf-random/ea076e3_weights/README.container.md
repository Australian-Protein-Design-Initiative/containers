# CF-random Docker Image (with Weights and Databases)

This Docker image provides a containerized environment for CF-random, a tool for predicting alternative protein conformations and fold-switching proteins using AlphaFold2-based sequence association.

**IMPORTANT**: This version includes pre-downloaded AlphaFold2 weights and PDB database, making the image significantly larger (~50GB+).

## Source Information

**Repository**: https://github.com/ncbi/CF-random_software
**Branch/Tag**: main
**LocalColabFold**: https://github.com/YoshitakaMo/localcolabfold
**Citation**: Lee, M., Schafer, J.W., Prabakaran, J. et al. Large-scale predictions of alternative protein conformations by AlphaFold2-based sequence association. Nat Commun 16, 5622 (2025). https://doi.org/10.1038/s41467-025-60759-5

## Description

CF-random predicts alternative conformations and fold-switching proteins by sampling AlphaFold2 predictions with different multiple sequence alignments (MSAs). It integrates LocalColabFold for structure prediction and Foldseek for database searches.

## Pre-Installed Components

This image includes:

1. **AlphaFold2 Weights** (~4GB)
   - Downloaded to `/opt/conda/params/`
   - Includes all necessary model weights for inference

2. **Foldseek PDB Database** (~50GB)
   - Downloaded to `/opt/foldseek/pdb/`
   - Complete PDB structure database for homology searches
   - Ready for blind mode and structure searches

3. **All Dependencies**
   - Python 3.10 with conda environment
   - ColabFold with JAX[cuda12]
   - TensorFlow
   - OpenMM, PDBFixer
   - Kalign2, HHsuite, MMseqs2, Foldseek
   - CF-random dependencies (textalloc, tmtools, adjustText, etc.)
   - PyMOL-open-source

## Usage Examples

### Basic Help

```bash
docker run --rm cf-random:latest python /opt/cf-random/code/main.py --help
```

### Fold-Switching Mode with GPU

Predict fold-switching proteins with reference structures:

```bash
docker run --gpus all \
  -v $(pwd)/data:/workspace/data \
  -v $(pwd)/output:/workspace/output \
  -w /workspace/data \
  cf-random:latest \
  python /opt/cf-random/code/main.py \
  --fname 2oug_C-search/ \
  --pdb1 2oug_C.pdb \
  --pdb2 6c6s_D.pdb \
  --option FS
```

### Alternative Conformation Mode

Predict alternative conformations:

```bash
docker run --gpus all \
  -v $(pwd)/data:/workspace/data \
  -v $(pwd)/output:/workspace/output \
  -w /workspace/data \
  cf-random:latest \
  python /opt/cf-random/code/main.py \
  --fname 5olw_A-search \
  --pdb1 5olw_A.pdb \
  --pdb2 5olx_A.pdb \
  --option AC \
  --nMSA 5
```

### Blind Mode

For blind mode, use the pre-installed PDB database:

```bash
docker run --gpus all \
  -v $(pwd)/data:/workspace/data \
  -v $(pwd)/output:/workspace/output \
  -w /workspace/data \
  cf-random:latest \
  python /opt/cf-random/code/main.py \
  --pname Mad2_test \
  --fname 2vfx_L-search/ \
  --option blind
```

### Using ColabFold Directly

```bash
docker run --gpus all \
  -v $(pwd)/input:/workspace/input \
  -v $(pwd)/output:/workspace/output \
  -w /workspace \
  cf-random:latest \
  colabfold_batch \
  /workspace/input \
  /workspace/output \
  --model-type ptm
```

### Using Foldseek Directly

```bash
docker run --rm \
  -v $(pwd)/structures:/workspace/structures \
  cf-random:latest \
  foldseek search \
  /workspace/structures \
  /opt/foldseek/pdb \
  /workspace/output
```

## Volume Mounts

- **`/workspace/data`**: Directory for input files (MSA, PDB files, etc.)
- **`/workspace/output`**: Directory for output files
- **`/opt/conda/params`**: AlphaFold2 weights (pre-installed, read-only)
- **`/opt/foldseek/pdb`**: PDB database (pre-installed, read-only)
- **`/opt/cf-random/code`**: Directory containing CF-random Python scripts

## Environment Variables

- **`CONDA_DEFAULT_ENV=cf-random`**: The conda environment is already activated
- **`PATH`**: Includes `/opt/conda/envs/cf-random/bin` where all tools are installed

## GPU Support

This image includes JAX with CUDA support. To use GPU acceleration:

```bash
docker run --gpus all ...
```

Make sure you have the NVIDIA Docker runtime installed and your GPU drivers are up to date (CUDA 12.1+ required).

## Disk Space Requirements

This image is approximately **50GB+** due to:

- AlphaFold2 weights: ~4GB
- Foldseek PDB database: ~50GB
- Base dependencies: ~10GB

Ensure you have sufficient disk space available.

## Input Requirements

- **MSA files**: Should be in A3M format, typically in a subdirectory (e.g., `protein-search/0.a3m`)
- **PDB files**: Should have a single chain, not multiple chains
- **Reference PDBs**: For default modes (FS and AC), you need reference PDB files
- **range_fs_pairs_all.txt**: Required for fold-switching mode to define residue ranges

## Image Size Considerations

- **Without weights/databases**: ~18GB
- **With weights and PDB database**: ~50GB+

If you need a smaller image and are willing to download weights/databases at runtime, use the base Dockerfile without pre-installed weights.

## Troubleshooting

### Out of Memory Errors

If you encounter GPU memory issues, try reducing the number of models or using a smaller batch size.

### Database Not Found

The PDB database is pre-installed at `/opt/foldseek/pdb`. If you need a different database, mount it to `/workspace/databases`.

### MSA Format Issues

Ensure your MSA files are in A3M format compatible with ColabFold.

## Additional Tools

The image also includes:
- **colabfold_batch**: Main ColabFold batch prediction tool
- **foldseek**: Fast and sensitive protein structure search
- **kalign2**: Multiple sequence alignment tool
- **mmseqs2**: Ultra-fast and sensitive sequence search
- **pymol**: Molecular visualization (pymol-open-source)

## License

Please see the LICENSE.md file in the CF-random repository for licensing information.
