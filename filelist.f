// Core Package
rtl/core_pkg.sv

// Submodules
rtl/alu.sv
rtl/imm_gen.sv
rtl/reg_file.sv
rtl/main_dec.sv
rtl/alu_dec.sv
rtl/branch_logic.sv
rtl/lsu.sv
rtl/stall_ctrl.sv
rtl/fault_ctrl.sv
rtl/controller.sv
rtl/datapath.sv

// Top-Level Core Wrapper
rtl/rv32i_core.sv

// DV Package and Components
dv/rvfi_pkg.sv
dv/env/mem_model.sv
dv/env/rvfi_monitor.sv
dv/env/spike_trace_adapter.sv
dv/env/rvfi_scoreboard.sv
