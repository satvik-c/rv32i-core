module mem_model
    import rvfi_pkg::*;
(
    input  logic        clk,
    input  logic        rst_n,

    input  logic        imem_req_valid,
    output logic        imem_req_ready,
    input  logic [31:0] imem_req_addr,
    output logic        imem_rsp_valid,
    output logic        imem_rsp_error,
    output logic [31:0] imem_rsp_rdata,

    input  logic        dmem_req_valid,
    output logic        dmem_req_ready,
    input  logic [31:0] dmem_req_addr,
    input  logic        dmem_req_we,
    input  logic [3:0]  dmem_req_wstrb,
    input  logic [31:0] dmem_req_wdata,
    output logic        dmem_rsp_valid,
    output logic        dmem_rsp_error,
    output logic [31:0] dmem_rsp_rdata,

    output logic        sim_exit_valid,
    output logic [31:0] sim_exit_code
);

    logic [31:0] mem [logic [31:0]];

    initial begin
        string hex_file;
        if ($value$plusargs("HEX_FILE=%s", hex_file)) begin
            $readmemh(hex_file, mem);
        end else begin
            $error("MEM_MODEL: hex_file path not provided");
            $finish;
        end
    end

    // IMEM Read
    assign imem_req_ready = 1'b1;
    assign imem_rsp_valid = imem_req_valid;
    assign imem_rsp_error = 1'b0;
    always_comb begin
        if (!$isunknown(imem_req_addr) && mem.exists(imem_req_addr[31:2]))
            imem_rsp_rdata = mem[imem_req_addr[31:2]];
        else imem_rsp_rdata = 32'hxxxx_xxxx;
    end

    // DMEM Read
    assign dmem_req_ready = 1'b1;
    assign dmem_rsp_valid = dmem_req_valid;
    assign dmem_rsp_error = 1'b0;
    always_comb begin
        if (!$isunknown(dmem_req_addr) && mem.exists(dmem_req_addr[31:2]))
            dmem_rsp_rdata = mem[dmem_req_addr[31:2]];
        else dmem_rsp_rdata = 32'hxxxx_xxxx;
    end

    // DMEM Write
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            sim_exit_valid <= 1'b0;
            sim_exit_code <= 32'b0;
        end
        else if (dmem_req_valid && dmem_req_ready && dmem_req_we) begin
            case (dmem_req_addr)
                SIM_EXIT: begin
                    sim_exit_valid <= 1'b1;
                    sim_exit_code <= (dmem_req_wdata >> 1);
                end
                SIM_PUTC: begin
                    $write("%c", dmem_req_wdata[7:0]);
                end
                SIM_EXIT_HI: ;
                default: begin
                    if (!mem.exists(dmem_req_addr[31:2])) begin
                        mem[dmem_req_addr[31:2]] = 32'h0000_0000;
                    end
                    for (int i = 0; i < 4; i++) begin
                        if (dmem_req_wstrb[i]) begin
                            mem[dmem_req_addr[31:2]][8*i +: 8] <= dmem_req_wdata[8*i +: 8];
                        end
                    end
                end
            endcase
        end
    end

endmodule
