# EnGens Container Image (Python 3.11)

## Source Repository
- **Repository**: https://github.com/KavrakiLab/EnGens.git
- **Ref**: `b097882` (main)
- **Runtime**: Python 3.11 (modernised; upstream ships Python 3.6)

## Description
EnGens is a computational framework for generation and analysis of representative protein conformational ensembles. This image includes a Python 3.11 conda environment, Jupyter notebooks, mTM-align, patched HDE, and Quarto.

Documentation: https://engens.readthedocs.io/en/latest/

### Notable differences from upstream Docker image
- Python **3.11** instead of 3.6
- Dependency set refreshed via `environment.yml` in this directory (not upstream's pinned 3.6 env)
- `pytraj` replaced with `mdtraj` + `nglview.show_mdtraj` (pytraj has no 3.11 builds)
- Upstream `pdbfixer` patch skipped (it forced the CUDA OpenMM platform)
- Biopython pinned to `<1.86` so `Bio.Align.Applications.ClustalOmegaCommandline` remains available
- HDE package `__init__` limited to the `HDE` class (molgen/propagator need obsolete Keras APIs unused by EnGens)

## Usage

### Jupyter notebooks (default)
```bash
docker run -it --rm -p 8888:8888 \
  -v $(pwd):/home/mambauser/work \
  engens:2024-11-22_b097882_py311
```

Open the printed notebook URL, then use the workflow notebooks in the home directory:
- `Workflow1-crystal_structures.ipynb` (static / UniProt workflow)
- `Workflow1-FeatureExtraction.ipynb` (dynamic / MD trajectory workflow)
- `Workflow2-DimensionalityReduction.ipynb`
- `Workflow3-Clustering.ipynb`
- `Workflow4-ResultSummary.ipynb`

Mount local data under `/home/mambauser/work` so it persists on the host.

### Quarto
```bash
docker run --rm -v $(pwd):/home/mambauser/work -w /home/mambauser/work engens:2024-11-22_b097882_py311 \
  quarto --version

docker run --rm -v $(pwd):/home/mambauser/work -w /home/mambauser/work engens:2024-11-22_b097882_py311 \
  quarto render your-document.qmd
```

### Interactive shell
```bash
docker run -it --rm -v $(pwd):/home/mambauser/work engens:2024-11-22_b097882_py311 bash
```

## External data
No large model weights are required at build time. For the dynamic workflow, provide your own MD trajectory (e.g. PDB + XTC) via the `/home/mambauser/work` mount. Example trajectories are included under the image home directory (`ExampleProt.pdb`, `ExampleTraj.xtc`).

## Citation
Conev et al., Briefings in Bioinformatics (2023). DOI: [10.1093/bib/bbad242](https://doi.org/10.1093/bib/bbad242)
