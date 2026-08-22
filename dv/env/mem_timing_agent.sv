module mem_timing_agent
#(
    parameter int PAYLOAD_W
)(
    input logic clk,
    input logic rst_n,
    input logic randomize_active,

    // Core-facing
    input logic req_valid,
    input logic [PAYLOAD_W-1:0] req_payload,
    output logic req_ready,
    output logic rsp_valid,
    output logic [31:0] rsp_rdata,
    output logic rsp_error,

    // mem_model-facing
    output logic back_req_valid,
    output logic [PAYLOAD_W-1:0] back_req_payload,
    input logic [31:0] back_rsp_rdata,
    input logic back_rsp_error,

    // Coverage indicators
    output logic [31:0] rsp_latency,
    output logic req_stalled
);

    int nxt_delay;
    logic delayed_valid = 0;
    logic [PAYLOAD_W-1:0] delayed_payload;
    logic [31:0] delayed_latency;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            nxt_delay <= 0;
            req_ready <= 1;
        end else if (randomize_active) begin
            nxt_delay <= ($urandom_range(0, 6));
            req_ready <= ($urandom_range(0, 99) >= 70);
        end else begin
            nxt_delay <= 0;
            req_ready <= 1;
        end
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            req_stalled <= 0;
        end else if (req_valid && !req_ready) begin
            req_stalled <= 1;
        end else if (rsp_valid) begin
            req_stalled <= 0;
        end
    end

    always @(posedge clk) begin
        if (req_valid && req_ready && (nxt_delay != 0)) begin
            automatic logic [PAYLOAD_W-1:0] p = req_payload;
            automatic int d = nxt_delay - 1;
            automatic int lat = nxt_delay;

            fork
                begin
                    repeat (d) @(posedge clk);
                    delayed_valid <= 1;
                    delayed_payload <= p;
                    delayed_latency <= lat;
                    @(posedge clk);
                    delayed_valid <= 0;
                end
            join_none
        end
    end

    logic is_zero_wait;
    assign is_zero_wait = (req_valid && req_ready && (nxt_delay == 0));

    assign back_req_valid = is_zero_wait ? 1'b1 : delayed_valid;
    assign back_req_payload = is_zero_wait ? req_payload : delayed_payload;

    assign rsp_valid = back_req_valid;
    assign rsp_rdata = back_rsp_rdata;
    assign rsp_error = back_rsp_error;
    assign rsp_latency = is_zero_wait ? 0 : delayed_latency;

endmodule
