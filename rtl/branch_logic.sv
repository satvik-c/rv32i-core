module branch_logic
(
    input logic [2:0] funct3,
    input logic [31:0] src_a,
    input logic [31:0] src_b,
    output logic take_branch
);

    always_comb begin
        case (funct3)
            3'b000: take_branch = (src_a == src_b);
            3'b001: take_branch = (src_a != src_b);
            3'b100: take_branch = ($signed(src_a) < $signed(src_b));
            3'b101: take_branch = ($signed(src_a) >= $signed(src_b));
            3'b110: take_branch = (src_a < src_b);
            3'b111: take_branch = (src_a >= src_b);
            default: take_branch = 0;
        endcase
    end

endmodule
