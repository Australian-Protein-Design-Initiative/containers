#!/bin/bash
################## BindCraft installation script — aarch64 / arm64 (e.g. NVIDIA GB10 / Grace-Blackwell, GH200)
##################
## Why a separate script? On aarch64 the upstream install_bindcraft.sh fails because:
##   * conda has no aarch64 jax/jaxlib CUDA builds  -> we install jax via pip instead.
##   * the bundled functions/dssp and functions/DAlphaBall.gcc are x86-64 binaries  -> we rebuild/replace them.
##   * PyRosetta has no pip build for aarch64        -> we install it from the RosettaCommons conda channel.
##
## Hardware note (Blackwell GB10 / sm_120 / sm_121): these GPUs require CUDA 12.8+.
## We therefore install jax 0.5.3 whose cuda12 plugin bundles CUDA 12.9 (supports sm_120, which is
## binary-compatible with the GB10's sm_121). This is the newest jax that still publishes cp310 +
## aarch64 wheels, and Python is pinned to 3.10 because that is the newest PyRosetta aarch64 build.
############################################################################################################

# Default values
pkg_manager='conda'
JAX_VERSION='0.5.3'                 # newest jax with cp310+aarch64 cuda12 wheels; bundles CUDA 12.9 (Blackwell)
PYROSETTA_VERSION='2023.11'        # newest PyRosetta aarch64 (py310) conda build
DSSP_ENV='BindCraft_dssp'          # dssp lives in its own env (its boost pin conflicts with PyRosetta's)

# Define the short and long options
OPTIONS=p:
LONGOPTIONS=pkg_manager:

# Parse the command-line options
PARSED=$(getopt --options=$OPTIONS --longoptions=$LONGOPTIONS --name "$0" -- "$@")
eval set -- "$PARSED"

while true; do
  case "$1" in
    -p|--pkg_manager) pkg_manager="$2"; shift 2 ;;
    --) shift; break ;;
    *) echo -e "Invalid option $1" >&2; exit 1 ;;
  esac
done

echo -e "Package manager: $pkg_manager"

############################################################################################################
################## initialisation
SECONDS=0

# Refuse to run on the wrong architecture
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

# Load newly created BindCraft environment
echo -e "Loading BindCraft environment\n"
source ${CONDA_BASE}/bin/activate ${CONDA_BASE}/envs/BindCraft || { echo -e "Error: Failed to activate the BindCraft environment."; exit 1; }
[ "$CONDA_DEFAULT_ENV" = "BindCraft" ] || { echo -e "Error: The BindCraft environment is not active."; exit 1; }
echo -e "BindCraft environment activated at ${CONDA_BASE}/envs/BindCraft"

# install required conda packages from conda-forge (no jax/jaxlib here -> pip provides the GPU build).
# We also pull in a compiler toolchain (gfortran/gxx) + gmp so we can build DAlphaBall for aarch64.
echo -e "Installing conda requirements (conda-forge)\n"
$pkg_manager install -c conda-forge \
  pip pandas matplotlib 'numpy<2.0.0' biopython scipy pdbfixer seaborn libgfortran5 tqdm jupyter ffmpeg fsspec py3dmol \
  chex dm-haiku 'flax<0.10.0' dm-tree joblib ml-collections immutabledict optax \
  gfortran gxx make gmp git wget \
  -y || { echo -e "Error: Failed to install conda-forge packages."; exit 1; }

# install PyRosetta separately (pinned -> fast solve) from the RosettaCommons aarch64 channel
echo -e "Installing PyRosetta ${PYROSETTA_VERSION} (aarch64)\n"
$pkg_manager install \
  -c https://west.rosettacommons.org/pyrosetta/conda/release -c conda-forge \
  "pyrosetta=${PYROSETTA_VERSION}" -y || { echo -e "Error: Failed to install PyRosetta"; exit 1; }
python -c "import pyrosetta" >/dev/null 2>&1 || { echo -e "Error: pyrosetta module not found after installation"; exit 1; }

