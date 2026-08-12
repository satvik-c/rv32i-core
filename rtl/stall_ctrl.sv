module stall_ctrl
(
    input logic clk,
    input logic rst_n,
    input logic mem_read,
    input logic mem_write,
    input logic core_halted,
    input logic misaligned_access,
    input logic imem_req_ready,
    input logic imem_rsp_valid,
    input logic dmem_req_ready,
    input logic dmem_rsp_valid,
    output logic imem_req_valid,
    output logic dmem_req_valid,
    output logic stall
);

    typedef enum logic {
        IDLE,
        WAIT_RSP
    } mem_state_e;

    mem_state_e imem_state;
    mem_state_e dmem_state;

    assign imem_req_valid = rst_n && !core_halted && (imem_state == IDLE);
    assign dmem_req_valid = rst_n && !misaligned_access && !core_halted &&
                            (mem_write || mem_read) && (dmem_state == IDLE);
    assign stall = ((imem_req_valid || imem_state == WAIT_RSP) && !imem_rsp_valid) || 
                   ((dmem_req_valid || dmem_state == WAIT_RSP) && !dmem_rsp_valid);

    always_ff @(posedge clk) begin
        if (!rst_n) imem_state <= IDLE;
        else begin
            case (imem_state)
                IDLE: if (imem_req_valid && imem_req_ready && !imem_rsp_valid) imem_state <= WAIT_RSP;
                WAIT_RSP: if (imem_rsp_valid) imem_state <= IDLE;
            endcase
        end
    end

    always_ff @(posedge clk) begin
        if (!rst_n) dmem_state <= IDLE;
        else begin
            case (dmem_state)
                IDLE: if (dmem_req_valid && dmem_req_ready && !dmem_rsp_valid) dmem_state <= WAIT_RSP;
                WAIT_RSP: if (dmem_rsp_valid) dmem_state <= IDLE;
            endcase
        end
    end

endmodule
