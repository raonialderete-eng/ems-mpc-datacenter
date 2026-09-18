# C golden — PC (lab gcc) e mesmas fontes do Nios
CC ?= gcc
CFLAGS ?= -O2 -std=c99 -Wall -Wextra -I.
SRCS = ems_param.c planta_bess.c controle_heuristico.c gera_cenario.c \
       qp_admm.c controle_mpc_fpga.c ems_protocol.c ems_work.c ems_golden_main.c
BIN = ems_golden

.PHONY: all test clean

all: $(BIN)

$(BIN): $(SRCS)
	$(CC) $(CFLAGS) -o $(BIN) $(SRCS) -lm

test: $(BIN)
	./$(BIN) --ctrl heur --cenario carga_faixas
	./$(BIN) --ctrl heur --cenario perda_fonte
	./$(BIN) --ctrl heur_fs --cenario perda_fonte
	./$(BIN) --ctrl mpc --cenario carga_faixas
	./$(BIN) --ctrl mpc --cenario perda_fonte

clean:
	rm -f $(BIN) ems_golden_kpi.csv
