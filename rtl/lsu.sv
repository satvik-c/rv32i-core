module lsu
(
    input logic [2:0] funct3,
    input logic [31:0] addr,

    input logic [31:0] rs2_data,
    output logic [31:0] dmem_wdata,
    output logic [3:0] dmem_wstrb,

    input logic [31:0] dmem_rdata,
    output logic [31:0] result_data
);

    always_comb begin
        dmem_wdata = 32'b0;
        dmem_wstrb = 4'b0000;

        case (funct3[1:0])
            2'b00: begin
                dmem_wdata = rs2_data[7:0] << (8 * addr[1:0]);
                dmem_wstrb[addr[1:0]] = 1'b1;
            end
            2'b01: begin
                dmem_wdata = rs2_data[15:0] << (16 * addr[1]);
                dmem_wstrb[2 * addr[1] +: 2] = 2'b11;
            end
            2'b10: begin
                dmem_wdata = rs2_data;
                dmem_wstrb = 4'b1111;
            end
            default: ;
        endcase
    end

    logic [7:0] b;
    logic [15:0] h;
    
    always_comb begin
        b = dmem_rdata >> (8 * addr[1:0]);
        h = dmem_rdata >> (16 * addr[1]);
        result_data = dmem_rdata;

        case (funct3)
            3'b000: result_data = {{24{b[7]}}, b};
            3'b001: result_data = {{16{h[15]}}, h};
            3'b010: result_data = dmem_rdata;
            3'b100: result_data = {24'b0, b};
            3'b101: result_data = {16'b0, h};
            default: ;
        endcase
    end

endmodule
