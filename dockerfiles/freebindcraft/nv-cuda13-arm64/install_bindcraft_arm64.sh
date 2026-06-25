#!/bin/bash
################## FreeBindCraft installation script — aarch64 / arm64 (e.g. NVIDIA GB10 / Grace-Blackwell, GH200)
##################
## Why a separate script? On aarch64 the upstream install_bindcraft.sh fails because:
##   * conda has no aarch64 jax/jaxlib CUDA builds       -> we install jax via pip instead.
##   * the bundled functions/{dssp,sc,FASPR,DAlphaBall.gcc} are x86-64 binaries
##       -> dssp is replaced with conda-forge's aarch64 mkdssp,
##       -> sc (shape complementarity, from github.com/cytokineking/sc-rs) and FASPR
##          (side-chain repacking, from github.com/tommyhuangthu/FASPR) are rebuilt from
##          source for aarch64 (pure Rust / plain C++, no native deps -> trivial cross-arch build),
##       -> DAlphaBall.gcc is only needed when PyRosetta is installed; it is rebuilt the same
##          way as for upstream BindCraft when --with-pyrosetta is requested.
##   * PyRosetta (optional, OFF by default — that's the "Free" in FreeBindCraft) has no pip
##     build for aarch64 -> when requested, it is installed from the RosettaCommons conda channel.
##
## Hardware note (Blackwell GB10 / sm_120 / sm_121): these GPUs require CUDA 12.8+.
## We install jax 0.6.0 (matching upstream FreeBindCraft's pin) whose cuda12 plugin bundles
## CUDA 12.9 (supports sm_120, binary-compatible with the GB10's sm_121). jax 0.6.0 is the
## version FreeBindCraft itself pins, and it has cp310 + aarch64 wheels.
############################################################################################################

# Default values
pkg_manager='conda'
install_pyrosetta=false   # FreeBindCraft default: no PyRosetta (OpenMM + sc-rs + FASPR instead)
JAX_VERSION='0.6.0'                # matches upstream FreeBindCraft's jax/jaxlib pin
PYROSETTA_VERSION='2023.11'        # newest PyRosetta aarch64 (py310) conda build, only used if --with-pyrosetta
DSSP_ENV='BindCraft_dssp'          # only used if --with-pyrosetta (its boost pin conflicts with PyRosetta's)

# Define the short and long options
OPTIONS=p:c:nf
LONGOPTIONS=pkg_manager:,cuda:,no-pyrosetta,with-pyrosetta,fix-channels

# Parse the command-line options
PARSED=$(getopt --options=$OPTIONS --longoptions=$LONGOPTIONS --name "$0" -- "$@")
eval set -- "$PARSED"

while true; do
  case "$1" in
    -p|--pkg_manager) pkg_manager="$2"; shift 2 ;;
    -c|--cuda) shift 2 ;; # accepted for CLI compatibility with upstream; unused (pip jax brings its own CUDA)
    -n|--no-pyrosetta) install_pyrosetta=false; shift ;;
    --with-pyrosetta) install_pyrosetta=true; shift ;;
    -f|--fix-channels) shift ;; # accepted for CLI compatibility; not needed with Miniforge/conda-forge defaults
    --) shift; break ;;
    *) echo -e "Invalid option $1" >&2; exit 1 ;;
  esac
done

echo -e "Package manager: $pkg_manager"
echo -e "Install PyRosetta: $install_pyrosetta"

############################################################################################################
################## initialisation
SECONDS=0

ARCH=$(uname -m)
if [ "$ARCH" != "aarch64" ] && [ "$ARCH" != "arm64" ]; then
  echo -e "Error: this script is for aarch64/arm64 machines. Detected '$ARCH'. Use install_bindcraft.sh instead."
  exit 1
fi
echo -e "Architecture: $ARCH"

install_dir=$(pwd)
CONDA_BASE=$(conda info --base 2>/dev/null) || { echo -e "Error: conda is not installed or cannot be initialised."; exit 1; }
echo -e "Conda is installed at: $CONDA_BASE"

### create base environment
echo -e "Installing BindCraft environment\n"
$pkg_manager create --name BindCraft python=3.10 -y || { echo -e "Error: Failed to create BindCraft conda environment"; exit 1; }
conda env list | grep -w 'BindCraft' >/dev/null 2>&1 || { echo -e "Error: Conda environment 'BindCraft' does not exist after creation."; exit 1; }

