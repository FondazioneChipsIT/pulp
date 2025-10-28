
SHELL=bash

PKG_DIR ?= $(PWD)/pulp-runtime

export VSIM_PATH=$(PWD)/sim
export PULP_PATH=$(PWD)

export MSIM_LIBS_PATH=$(VSIM_PATH)/modelsim_libs

export IPS_PATH=$(PULP_PATH)/fe/ips
export RTL_PATH=$(PULP_PATH)/fe/rtl
export TB_PATH=$(PULP_PATH)/rtl/tb

ROOT_DIR = $(strip $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST)))))
BENDER_GIT_DIR=$(PULP_PATH)/.bender/git/checkouts

define declareInstallFile

$(VSIM_PATH)/$(1): sim/$(1)
	install -v -D sim/$(1) $$@

INSTALL_HEADERS += $(VSIM_PATH)/$(1)

endef

INSTALL_FILES += tcl_files/config/vsim_ips.tcl
INSTALL_FILES += modelsim.ini
INSTALL_FILES += $(shell cd sim && find boot -type f)
INSTALL_FILES += $(shell cd sim && find tcl_files -type f)
INSTALL_FILES += $(shell cd sim && find waves -type f)

$(foreach file, $(INSTALL_FILES), $(eval $(call declareInstallFile,$(file))))

BRANCH ?= master

VLOG_ARGS += -suppress 2583 -suppress 13314 \"+incdir+\$$ROOT/rtl/includes\"
BENDER_SIM_BUILD_DIR = sim
BENDER_FPGA_SCRIPTS_DIR = fpga/pulp/tcl/generated

CompileFlags := +acc -permissive -suppress 2583 -suppress 13314 -suppress vlog-1952

.PHONY: checkout
ifndef IPAPPROX
Bender.lock: bender
	./bender checkout
	touch Bender.lock

checkout: bender Bender.lock
else
checkout:
	./update-ips
endif
	$(MAKE) scripts

# generic clean and build targets for the platform
.PHONY: clean
clean:
	$(MAKE) -C sim IPAPPROX=$(IPAPPROX) clean


.PHONY: scripts
## Generate scripts for all tools
ifndef IPAPPROX
scripts: scripts-bender-vsim scripts-bender-fpga

include bender-common.mk
include bender-synth.mk

scripts-bender-vsim-mchan: | Bender.lock
	echo 'set ROOT [file normalize [file dirname [info script]]/..]' > $(BENDER_SIM_BUILD_DIR)/compile.tcl
	./bender script vsim \
		--vlog-arg="$(VLOG_ARGS)" --vcom-arg="" \
		-t rtl -t test -t pulp -t mchan $(common_defs) $(common_targs) \
		| grep -v "set ROOT" >> $(BENDER_SIM_BUILD_DIR)/compile.tcl \

scripts-bender-vsim: | Bender.lock
	echo 'set ROOT [file normalize [file dirname [info script]]/..]' > $(BENDER_SIM_BUILD_DIR)/compile.tcl
	./bender script vsim \
		--vlog-arg="$(VLOG_ARGS)" --vcom-arg="" \
		-t rtl -t test -t pulp -t idma $(common_defs) $(common_targs) \
		| grep -v "set ROOT" >> $(BENDER_SIM_BUILD_DIR)/compile.tcl \

scripts-bender-fpga: | Bender.lock
	mkdir -p fpga/pulp/tcl/generated
	./bender script vivado -t fpga -t xilinx > $(BENDER_FPGA_SCRIPTS_DIR)/compile.tcl

$(BENDER_SIM_BUILD_DIR)/compile.tcl: Bender.lock
	echo 'set ROOT [file normalize [file dirname [info script]]/..]' > $(BENDER_SIM_BUILD_DIR)/compile.tcl
	./bender script vsim \
		--vlog-arg="$(VLOG_ARGS)" --vcom-arg="" \
		-t rtl -t test \
		| grep -v "set ROOT" >> $(BENDER_SIM_BUILD_DIR)/compile.tcl

scripts-bender-vsim-vips: | Bender.lock
	echo 'set ROOT [file normalize [file dirname [info script]]/..]' > $(BENDER_SIM_BUILD_DIR)/compile.tcl
	./bender script vsim \
		--vlog-arg="$(VLOG_ARGS)" --vcom-arg="" \
		-t rtl -t test -t rt_dpi -t i2c_vip -t flash_vip -t i2s_vip -t hyper_vip -t use_vips \
		| grep -v "set ROOT" >> $(BENDER_SIM_BUILD_DIR)/compile.tcl

scripts-bender-vsim-psram: | Bender.lock
	echo 'set ROOT [file normalize [file dirname [info script]]/..]' > $(BENDER_SIM_BUILD_DIR)/compile.tcl
	./bender script vsim \
		--vlog-arg="$(VLOG_ARGS)" --vcom-arg="" \
		-t rtl -t test -t psram_vip \
		| grep -v "set ROOT" >> $(BENDER_SIM_BUILD_DIR)/compile.tcl
	sed -i 's/psram_fake.v/*.vp_modelsim/g' $(BENDER_SIM_BUILD_DIR)/compile.tcl # Workaround for unsupported file type in bender

