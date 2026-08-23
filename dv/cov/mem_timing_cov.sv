module mem_timing_cov
    import rvfi_pkg::*;
(
    input logic clk,
    input logic rst_n,
    input logic rvfi_valid,
    input logic [31:0] rvfi_insn,
    
    input logic imem_rsp_valid,
    input logic [31:0] imem_rsp_latency,
    input logic imem_req_stalled,

    input logic dmem_rsp_valid,
    input logic [31:0] dmem_rsp_latency,
    input logic dmem_req_stalled
);

    logic [31:0] reg_imem_rsp_latency;
    logic reg_imem_req_stalled;
    logic [31:0] reg_dmem_rsp_latency;
    logic reg_dmem_req_stalled;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            reg_imem_rsp_latency <= 32'b0;
            reg_imem_req_stalled <= 1'b0;
            reg_dmem_rsp_latency <= 32'b0;
            reg_dmem_req_stalled <= 1'b0;
        end else begin
            if (imem_rsp_valid) begin
                reg_imem_rsp_latency <= imem_rsp_latency;
                reg_imem_req_stalled <= imem_req_stalled;
            end
            if (dmem_rsp_valid) begin
                reg_dmem_rsp_latency <= dmem_rsp_latency;
                reg_dmem_req_stalled <= dmem_req_stalled;
            end
        end
    end

    covergroup cg_mem_timing with function sample(
        logic [31:0] cur_imem_lat,
        logic cur_imem_stall,
        logic [31:0] cur_dmem_lat,
        logic cur_dmem_stall
    );

        cp_imem_lat : coverpoint cur_imem_lat {
            bins zero = { 0 };
            bins one  = { 1 };
            bins few  = { [2 : 4] };
            bins many = { [5 : $] };
        }

        cp_dmem_lat : coverpoint cur_dmem_lat iff (rvfi_insn[6:0] inside {OP_LOAD, OP_STORE}) {
            bins zero = { 0 };
            bins one  = { 1 };
            bins few  = { [2 : 4] };
            bins many = { [5 : $] };
        }

        cp_imem_stall : coverpoint cur_imem_stall {
            bins immediate = { 0 };
            bins stalled   = { 1 };
        }
        
        cp_dmem_stall : coverpoint cur_dmem_stall iff (rvfi_insn[6:0] inside {OP_LOAD, OP_STORE}) {
            bins immediate = { 0 };
            bins stalled   = { 1 };
        }

        cp_instr : coverpoint rvfi_insn[6:0] {
            bins load   = { OP_LOAD };
            bins store  = { OP_STORE };
            bins alu_r  = { OP_ALU_R };
            bins alu_i  = { OP_ALU_I };
            bins branch = { OP_BRANCH };
            bins jalr   = { OP_JALR };
            bins jal    = { OP_JAL };
            bins lui    = { OP_LUI };
            bins auipc  = { OP_AUIPC };
            bins fence  = { OP_FENCE };
            bins system = { OP_SYSTEM };
        }

        cr_imem_lat : cross cp_instr, cp_imem_lat;
        cr_dmem_lat : cross cp_instr, cp_dmem_lat;

    endgroup

    cg_mem_timing cg = new();

    always_ff @(posedge clk) begin
        if (rvfi_valid) begin
            cg.sample(
                imem_rsp_valid ? imem_rsp_latency : reg_imem_rsp_latency,
                imem_rsp_valid ? imem_req_stalled : reg_imem_req_stalled,
                dmem_rsp_valid ? dmem_rsp_latency : reg_dmem_rsp_latency,
                dmem_rsp_valid ? dmem_req_stalled : reg_dmem_req_stalled
            );
        end
    end

endmodule
