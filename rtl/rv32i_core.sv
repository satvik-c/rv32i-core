module rv32i_core
    import core_pkg::*;
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
    input  logic [31:0] dmem_rsp_rdata
);

    logic reg_write;
    logic alu_src;
    logic branch;
    logic jump;
    logic jalr;
    logic illegal_instr;
    logic stall;
    logic misaligned_access;
    logic misaligned_fetch;
    alu_op_e alu_op;
    imm_src_e imm_src;
    result_src_e result_src;

    logic mem_write;
    logic mem_read;
    logic [31:0] pc;
    logic [31:0] alu_result;
    logic [31:0] write_data;
    logic [3:0] wstrb;

    assign imem_req_addr = {pc[31:2], 2'b00};
    assign dmem_req_addr = {alu_result[31:2], 2'b00};
    assign dmem_req_we = mem_write;
    assign dmem_req_wstrb = wstrb;
    assign dmem_req_wdata = write_data;
    assign mem_read = reg_write && result_src == RESULT_MEM;
    assign core_halted = illegal_instr || imem_rsp_error || dmem_rsp_error;

    controller controller_u (
        .op(imem_rsp_rdata[6:0]),
        .funct3(imem_rsp_rdata[14:12]),
        .funct7_5(imem_rsp_rdata[30]),
        .op_5(imem_rsp_rdata[5]),
        .reg_write(reg_write),
        .mem_write(mem_write),
        .alu_src(alu_src),
        .alu_op(alu_op),
        .imm_src(imm_src),
        .result_src(result_src),
        .branch(branch),
        .jump(jump),
        .jalr(jalr),
        .illegal_instr(illegal_instr)
    );

    stall_ctrl stall_ctrl_u (
        .clk(clk),
        .rst_n(rst_n),
        .mem_read(mem_read),
        .mem_write(mem_write),
        .core_halted(core_halted),
        .imem_req_ready(imem_req_ready),
        .imem_rsp_valid(imem_rsp_valid),
        .dmem_req_ready(dmem_req_ready),
        .dmem_rsp_valid(dmem_rsp_valid),
        .imem_req_valid(imem_req_valid),
        .dmem_req_valid(dmem_req_valid),
        .stall(stall)
    );

    datapath datapath_u (
        .clk(clk),
        .rst_n(rst_n),
        .reg_write(reg_write),
        .alu_src(alu_src),
        .alu_op(alu_op),
        .imm_src(imm_src),
        .result_src(result_src),
        .pc(pc),
        .instr(imem_rsp_rdata),
        .alu_result(alu_result),
        .write_data(write_data),
        .wstrb(wstrb),
        .read_data(dmem_rsp_rdata),
        .branch(branch),
        .jump(jump),
        .jalr(jalr),
        .illegal_instr(illegal_instr),
        .stall(stall),
        .misaligned_access(misaligned_access),
        .misaligned_fetch(misaligned_fetch)
    );

endmodule