$(BENDER_SIM_BUILD_DIR)/compile_lint.tcl:
	echo 'set ROOT $(ROOT_DIR)' > $(BENDER_SIM_BUILD_DIR)/compile_lint.tcl
	./bender script vsim --vlog-arg="$(VLOG_ARGS_LINT)" $(common_defs) $(common_targs) $(synth_targs) $(synth_defs) | grep -v "set ROOT" >> $@
	echo >> $(BENDER_SIM_BUILD_DIR)/compile_lint.tcl

else
scripts:
	./generate-scripts
endif

scripts-vips:
ifndef IPAPPROX
	$(MAKE) scripts-bender-vsim-vips
else
	./generate-scripts --rt-dpi --i2c-vip --flash-vip --i2s-vip --hyper-vip --use-vip --verbose
endif

scripts-psram:
ifndef IPAPPROX
	$(MAKE) scripts-bender-vsim-psram
else
	./generate-scripts --psram-vip
endif

.PHONY: build
## Build the RTL model for vsim

generate_idma_rtl:
	$(MAKE) -C $(shell find $(BENDER_GIT_DIR) -type d -name 'idma*' | head -n 1) idma_hw_all

ifndef IPAPPROX
build: $(BENDER_SIM_BUILD_DIR)/compile.tcl generate_idma_rtl
	@test -f Bender.lock || { echo "ERROR: Bender.lock file does not exist. Did you run make checkout in bender mode?"; exit 1; }
	@test -f $(BENDER_SIM_BUILD_DIR)/compile.tcl || { echo "ERROR: sim/compile.tcl file does not exist. Did you run make scripts in bender mode?"; exit 1; }
	$(MAKE) -C sim all
else
build:
	@[ "$$(ls -A ips/)" ] || { echo "ERROR: ips/ is an empty directory. Did you run ./update-ips?"; exit 1; }
	$(MAKE) -C sim IPAPPROX=$(IPAPPROX) all
endif

## Build the RTL model for QuestaONE
build_qone: $(BENDER_SIM_BUILD_DIR)/compile.tcl
	@test -f Bender.lock || { echo "ERROR: Bender.lock file does not exist. Did you run make checkout in bender mode?"; exit 1; }
	@test -f $(BENDER_SIM_BUILD_DIR)/compile.tcl || { echo "ERROR: sim/compile.tcl file does not exist. Did you run make scripts in bender mode?"; exit 1; }
	$(MAKE) -C sim all_qone


# sdk specific targets
install: $(INSTALL_HEADERS)

vopt:
	export VOPT_FLOW=1 && cd $(VSIM_PATH) && vsim -64 -c -do "source tcl_files/config/vsim.tcl; quit"

import_bootcode:
	cd sim/boot && objcopy --srec-len 1 --output-target=srec ${PULP_SDK_HOME}/install/bin/boot-pulpissimo boot-pulpissimo.s19
	cd sim/boot && s19toboot.py boot-pulpissimo.s19 pulpissimo

# JENKIN CI
# continuous integration on jenkins
all: checkout build install vopt sdk

pulp_sdk:
	git clone https://github.com/FondazioneChipsIT/pulp-sdk.git; \
	cd pulp-sdk; \
	git checkout 2d990cd75214f88ac5a76229ebfa4fe77c1c103a; \

gvsoc:
	git clone https://github.com/FondazioneChipsIT/gvsoc.git; \
	cd gvsoc; \
	git checkout 0470a230652d0ae6f6428c406471ff5da0dbddfb; \
	git submodule update --init --recursive;

deeploy:
	git clone https://github.com/FondazioneChipsIT/Deeploy.git; \
	cd Deeploy; \
	git checkout b0e722a701c761defd0b87d60f4da536ab1887d2; \
	git submodule update --init --recursive; \
	pip install -e . --extra-index-url=https://pypi.ngc.nvidia.com; \
	make minimalloc xtensor; \

sdk:
	if [ ! -e pulp-builder ]; then \
	  git clone --recurse https://github.com/pulp-platform/pulp-builder.git; \
	fi; \
	cd pulp-builder; \
	git checkout 83953d5ca4c545f4186bf3683d509566c3067012; \
	git checkout --recurse-submodules; \
	. configs/pulp.sh; \
	. configs/rtl.sh; \
	./scripts/clean; \
	./scripts/update-runtime; \
	./scripts/build-runtime; \
	./scripts/update-runner; \
	./scripts/build-runner;

test-checkout:
	./update-tests

test:
	cd pulp-builder; \
	. sdk-setup.sh; \
	. configs/pulp.sh; \
	. configs/rtl.sh; \
	cd ..; \
	cd tests && plptest --threads 16 --stdout

# GITLAB CI
# continuous integration on gitlab
sdk-gitlab:
	sdk-releases/get-sdk-2019.11.03-CentOS_7.py; \

