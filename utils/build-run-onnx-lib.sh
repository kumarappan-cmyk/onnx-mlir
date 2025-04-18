# Build the run-onnx-lib utility
#
# When called without parameters, we build the tool for dynamically linking of 
# a model. It will need to be passed at runtime.
#
# When called with one parameter, we build the tool for the model passed
# as a parameter. 
#
# Assumptions:
# 1) script run in the onnx-mlir/build subdir. 
# 2) llvm-project is built with all its libraries (needed to run the tool)

if [ -z $ONNX_MLIR_HOME ]; then
  # The build path of onnx-mlir is not provided
  # ask git for the onnx-mlir top level dir
  ONNX_MLIR=$(git rev-parse --show-toplevel)
  if [ $(realpath $(pwd)) != $ONNX_MLIR/build ] ; then
    echo "Error: this script must be run from the build dir $ONNX_MLIR/build"
    exit 1
  fi
  ONNX_MLIR_BIN=$ONNX_MLIR/build/Debug/bin
else
  # ONNX_MLIR_HOME should be onnx-mlir/build/Debug according to RunONNXModel.py
  ONNX_MLIR_BIN=$ONNX_MLIR_HOME/bin
  ONNX_MLIR=$ONNX_MLIR_HOME/../..
fi

if [ -z $LLVM_PROJECT ] ; then
  if [ $MLIR_DIR ] ; then
    # find llvm-project in MLIR_DIR, used to configure cmake,
    LLVM_PROJECT=${MLIR_DIR%llvm-project/*}llvm-project
  else
    # or else assume llvm-project shares parent directory with ONNX-MLIR
    LLVM_PROJECT=$(dirname $ONNX_MLIR)/llvm-project
  fi
fi

if [ "$#" -eq 0 ] ; then
  echo "Compiling run-onnx-lib for dynamically linked models passed at runtime"
  RUN_BIN=$ONNX_MLIR_BIN/run-onnx-lib
else
  # Check .so exists
  if [ -e $1 ] ; then
    echo "Compiling run-onnx-lib statically linked to model $1"
  else
    echo "Error: could not find model $1"
    exit 1
  fi
  # User specified destination?
  if  [ "$#" -eq 1 ] ; then
    RUN_BIN=$ONNX_MLIR_BIN/run-onnx-lib
  elif [ "$#" -eq 2] ; then
    RUN_BIN=$2
  else
    echo "Error: pass either zero/one/two argument for dynamically/statically linked models and output"
    exit 1
  fi
  echo "Built binary will be created at $RUN_BIN"
fi

DRIVER_NAME=$ONNX_MLIR/utils/RunONNXLib.cpp
RUN_BIN_RELATIVE=${RUN_BIN#$(pwd)/}
g++ -g $DRIVER_NAME -o $RUN_BIN -std=c++17 -D LOAD_MODEL_STATICALLY=$# \
-I $LLVM_PROJECT/llvm/include -I $LLVM_PROJECT/build/include \
-I $ONNX_MLIR/include -L $LLVM_PROJECT/build/lib \
-lLLVMSupport -lLLVMDemangle -lcurses -lpthread -ldl "$@" &&
echo "Success, built $RUN_BIN_RELATIVE"

if [ "$#" -eq 1 -a $(uname -s) = Darwin ] ; then
  echo ""
  echo "TO RUN: easiest is to cd into the directory where the model was built"
  echo "(run \"otool -L $RUN_BIN_RELATIVE\" to see $(basename $1) path)"
fi
