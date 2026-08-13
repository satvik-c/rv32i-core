module memory_sva
(
    input logic clk,
    input logic rst_n,

    input logic core_halted,

    input logic        imem_req_valid,
    input logic        imem_req_ready,
    input logic [31:0] imem_req_addr,
    input logic        imem_rsp_valid,

    input logic        dmem_req_valid,
    input logic        dmem_req_ready,
    input logic [31:0] dmem_req_addr,
    input logic        dmem_req_we,
    input logic [3:0]  dmem_req_wstrb,
    input logic [31:0] dmem_req_wdata,
    input logic        dmem_rsp_valid
);

    default clocking @(posedge clk); endclocking
    default disable iff (!rst_n);

    // B1
    property valid_until_ready(valid, ready);
        (valid && !ready) |=> valid;
    endproperty

    B1_IMEM: assert property (valid_until_ready(imem_req_valid, imem_req_ready));
    B1_DMEM: assert property (valid_until_ready(dmem_req_valid, dmem_req_ready));

    // B2
    property payload_stable(valid, ready, s1, s2, s3, s4);
        (valid && !ready) |=> $stable(s1) && $stable(s2) && $stable(s3) && $stable(s4);
    endproperty

    B2_IMEM: assert property (payload_stable(imem_req_valid, imem_req_ready, imem_req_addr, 1, 1, 1));
    B2_DMEM: assert property (payload_stable(dmem_req_valid, dmem_req_ready, dmem_req_addr, dmem_req_we, dmem_req_wstrb, dmem_req_wdata));

    // B3
    B3_IMEM: assert property (imem_req_valid && imem_req_ready |-> imem_req_addr[1:0] == 2'b00);
    B3_DMEM: assert property (dmem_req_valid && dmem_req_ready |-> dmem_req_addr[1:0] == 2'b00);

    // B4, B5
    int imem_req_rsp_count, dmem_req_rsp_count;
    
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            imem_req_rsp_count <= 0;
            dmem_req_rsp_count <= 0;
        end else begin
            imem_req_rsp_count <= imem_req_rsp_count + (imem_req_valid && imem_req_ready) - imem_rsp_valid;
            dmem_req_rsp_count <= dmem_req_rsp_count + (dmem_req_valid && dmem_req_ready) - dmem_rsp_valid;
        end
    end

    B4_B5_IMEM: assert property (imem_req_rsp_count inside {0, 1});
    B4_B5_DMEM: assert property (dmem_req_rsp_count inside {0, 1});

    // B6
    property reset_valid_low(valid);
        disable iff (0)
        !rst_n |-> !valid;
    endproperty

    B6_IMEM: assert property (reset_valid_low(imem_req_valid));
    B6_DMEM: assert property (reset_valid_low(dmem_req_valid));

    // B7
    property no_x_when_valid(valid, ready, s1, s2, s3, s4);
        valid |-> !$isunknown({ready, s1, s2, s3, s4});
    endproperty

    B7_IMEM: assert property (no_x_when_valid(imem_req_valid, imem_req_ready, imem_req_addr, 1, 1, 1));
    B7_DMEM: assert property (no_x_when_valid(dmem_req_valid, dmem_req_ready, dmem_req_addr, dmem_req_we, dmem_req_wstrb, dmem_req_wdata));

    // B8
    B8: assert property (dmem_req_valid && dmem_req_ready && dmem_req_we |-> dmem_req_wstrb != 4'b0000);

    // B9
    property no_req_when_halted(valid);
        core_halted |-> !valid;
    endproperty

    B9_IMEM: assert property (no_req_when_halted(imem_req_valid));
    B9_DMEM: assert property (no_req_when_halted(dmem_req_valid));

endmodule