echo -e "Loading BindCraft environment\n"
source ${CONDA_BASE}/bin/activate ${CONDA_BASE}/envs/BindCraft || { echo -e "Error: Failed to activate the BindCraft environment."; exit 1; }
[ "$CONDA_DEFAULT_ENV" = "BindCraft" ] || { echo -e "Error: The BindCraft environment is not active."; exit 1; }
echo -e "BindCraft environment activated at ${CONDA_BASE}/envs/BindCraft"

# install required conda packages from conda-forge (no jax/jaxlib/pyrosetta here -> handled separately below).
# freesasa has no aarch64 pip wheel, so it is installed via conda-forge instead of pip.
echo -e "Installing conda requirements (conda-forge)\n"
$pkg_manager install -c conda-forge \
  pip pandas matplotlib 'numpy<2.0.0' biopython scipy pdbfixer openmm seaborn libgfortran5 tqdm jupyter ffmpeg fsspec py3dmol \
  chex dm-haiku 'flax<0.10.0' dm-tree joblib ml-collections immutabledict optax \
  freesasa git wget \
  -y || { echo -e "Error: Failed to install conda-forge packages."; exit 1; }

# make sure required conda packages were installed
required_packages=(pip pandas libgfortran5 matplotlib numpy biopython scipy pdbfixer openmm seaborn tqdm jupyter ffmpeg fsspec py3dmol chex dm-haiku dm-tree joblib ml-collections immutabledict optax freesasa)
missing_packages=()
for pkg in "${required_packages[@]}"; do
    conda list "$pkg" | grep -w "$pkg" >/dev/null 2>&1 || missing_packages+=("$pkg")
