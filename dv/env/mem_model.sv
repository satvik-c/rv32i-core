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

    // Internal IMEM Store Nets
    logic        back_imem_req_valid;
    logic [31:0] back_imem_req_payload;
    logic [31:0] back_imem_rsp_rdata;

    // Internal DMEM Store Nets
    logic        back_dmem_req_valid;
    logic [31:0] back_dmem_req_addr;
    logic        back_dmem_req_we;
    logic [3:0]  back_dmem_req_wstrb;
    logic [31:0] back_dmem_req_wdata;
    logic [31:0] back_dmem_rsp_rdata;
    logic randomize_active;

    task automatic load_program(string hex_file, bit randomize);
        mem.delete();
        $readmemh(hex_file, mem);
        randomize_active = randomize;
    endtask

    // IMEM Read
    mem_timing_agent #(
        .PAYLOAD_W(32)
    ) imem_timing_agent (
        .clk(clk),
        .rst_n(rst_n),
        .randomize_active(randomize_active),
        .req_valid(imem_req_valid),
        .req_payload(imem_req_addr),
        .req_ready(imem_req_ready),
        .rsp_valid(imem_rsp_valid),
        .rsp_rdata(imem_rsp_rdata),
        .rsp_error(imem_rsp_error),
        .back_req_valid(back_imem_req_valid),
        .back_req_payload(back_imem_req_payload),
        .back_rsp_rdata(back_imem_rsp_rdata),
        .back_rsp_error(back_imem_req_valid && back_imem_req_payload == ACCESS_FAULT_ADDR)
    );
    
    always_comb begin
        if (!$isunknown(back_imem_req_payload) && mem.exists(back_imem_req_payload[31:2]))
            back_imem_rsp_rdata = mem[back_imem_req_payload[31:2]];
        else back_imem_rsp_rdata = 32'hxxxx_xxxx;
    end

    // DMEM Read
    mem_timing_agent #(
        .PAYLOAD_W(69)
    ) dmem_timing_agent (
        .clk(clk),
        .rst_n(rst_n),
        .randomize_active(randomize_active),
        .req_valid(dmem_req_valid),
        .req_payload({dmem_req_addr, dmem_req_we, dmem_req_wstrb, dmem_req_wdata}),
        .req_ready(dmem_req_ready),
        .rsp_valid(dmem_rsp_valid),
        .rsp_rdata(dmem_rsp_rdata),
        .rsp_error(dmem_rsp_error),
        .back_req_valid(back_dmem_req_valid),
        .back_req_payload({back_dmem_req_addr, back_dmem_req_we, back_dmem_req_wstrb, back_dmem_req_wdata}),
        .back_rsp_rdata(back_dmem_rsp_rdata),
        .back_rsp_error(back_dmem_req_valid && back_dmem_req_addr == ACCESS_FAULT_ADDR)
    );
    
    always_comb begin
        if (!$isunknown(back_dmem_req_addr) && mem.exists(back_dmem_req_addr[31:2]))
            back_dmem_rsp_rdata = mem[back_dmem_req_addr[31:2]];
        else back_dmem_rsp_rdata = 32'hxxxx_xxxx;
    end

    // DMEM Write
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            sim_exit_valid <= 1'b0;
            sim_exit_code <= 32'b0;
        end
        else if (back_dmem_req_valid && back_dmem_req_we) begin
            case (back_dmem_req_addr)
                SIM_EXIT: begin
                    sim_exit_valid <= 1'b1;
                    sim_exit_code <= (back_dmem_req_wdata >> 1);
                end
                SIM_PUTC: begin
                    $write("%c", back_dmem_req_wdata[7:0]);
                end
                SIM_EXIT_HI: ;
                default: begin
                    if (!mem.exists(back_dmem_req_addr[31:2])) begin
                        mem[back_dmem_req_addr[31:2]] = 32'h0000_0000;
                    end
                    for (int i = 0; i < 4; i++) begin
                        if (back_dmem_req_wstrb[i]) begin
                            mem[back_dmem_req_addr[31:2]][8*i +: 8] <= back_dmem_req_wdata[8*i +: 8];
                        end
                    end
                end
            endcase
        end
    end

endmodule
