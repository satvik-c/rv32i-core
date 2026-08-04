module reg_file
(
    input logic clk,
    input logic [4:0] a1,
    input logic [4:0] a2,
    input logic [4:0] a3,
    input logic we3,
    input logic [31:0] wd3,
    output logic [31:0] rd1,
    output logic [31:0] rd2
);

    logic [31:0] regs [32];

    assign rd1 = (a1 == 5'b0) ? 32'b0 : regs[a1];
    assign rd2 = (a2 == 5'b0) ? 32'b0 : regs[a2];

    always_ff @(posedge clk) begin
        if (we3 && a3 != 5'b0) regs[a3] <= wd3;
    end

endmodule
