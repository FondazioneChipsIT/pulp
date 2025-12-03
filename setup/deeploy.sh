ROOT=$(cd "$(dirname "${BASH_SOURCE[0]:-${(%):-%x}}")/.." && pwd)
DEEPLOY_ROOT="$ROOT"/Deeploy

export MINIMALLOC_INSTALL_DIR=$DEEPLOY_ROOT/install/minimalloc
export PULP_SDK_HOME=$ROOT/pulp-sdk
export GVSOC_INSTALL_DIR=$ROOT/gvsoc/install
export LLVM_INSTALL_DIR=/opt/riscv/snitch-llvm-15.0.0-snitch-0.1.0
export CMAKE=/usr/bin/cmake
export PULP_OPEN_HOME=$ROOT
export XTL_INSTALL_DIR=$DEEPLOY_ROOT/install/xtl
export XSIMD_INSTALL_DIR=$DEEPLOY_ROOT/install/xsimd
export XTENSOR_INSTALL_DIR=$DEEPLOY_ROOT/install/xtensor