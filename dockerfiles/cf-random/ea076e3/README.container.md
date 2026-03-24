# CF-random Docker Image

This Docker image provides a containerized environment for CF-random, a tool for predicting alternative protein conformations and fold-switching proteins using AlphaFold2-based sequence association.

## Source Information

**Repository**: https://github.com/ncbi/CF-random_software
**Branch/Tag**: main
**LocalColabFold**: https://github.com/YoshitakaMo/localcolabfold
**Citation**: Lee, M., Schafer, J.W., Prabakaran, J. et al. Large-scale predictions of alternative protein conformations by AlphaFold2-based sequence association. Nat Commun 16, 5622 (2025). https://doi.org/10.1038/s41467-025-60759-5

## Description

CF-random predicts alternative conformations and fold-switching proteins by sampling AlphaFold2 predictions with different multiple sequence alignments (MSAs). It integrates LocalColabFold for structure prediction and Foldseek for database searches.

## Database Setup

The image includes Foldseek but does NOT pre-download any databases. To use the blind mode or other database-dependent features, you need to download and mount the Foldseek databases.

### Downloading AlphaFold2 Weights

The image does NOT include pre-downloaded AlphaFold2 weights. Download them at first use:

```bash
docker run --rm -v /path/to/params:/params cf-random:latest \
    python -m colabfold.download
```

Then mount the params directory when running:
```bash
docker run -v /path/to/params:/params cf-random:latest ...
```

### Downloading Foldseek Databases

Before running the container, download the PDB database (or any other Foldseek database you need):

```bash
# Create a directory for databases on your host
mkdir -p /path/to/databases

# Download PDB database (this will take some time and requires ~50GB+)
# Run this outside the container or mount the database directory
docker run --rm -v /path/to/databases:/databases cf-random:latest \
    foldseek databases PDB /databases/pdb /databases/tmp
```

Alternatively, you can download databases using foldseek directly on your host system if you have it installed, then mount the directory into the container.

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

### Blind Mode with Foldseek Databases

For blind mode, you need to mount the Foldseek databases:

```bash
docker run --gpus all \
    -v $(pwd)/data:/workspace/data \
    -v $(pwd)/output:/workspace/output \
    -v /path/to/databases:/workspace/databases \
    -w /workspace/data \
    cf-random:latest \
    python /opt/cf-random/code/main.py \
    --pname Mad2_test \
    --fname 2vfx_L-search/ \
    --option blind
```

### Using ColabFold Directly

You can also use LocalColabFold directly:

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

## Volume Mounts

- **`/workspace/data`**: Directory for input files (MSA, PDB files, etc.)
- **`/workspace/output`**: Directory for output files
- **`/workspace/databases`**: Directory for Foldseek databases (if using blind mode)
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

## Input Requirements

- **MSA files**: Should be in A3M format, typically in a subdirectory (e.g., `protein-search/0.a3m`)
- **PDB files**: Should have a single chain, not multiple chains
- **Reference PDBs**: For default modes (FS and AC), you need reference PDB files
- **range_fs_pairs_all.txt**: Required for fold-switching mode to define residue ranges

## Troubleshooting

### Out of Memory Errors

If you encounter GPU memory issues, try reducing the number of models or using a smaller batch size.

### Database Not Found

For blind mode, ensure you've downloaded the Foldseek databases and mounted them correctly to `/workspace/databases`.

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
