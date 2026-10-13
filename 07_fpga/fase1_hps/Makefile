# Fase 1 HPS — OSQP no host (casa) e Cortex-A9 (DE10-Standard).
# Nao e FIL. Nao usa BSP Nios. qpOASES fica no PC (build_campaign.ps1).
# gcc da placa: make
# Cross ARM: make arm   (precisa arm-linux-gnueabihf-gcc)

CC ?= gcc
ARM_CC ?= arm-linux-gnueabihf-gcc
AR ?= ar
CFLAGS ?= -O2 -std=c99 -Wall -Wextra -I. -D_POSIX_C_SOURCE=200809L -DQP_DEFAULT_OSQP
LDFLAGS ?= -lm
ifeq ($(OS),Windows_NT)
LDFLAGS += -static
OSQP_TIME := third_party/osqp/src/timing_windows.c
else
OSQP_TIME := third_party/osqp/src/timing_linux.c
endif

OSQP_INC = \
	-Ihps_config \
	-Ithird_party/osqp/include/public \
	-Ithird_party/osqp/include/private \
	-Ithird_party/osqp/algebra/builtin \
	-Ithird_party/osqp/algebra/_common \
	-Ithird_party/osqp/algebra/_common/lin_sys/qdldl \
	-Ithird_party/osqp/algebra/_common/lin_sys/qdldl/amd/include \
	-Ithird_party/qdldl/include

OSQP_SRCS = \
	third_party/osqp/src/auxil.c \
	third_party/osqp/src/error.c \
	third_party/osqp/src/osqp_api.c \
	third_party/osqp/src/polish.c \
	third_party/osqp/src/scaling.c \
	third_party/osqp/src/util.c \
	$(OSQP_TIME) \
	third_party/osqp/algebra/_common/csc_math.c \
	third_party/osqp/algebra/_common/csc_utils.c \
	third_party/osqp/algebra/_common/kkt.c \
	third_party/osqp/algebra/_common/lin_sys/qdldl/qdldl_interface.c \
	third_party/osqp/algebra/builtin/algebra_libs.c \
	third_party/osqp/algebra/builtin/vector.c \
	third_party/osqp/algebra/builtin/matrix.c \
	third_party/qdldl/src/qdldl.c \
	third_party/osqp/algebra/_common/lin_sys/qdldl/amd/src/amd_1.c \
	third_party/osqp/algebra/_common/lin_sys/qdldl/amd/src/amd_2.c \
	third_party/osqp/algebra/_common/lin_sys/qdldl/amd/src/amd_aat.c \
	third_party/osqp/algebra/_common/lin_sys/qdldl/amd/src/amd_control.c \
	third_party/osqp/algebra/_common/lin_sys/qdldl/amd/src/amd_defaults.c \
	third_party/osqp/algebra/_common/lin_sys/qdldl/amd/src/amd_info.c \
	third_party/osqp/algebra/_common/lin_sys/qdldl/amd/src/amd_order.c \
	third_party/osqp/algebra/_common/lin_sys/qdldl/amd/src/amd_post_tree.c \
	third_party/osqp/algebra/_common/lin_sys/qdldl/amd/src/amd_postorder.c \
	third_party/osqp/algebra/_common/lin_sys/qdldl/amd/src/amd_preprocess.c \
	third_party/osqp/algebra/_common/lin_sys/qdldl/amd/src/amd_valid.c \
	third_party/osqp/algebra/_common/lin_sys/qdldl/amd/src/SuiteSparse_config.c

EMS_SRCS = ems_param.c planta_bess.c controle_heuristico.c gera_cenario.c \
	qp_admm.c qp_admm_hist.c qp_metrics.c qp_eval.c qp_engine.c qp_osqp.c \
	controle_mpc_fpga.c ems_protocol.c ems_work.c ems_clock.c ems_hps_main.c

CAMP_SRCS = qp_campaign.c qp_dump_io.c qp_sha256.c qp_admm.c qp_admm_hist.c \
	qp_metrics.c qp_eval.c qp_engine.c qp_osqp.c ems_param.c ems_work.c ems_clock.c

BIN = ems_hps
ARM_BIN = ems_hps_arm
CAMP_BIN = qp_campaign
DUMP_BIN = qp_dump_run

.PHONY: all arm test clean dump_run

all: $(BIN) $(CAMP_BIN) $(DUMP_BIN)

$(BIN): $(EMS_SRCS) $(OSQP_SRCS)
	$(CC) $(CFLAGS) $(OSQP_INC) -o $(BIN) $(EMS_SRCS) $(OSQP_SRCS) $(LDFLAGS)

$(CAMP_BIN): $(CAMP_SRCS) $(OSQP_SRCS)
	$(CC) $(CFLAGS) $(OSQP_INC) -o $(CAMP_BIN) $(CAMP_SRCS) $(OSQP_SRCS) $(LDFLAGS)

$(DUMP_BIN): qp_dump_run.c qp_dump_io.c qp_admm.c qp_metrics.c ems_work.c ems_clock.c ems_param.c
	$(CC) $(CFLAGS) -o $(DUMP_BIN) qp_dump_run.c qp_dump_io.c qp_admm.c qp_metrics.c ems_work.c ems_clock.c ems_param.c $(LDFLAGS)

arm:
	$(ARM_CC) $(CFLAGS) $(OSQP_INC) -mfpu=neon -mfloat-abi=hard -o $(ARM_BIN) \
		$(EMS_SRCS) $(OSQP_SRCS) $(LDFLAGS)

test: $(BIN)
	./$(BIN) --ctrl heur --cenario carga_faixas
	./$(BIN) --ctrl mpc --qp-solver osqp --cenario carga_faixas

clean:
	rm -f $(BIN) $(BIN).exe $(ARM_BIN) $(CAMP_BIN) $(CAMP_BIN).exe \
		$(DUMP_BIN) $(DUMP_BIN).exe ems_hps_kpi.csv
