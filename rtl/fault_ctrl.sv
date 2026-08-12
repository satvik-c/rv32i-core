module fault_ctrl
    import core_pkg::*;
(
    input logic clk,
    input logic rst_n,
    input fault_t fault,
    output logic trap_active,
    output logic core_halted,
    output logic rvfi_trap,
    output logic rvfi_halt
);

    assign trap_active = |fault;
    assign rvfi_trap = trap_active;
    assign rvfi_halt = trap_active || core_halted;

    always_ff @(posedge clk) begin
        if (!rst_n) core_halted <= 1'b0;
        else if (trap_active) core_halted <= 1'b1;
    end

endmodule
