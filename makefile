CURDIR      := $(shell pwd)
WORK_DIR    := $(CURDIR)/work/top
RTL_DIR     := $(CURDIR)/src
TB_DIR      := $(CURDIR)/tb

# --- Исходные файлы -----------------------------------------------------------

RTL_FILES := \
	$(RTL_DIR)/dual_port_mem.sv \
	$(RTL_DIR)/frame_pipeline_top.sv \

TB_FILES := \
	$(TB_DIR)/tb_pipeline.sv

ALL_SV_FILES := $(RTL_FILES) $(TB_FILES)

# --- Параметры симуляции ------------------------------------------------------

TOP_MODULE   := tb_pipeline
SNAPSHOT     := tb_pipeline_opt
SEED         := $(shell echo $$RANDOM)
MODE         := -batch

COMPILE_LOG  := $(WORK_DIR)/compile.log
OPT_LOG      := $(WORK_DIR)/opt.log
RUN_LOG      := $(WORK_DIR)/run.log
HISTORY_FILE := $(WORK_DIR)/.history

# --- Файлы-маркеры (для отслеживания состояния сборки) ------------------------

COMPILE_STAMP := $(WORK_DIR)/.compile.stamp
OPT_STAMP     := $(WORK_DIR)/.opt.stamp

# ==============================================================================
# Цели
# ==============================================================================

.PHONY: all compile elaborate run gui clean help

all: run

xcell:
	@echo "module load cadence/XCELIUMMAIN/24.03.001 "

compile: $(COMPILE_STAMP)

$(COMPILE_STAMP): $(ALL_SV_FILES)
	@echo ">>> [compile] Компиляция исходных файлов..."
	@mkdir -p $(WORK_DIR)
	cd $(WORK_DIR) && xrun -compile -64bit $(ALL_SV_FILES) \
		-xmlibdirpath $(WORK_DIR) -l $(COMPILE_LOG)
	@touch $@

elaborate: $(OPT_STAMP)

$(OPT_STAMP): $(COMPILE_STAMP)
	@echo ">>> [elaborate] Элаборация топ-модуля $(TOP_MODULE)..."
	cd $(WORK_DIR) && xrun -elaborate -elabonly -64bit -top $(TOP_MODULE) \
		-snapshot $(SNAPSHOT) \
		-xmlibdirpath $(WORK_DIR) -access +rwc -l $(OPT_LOG)
	@touch $@

run: $(OPT_STAMP)
	@echo ">>> [run] Запуск симуляции (seed=$(SEED), mode=$(MODE))..."
	cd $(WORK_DIR) && xrun -r $(SNAPSHOT) -64bit -xmlibdirpath $(WORK_DIR) $(MODE) \
		-seed $(SEED) -l $(RUN_LOG) \
		$(INCDIR_OPT) \
		-input @"run"

# GUI-режим
gui: MODE = -gui
gui: run

clean:
	@echo ">>> [clean] Удаление артефактов симулятора и логов..."
	rm -rf $(WORK_DIR)
	rm -f $(CURDIR)/*.log $(CURDIR)/.history

help:
	@echo "Доступные цели:"
	@echo "  make            - компиляция, элаборация и запуск симуляции (batch)"
	@echo "  make xcell      - активация кселиума"
	@echo "  make compile    - только компиляция"
	@echo "  make elaborate  - только элаборация"
	@echo "  make run        - запуск симуляции в консольном режиме"
	@echo "  make gui        - запуск симуляции в графическом режиме"
	@echo "  make clean      - удалить артефакты и логи"
	@echo ""
	@echo "Переменные:"
	@echo "  MODE=-gui|-batch  - режим симуляции"
	@echo "  SEED=<число>      - зерно генератора случайных чисел"