done
if [ ${#missing_packages[@]} -ne 0 ]; then
    echo -e "Error: The following packages are missing from the environment:"
    for pkg in "${missing_packages[@]}"; do echo -e " - $pkg"; done
    exit 1
fi
python -c "import freesasa" >/dev/null 2>&1 && echo -e "FreeSASA Python module installed successfully" || echo -e "Warning: FreeSASA Python module not available - using Biopython fallback for SASA"

# install PyRosetta (optional) from the RosettaCommons aarch64 channel
if [ "$install_pyrosetta" = true ]; then
  echo -e "Installing PyRosetta ${PYROSETTA_VERSION} (aarch64)\n"
  $pkg_manager install \
    -c https://west.rosettacommons.org/pyrosetta/conda/release -c conda-forge \
    "pyrosetta=${PYROSETTA_VERSION}" -y || { echo -e "Error: Failed to install PyRosetta"; exit 1; }
  python -c "import pyrosetta" >/dev/null 2>&1 || { echo -e "Error: pyrosetta module not found after installation"; exit 1; }
fi

# install JAX (GPU) via pip — bundles CUDA 12.9, supports Blackwell sm_120/sm_121.
echo -e "Installing JAX ${JAX_VERSION} with CUDA 12 (pip)\n"
pip install -U "jax[cuda12]==${JAX_VERSION}" --timeout 120 --retries 20 --resume-retries 50 \
  || { echo -e "Error: Failed to install jax[cuda12]"; exit 1; }
if [ "${BINDCRAFT_SKIP_GPU_CHECK:-0}" = "1" ]; then
  python -c "import jax; print('JAX', jax.__version__, '— GPU check skipped (build-time); devices:', jax.devices())" \
    || { echo -e "Error: jax failed to import"; exit 1; }
else
  python -c "import jax; assert any(d.platform=='gpu' for d in jax.devices()), 'no GPU'; print('JAX devices:', jax.devices())" \
    || { echo -e "Error: JAX cannot see the GPU"; exit 1; }
fi

# install ColabDesign
echo -e "Installing ColabDesign\n"
pip3 install git+https://github.com/sokrypton/ColabDesign.git --no-deps || { echo -e "Error: Failed to install ColabDesign"; exit 1; }
python -c "import colabdesign" >/dev/null 2>&1 || { echo -e "Error: colabdesign module not found after installation"; exit 1; }

############################################################################################################
################## aarch64 binaries: dssp, sc (sc-rs), FASPR, and (optionally) DAlphaBall

# DSSP. If PyRosetta is also installed, mkdssp's conda-forge package pulls a newer libboost than
# PyRosetta pins, so co-installing them would remove PyRosetta -> install mkdssp into its own env
# instead and symlink to it. Without PyRosetta there is no such conflict, so install it directly.
if [ "$install_pyrosetta" = true ]; then
  echo -e "Installing DSSP (mkdssp) in separate env '${DSSP_ENV}' (PyRosetta's libboost pin would otherwise conflict)\n"
  $pkg_manager create --name "${DSSP_ENV}" -c conda-forge dssp -y || { echo -e "Error: Failed to create dssp environment"; exit 1; }
  DSSP_BIN="${CONDA_BASE}/envs/${DSSP_ENV}/bin/mkdssp"
else
  echo -e "Installing DSSP (mkdssp) directly into the BindCraft env\n"
  $pkg_manager install -n BindCraft -c conda-forge dssp -y || { echo -e "Error: Failed to install dssp"; exit 1; }
  DSSP_BIN="${CONDA_PREFIX}/bin/mkdssp"
fi
[ -x "$DSSP_BIN" ] || { echo -e "Error: mkdssp not found at $DSSP_BIN"; exit 1; }
rm -f "${install_dir}/functions/dssp"
ln -s "$DSSP_BIN" "${install_dir}/functions/dssp"
"${install_dir}/functions/dssp" --version >/dev/null 2>&1 || { echo -e "Error: dssp symlink does not run"; exit 1; }

# sc (shape complementarity, replaces PyRosetta's ShapeComplementarityFilter): pure Rust, no native
# deps -> builds for aarch64 with no changes. Requires cargo/rustc (>=1.70) on PATH.
echo -e "Building sc (sc-rs) for aarch64\n"
command -v cargo >/dev/null 2>&1 || { echo -e "Error: cargo not found; install Rust (e.g. 'apt-get install -y cargo') before running this script"; exit 1; }
SC_SRC=$(mktemp -d)
git clone --depth 1 https://github.com/cytokineking/sc-rs.git "${SC_SRC}/sc-rs" || { echo -e "Error: Failed to clone sc-rs"; exit 1; }
( cd "${SC_SRC}/sc-rs" && cargo build --release --bin sc ) || { echo -e "Error: Failed to build sc-rs"; exit 1; }
cp -f "${SC_SRC}/sc-rs/target/release/sc" "${install_dir}/functions/sc" || { echo -e "Error: Failed to install sc binary"; exit 1; }
chmod +x "${install_dir}/functions/sc"
rm -rf "${SC_SRC}"
"${install_dir}/functions/sc" 2>&1 | grep -qi "Usage" || { echo -e "Error: sc binary does not run"; exit 1; }

# FASPR (side-chain repacking, replaces PyRosetta-based repacking): plain C++, no external libs
# beyond libstdc++/libm -> builds for aarch64 with no changes. dun2010bbdep.bin (already present
# in functions/, from the upstream repo) must stay alongside the FASPR binary.
echo -e "Building FASPR for aarch64\n"
command -v g++ >/dev/null 2>&1 || { echo -e "Error: g++ not found; install build-essential before running this script"; exit 1; }
FASPR_SRC=$(mktemp -d)
git clone --depth 1 https://github.com/tommyhuangthu/FASPR.git "${FASPR_SRC}/FASPR" || { echo -e "Error: Failed to clone FASPR"; exit 1; }
( cd "${FASPR_SRC}/FASPR" && g++ -O3 --fast-math -o FASPR src/*.cpp ) || { echo -e "Error: Failed to build FASPR"; exit 1; }
cp -f "${FASPR_SRC}/FASPR/FASPR" "${install_dir}/functions/FASPR" || { echo -e "Error: Failed to install FASPR binary"; exit 1; }
chmod +x "${install_dir}/functions/FASPR"
rm -rf "${FASPR_SRC}"
[ -f "${install_dir}/functions/dun2010bbdep.bin" ] || { echo -e "Error: dun2010bbdep.bin missing from functions/ (required by FASPR)"; exit 1; }

# DAlphaBall.gcc: only needed when PyRosetta is installed (BuriedUnsatHbonds filter).
if [ "$install_pyrosetta" = true ]; then
  echo -e "Building DAlphaBall for aarch64\n"
  command -v gfortran >/dev/null 2>&1 || $pkg_manager install -c conda-forge gfortran gmp make -y || { echo -e "Error: Failed to install DAlphaBall build toolchain"; exit 1; }
  DAB_SRC=$(mktemp -d)
  git clone --depth 1 https://github.com/outpace-bio/DAlphaBall.git "${DAB_SRC}/DAlphaBall" || { echo -e "Error: Failed to clone DAlphaBall"; exit 1; }
  (
    cd "${DAB_SRC}/DAlphaBall/src" && \
    make CC=gcc FC=gfortran \
         CFLAGS="-I${CONDA_PREFIX}/include" \
         FFLAGS="-I${CONDA_PREFIX}/include" \
         LIBS="-L${CONDA_PREFIX}/lib -Wl,-rpath,${CONDA_PREFIX}/lib"
  ) || { echo -e "Error: Failed to build DAlphaBall"; exit 1; }
  cp -f "${DAB_SRC}/DAlphaBall/src/DAlphaBall.gcc" "${install_dir}/functions/DAlphaBall.gcc" || { echo -e "Error: Failed to install DAlphaBall.gcc"; exit 1; }
  chmod +x "${install_dir}/functions/DAlphaBall.gcc"
  rm -rf "${DAB_SRC}"
  "${install_dir}/functions/DAlphaBall.gcc" 2>&1 | grep -qi "arg is required" || { echo -e "Error: DAlphaBall.gcc does not run"; exit 1; }
else
  echo -e "Skipping DAlphaBall.gcc build (PyRosetta not requested)\n"
fi

# chmod remaining executables (idempotent; ensure_binaries_executable() in bindcraft.py also does this at runtime)
echo -e "Changing permissions for executables\n"
chmod +x "${install_dir}/functions/dssp" "${install_dir}/functions/sc" "${install_dir}/functions/FASPR" 2>/dev/null || true

############################################################################################################
################## AlphaFold2 weights
# Set BINDCRAFT_SKIP_PARAMS=1 to skip the ~5.3 GB weights download (e.g. in Docker builds where the
# params/ directory is mounted at runtime instead of baked into the image).
if [ "${BINDCRAFT_SKIP_PARAMS:-0}" = "1" ]; then
  echo -e "BINDCRAFT_SKIP_PARAMS=1 set — skipping AlphaFold2 weights download.\n"
  echo -e "Remember to provide AlphaFold2 weights at ${install_dir}/params/ before running.\n"
else
  echo -e "Downloading AlphaFold2 model weights \n"
  params_dir="${install_dir}/params"
  params_file="${params_dir}/alphafold_params_2022-12-06.tar"

  mkdir -p "${params_dir}" || { echo -e "Error: Failed to create weights directory"; exit 1; }
  wget -c -O "${params_file}" "https://storage.googleapis.com/alphafold/alphafold_params_2022-12-06.tar" || { echo -e "Error: Failed to download AlphaFold2 weights"; exit 1; }
  [ -s "${params_file}" ] || { echo -e "Error: Could not locate downloaded AlphaFold2 weights"; exit 1; }
  tar tf "${params_file}" >/dev/null 2>&1 || { echo -e "Error: Corrupt AlphaFold2 weights download"; exit 1; }
  tar -xvf "${params_file}" --no-same-owner -C "${params_dir}" || { echo -e "Error: Failed to extract AlphaFold2 weights"; exit 1; }
  [ -f "${params_dir}/params_model_5_ptm.npz" ] || { echo -e "Error: Could not locate extracted AlphaFold2 weights"; exit 1; }
  rm "${params_file}" || { echo -e "Warning: Failed to remove AlphaFold2 weights archive"; }
fi

# finish
conda deactivate
echo -e "BindCraft environment set up\n"

############################################################################################################
################## cleanup
echo -e "Cleaning up ${pkg_manager} temporary files to save space\n"
$pkg_manager clean -a -y
echo -e "$pkg_manager cleaned up\n"

################## finish
t=$SECONDS
echo -e "Successfully finished FreeBindCraft installation!\n"
echo -e "Activate environment using command: \"$pkg_manager activate BindCraft\""
echo -e "\n"
echo -e "Installation took $(($t / 3600)) hours, $((($t / 60) % 60)) minutes and $(($t % 60)) seconds."
