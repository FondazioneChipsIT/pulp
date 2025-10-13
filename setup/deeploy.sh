ROOT=$(cd "$(dirname "${BASH_SOURCE[0]:-${(%):-%x}}")/.." && pwd)
DEEPLOY_ROOT="$ROOT"/Deeploy

export MINIMALLOC_INSTALL_DIR=$DEEPLOY_ROOT/install/minimalloc
export PULP_SDK_HOME=$ROOT/pulp-sdk
export GVSOC_INSTALL_DIR=$ROOT/pulp-sdk/install/workstation
export LLVM_INSTALL_DIR=/opt/llvm
export CMAKE=/usr/bin/cmake
