module rv32i_core
    import core_pkg::*;
#(
    parameter logic [31:0] RESET_VECTOR = 32'h8000_0000
)
(
    input logic clk,
    input logic rst_n,

    output logic core_halted,

    output logic        imem_req_valid,
    input  logic        imem_req_ready,
    output logic [31:0] imem_req_addr,
    input  logic        imem_rsp_valid,
    input  logic        imem_rsp_error,
    input  logic [31:0] imem_rsp_rdata,

    output logic        dmem_req_valid,
    input  logic        dmem_req_ready,
    output logic [31:0] dmem_req_addr,
    output logic        dmem_req_we,
    output logic [3:0]  dmem_req_wstrb,
    output logic [31:0] dmem_req_wdata,
    input  logic        dmem_rsp_valid,
    input  logic        dmem_rsp_error,
    input  logic [31:0] dmem_rsp_rdata,

    // RVFI Ports
    output logic        rvfi_valid,
    output logic [63:0] rvfi_order,
    output logic [31:0] rvfi_insn,
    output logic        rvfi_trap,
    output logic        rvfi_halt,
    output logic        rvfi_intr,
    output logic [1:0]  rvfi_mode,
    output logic [1:0]  rvfi_ixl,
    output logic [4:0]  rvfi_rs1_addr,
    output logic [4:0]  rvfi_rs2_addr,
    output logic [31:0] rvfi_rs1_rdata,
    output logic [31:0] rvfi_rs2_rdata,
    output logic [4:0]  rvfi_rd_addr,
    output logic [31:0] rvfi_rd_wdata,
    output logic [31:0] rvfi_pc_rdata,
    output logic [31:0] rvfi_pc_wdata,
    output logic [31:0] rvfi_mem_addr,
    output logic [3:0]  rvfi_mem_rmask,
    output logic [3:0]  rvfi_mem_wmask,
    output logic [31:0] rvfi_mem_rdata,
    output logic [31:0] rvfi_mem_wdata
);

    ctrl_t ctrl;
    fault_t fault;
    logic stall;
    logic trap_active;
    logic pc_en;
    logic reg_file_we;

    logic mem_read;
    logic decode_valid;
    logic instr_valid;
    logic [31:0] pc;
    logic [31:0] alu_result;
    logic [31:0] write_data;
    logic [3:0] wstrb;

    logic [31:0] instr_reg;
    logic [31:0] instr_word;

    always_ff @(posedge clk) begin
        if (!rst_n) instr_reg <= 32'b0;
        else if (imem_rsp_valid && !imem_rsp_error) instr_reg <= imem_rsp_rdata;
    end

    assign instr_word = (imem_rsp_valid && !imem_rsp_error) ? imem_rsp_rdata :
                        (instr_valid)                       ? instr_reg      : 32'b0;

    assign fault.imem_error = imem_rsp_valid && imem_rsp_error;
    assign fault.dmem_error = dmem_rsp_valid && dmem_rsp_error;

    assign pc_en = !trap_active && !core_halted && !stall;
    assign reg_file_we = ctrl.reg_write && !trap_active && !core_halted && !stall;

    assign imem_req_addr = {pc[31:2], 2'b00};
    assign dmem_req_addr = {alu_result[31:2], 2'b00};
    assign dmem_req_we = ctrl.mem_write;
    assign dmem_req_wstrb = wstrb;
    assign dmem_req_wdata = write_data;
    assign mem_read = ctrl.result_src == RESULT_MEM;

    // RVFI Port Assignments
    assign rvfi_valid = rst_n && !core_halted && !stall;
    logic [63:0] retired_count;
    logic [63:0] last_order;
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            retired_count <= 64'b0;
            last_order <= 64'b0;
        end else if (rvfi_valid) begin
            retired_count <= retired_count + 64'b1;
            last_order <= retired_count;
        end
    end
    assign rvfi_order = rvfi_valid ? retired_count : last_order;
    assign rvfi_insn = instr_word;
    // rvfi_trap and rvfi_halt taken care of by fault_ctrl
    assign rvfi_intr = 1'b0;
    assign rvfi_mode = 2'd3;
    assign rvfi_ixl = 2'd1;

    logic rs1_read, rs2_read, rd_write;
    logic [31:0] src_a_rvfi, rd2_data_rvfi, result_rvfi;
    assign rs1_read = !(ctrl.imm_src inside {IMM_U, IMM_J, IMM_NONE});
    assign rs2_read = !(ctrl.imm_src inside {IMM_I, IMM_U, IMM_J, IMM_NONE});
    assign rd_write = !(ctrl.imm_src inside {IMM_S, IMM_B, IMM_NONE});
    assign rvfi_rs1_addr = (rs1_read) ? instr_word[19:15] : 5'b0;
    assign rvfi_rs2_addr = (rs2_read) ? instr_word[24:20] : 5'b0;
    assign rvfi_rs1_rdata = (rvfi_rs1_addr != 5'b0) ? src_a_rvfi : 32'b0;
    assign rvfi_rs2_rdata = (rvfi_rs2_addr != 5'b0) ? rd2_data_rvfi : 32'b0;
    assign rvfi_rd_addr = (rd_write && !rvfi_trap) ? instr_word[11:7] : 5'b0;
    assign rvfi_rd_wdata = (rvfi_rd_addr != 5'b0) ? result_rvfi : 32'b0;

    logic [31:0] pc_next_rvfi;
    assign rvfi_pc_rdata = pc;
    assign rvfi_pc_wdata = (rvfi_trap) ? pc : pc_next_rvfi;
    assign rvfi_mem_addr = ((ctrl.mem_write || mem_read) && !rvfi_trap) ? dmem_req_addr : 32'b0;
    assign rvfi_mem_rmask = (mem_read && !rvfi_trap) ? dmem_req_wstrb : 4'b0;
    assign rvfi_mem_wmask = (ctrl.mem_write && !rvfi_trap) ? dmem_req_wstrb : 4'b0;
    assign rvfi_mem_rdata = (mem_read && !rvfi_trap) ? dmem_rsp_rdata : 32'b0;
    assign rvfi_mem_wdata = (ctrl.mem_write && !rvfi_trap) ? dmem_req_wdata : 32'b0;
    // End RVFI Port Assignments

    controller controller_u (
        .op(instr_word[6:0]),
        .funct3(instr_word[14:12]),
        .funct7_5(instr_word[30]),
        .funct7_0(instr_word[25]),
        .op_5(instr_word[5]),
        .ctrl(ctrl),
        .illegal_instr(fault.illegal_instr)
    );

    stall_ctrl stall_ctrl_u (
        .clk(clk),
        .rst_n(rst_n),
        .mem_read(mem_read),
        .mem_write(ctrl.mem_write),
        .core_halted(core_halted),
        .misaligned_access(fault.misaligned_access),
        .imem_req_ready(imem_req_ready),
        .imem_rsp_valid(imem_rsp_valid),
        .dmem_req_ready(dmem_req_ready),
        .dmem_rsp_valid(dmem_rsp_valid),
        .imem_req_valid(imem_req_valid),
        .dmem_req_valid(dmem_req_valid),
        .stall(stall),
        .decode_valid(decode_valid),
        .instr_valid(instr_valid)
    );

    fault_ctrl fault_ctrl_u (
        .clk(clk),
        .rst_n(rst_n),
        .fault(fault),
        .decode_valid(decode_valid),
        .trap_active(trap_active),
        .core_halted(core_halted),
        .rvfi_trap(rvfi_trap),
        .rvfi_halt(rvfi_halt)
    );

    datapath #(
        .RESET_VECTOR(RESET_VECTOR)
    ) datapath_u (
        .clk(clk),
        .rst_n(rst_n),
        .ctrl(ctrl),
        .mem_read(mem_read),
        .pc_en(pc_en),
        .reg_file_we(reg_file_we),
        .misaligned_access(fault.misaligned_access),
        .misaligned_fetch(fault.misaligned_fetch),
        .pc(pc),
        .instr(instr_word),
        .alu_result(alu_result),
        .write_data(write_data),
        .wstrb(wstrb),
        .read_data(dmem_rsp_rdata),
        .src_a_rvfi(src_a_rvfi),
        .rd2_data_rvfi(rd2_data_rvfi),
        .result_rvfi(result_rvfi),
        .pc_next_rvfi(pc_next_rvfi)
    );

endmodule