# make sure required conda packages were installed
required_packages=(pip pandas libgfortran5 matplotlib numpy biopython scipy pdbfixer seaborn tqdm jupyter ffmpeg fsspec py3dmol chex dm-haiku dm-tree joblib ml-collections immutabledict optax gfortran make gmp pyrosetta)
missing_packages=()
for pkg in "${required_packages[@]}"; do
    conda list "$pkg" | grep -w "$pkg" >/dev/null 2>&1 || missing_packages+=("$pkg")
done
if [ ${#missing_packages[@]} -ne 0 ]; then
    echo -e "Error: The following packages are missing from the environment:"
    for pkg in "${missing_packages[@]}"; do echo -e " - $pkg"; done
    exit 1
fi

# install JAX (GPU) via pip — bundles CUDA 12.9, supports Blackwell sm_120/sm_121.
# --resume-retries makes the large NVIDIA wheels survive flaky/slow connections.
echo -e "Installing JAX ${JAX_VERSION} with CUDA 12 (pip)\n"
pip install -U "jax[cuda12]==${JAX_VERSION}" --timeout 120 --retries 20 --resume-retries 50 \
  || { echo -e "Error: Failed to install jax[cuda12]"; exit 1; }
# Verify jax imports. The GPU assertion is skipped when BINDCRAFT_SKIP_GPU_CHECK=1, because
# `docker build` has no GPU access — the GPU is still checked at runtime by bindcraft.py.
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
################## aarch64 binaries: dssp + DAlphaBall

# DSSP: install mkdssp into its OWN env. The conda dssp package pulls a newer libboost than PyRosetta
# pins, so co-installing them removes PyRosetta. A separate env avoids the conflict; mkdssp resolves
# its libraries via RPATH so a direct symlink works.
echo -e "Installing DSSP (mkdssp) in separate env '${DSSP_ENV}'\n"
$pkg_manager create --name "${DSSP_ENV}" -c conda-forge dssp -y || { echo -e "Error: Failed to create dssp environment"; exit 1; }
DSSP_BIN="${CONDA_BASE}/envs/${DSSP_ENV}/bin/mkdssp"
[ -x "$DSSP_BIN" ] || { echo -e "Error: mkdssp not found at $DSSP_BIN"; exit 1; }
rm -f "${install_dir}/functions/dssp"
ln -s "$DSSP_BIN" "${install_dir}/functions/dssp"
"${install_dir}/functions/dssp" --version >/dev/null 2>&1 || { echo -e "Error: dssp symlink does not run"; exit 1; }

# DAlphaBall: rebuild from source for aarch64 (bundled binary is x86-64).
echo -e "Building DAlphaBall for aarch64\n"
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
# Sanity-check the binary is aarch64 (only if 'file' is available — it may be absent on minimal systems).
if command -v file >/dev/null 2>&1; then
  file "${install_dir}/functions/DAlphaBall.gcc" | grep -qi "aarch64" || { echo -e "Error: DAlphaBall.gcc is not an aarch64 binary"; exit 1; }
fi
"${install_dir}/functions/DAlphaBall.gcc" 2>&1 | grep -qi "arg is required" || { echo -e "Error: DAlphaBall.gcc does not run"; exit 1; }

# chmod executables
echo -e "Changing permissions for executables\n"
chmod +x "${install_dir}/functions/DAlphaBall.gcc" || { echo -e "Error: Failed to chmod DAlphaBall.gcc"; exit 1; }

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
  # -c resumes if interrupted (the file is ~5.3 GB)
  wget -c -O "${params_file}" "https://storage.googleapis.com/alphafold/alphafold_params_2022-12-06.tar" || { echo -e "Error: Failed to download AlphaFold2 weights"; exit 1; }
  [ -s "${params_file}" ] || { echo -e "Error: Could not locate downloaded AlphaFold2 weights"; exit 1; }
  tar tf "${params_file}" >/dev/null 2>&1 || { echo -e "Error: Corrupt AlphaFold2 weights download"; exit 1; }
  tar -xvf "${params_file}" -C "${params_dir}" || { echo -e "Error: Failed to extract AlphaFold2 weights"; exit 1; }
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
echo -e "Successfully finished BindCraft installation!\n"
echo -e "Activate environment using command: \"$pkg_manager activate BindCraft\""
echo -e "\n"
echo -e "Installation took $(($t / 3600)) hours, $((($t / 60) % 60)) minutes and $(($t % 60)) seconds."