## Clone pulp-runtime as SW stack
pulp-runtime:
	git clone https://github.com/FondazioneChipsIT/pulp-runtime.git $@
	cd $@; git checkout ab958e06b37bc05b981dabca9680f72660b8dee1; cd ..

## Clone regression tests for bare-metal verification
regression-tests:
	git clone https://github.com/FondazioneChipsIT/regression_tests.git $@
	cd $@; git checkout 6fac940e924c7de83b37d7be14bfd9febbf04678; cd ..

# the gitlab runner needs a special configuration to be able to access the
# dependent git repositories
test-checkout-gitlab:
	./update-regression-tests



# gitlab and local test runs
test-fast-regressions:
	mkdir -p regression_tests/riscv_tests_soc
	cp -r regression_tests/riscv_tests/* regression_tests/riscv_tests_soc
	source setup/vsim.sh; \
	source pulp-runtime/configs/pulp.sh; \
	cd regression_tests && ../pulp-runtime/scripts/bwruntests.py --proc-verbose -v --report-junit -t 2000 --yaml -o simplified-runtime.xml simple-regression-tests.yaml

test-local-regressions: 
	mkdir -p regression_tests/riscv_tests_soc
	cp -r regression_tests/riscv_tests/* regression_tests/riscv_tests_soc
	source setup/vsim.sh; \
	source pulp-runtime/configs/pulp.sh; \
	cd regression_tests && ../pulp-runtime/scripts/bwruntests.py --proc-verbose -v --report-junit -t 1800 --yaml -o simplified-runtime.xml regression-tests.yaml

git-ci-ml-regs:
	source setup/vsim.sh; \
	source pulp-runtime/configs/pulp.sh; \
	touch regression_tests/simplified-ml-runtime.xml; \
	cd regression_tests && ../pulp-runtime/scripts/bwruntests.py --proc-verbose -v --report-junit -t 7200 --yaml -o simplified-ml-runtime.xml ml-tests.yaml

git-ci-riscv-regs:
	source setup/vsim.sh; \
	source pulp-runtime/configs/pulp.sh; \
	touch regression_tests/simplified-riscv-runtime.xml; \
	cd regression_tests && ../pulp-runtime/scripts/bwruntests.py --proc-verbose -v --report-junit -t 7200 --yaml -o simplified-riscv-runtime.xml riscv-tests.yaml

git-ci-s-bare-regs:
	source setup/vsim.sh; \
	source pulp-runtime/configs/pulp.sh; \
	touch regression_tests/simplified-sbare-runtime.xml; \
	cd regression_tests && ../pulp-runtime/scripts/bwruntests.py --proc-verbose -v --report-junit -t 7200 --yaml -o simplified-sbare-runtime.xml sequential-bare-tests.yaml

git-ci-p-bare-regs:
	source setup/vsim.sh; \
	source pulp-runtime/configs/pulp.sh; \
	touch regression_tests/simplified-pbare-runtime.xml; \
	cd regression_tests && ../pulp-runtime/scripts/bwruntests.py --proc-verbose -v --report-junit -t 7200 --yaml -o simplified-pbare-runtime.xml parallel-bare-tests.yaml

git-ci-periphs-regs:
	source setup/vsim.sh; \
	source pulp-runtime/configs/pulp.sh; \
	touch regression_tests/simplified-periph-runtime.xml; \
	cd regression_tests && ../pulp-runtime/scripts/bwruntests.py --proc-verbose -v --report-junit -t 7200 --yaml -o simplified-periph-runtime.xml periph-tests.yaml

git-ci-psram:
	source setup/vsim.sh; \
	source pulp-runtime/configs/pulp.sh; \
	touch regression_tests/simplified-psram-runtime.xml; \
	cd regression_tests && ../pulp-runtime/scripts/bwruntests.py --proc-verbose -v --report-junit -t 7200 --yaml -o simplified-psram-runtime.xml psram-test.yaml

git-boot:
	source setup/vsim.sh; \
	source pulp-runtime/configs/pulp.sh; \
	touch regression_tests/boot-runtime.xml; \
	cd regression_tests && ../pulp-runtime/scripts/bwruntests.py --proc-verbose -v --report-junit -t 7200 --yaml -o boot-runtime.xml hello-test.yaml

test-local-runtime: 
	source setup/vsim.sh; \
	source pulp-runtime/configs/pulp.sh; \
	cd tests && ../pulp-runtime/scripts/bwruntests.py --proc-verbose -v --report-junit -t 600 --yaml -o simplified-runtime.xml runtime-tests.yaml

bender:
ifeq (,$(wildcard ./bender))
	curl --proto '=https' --tlsv1.2 -sSf https://pulp-platform.github.io/bender/init \
		| bash -s -- 0.25.2
	touch bender
endif

.PHONY: bender-rm
bender-rm:
	rm -f bender

compile_lint:
	$(MAKE) -C sim compile_lint

lint:
	$(MAKE) -C sim lint

cdc:
	$(MAKE) -C sim cdc
