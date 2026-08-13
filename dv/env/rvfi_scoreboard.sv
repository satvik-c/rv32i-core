module rvfi_scoreboard
    import rvfi_pkg::*;
(
    input mailbox #(rvfi_txn) mon2scb,
    input mailbox #(rvfi_txn) spike2scb,

    input logic sim_exit_valid,
    input logic [31:0] sim_exit_code
);  

    int count, errors;

    initial begin
        logic test_done;
        rvfi_txn txn_mon, txn_spike;
        string diff;

        count = 0;
        errors = 0;
        test_done = 1'b0;

        while (!test_done) begin
            mon2scb.get(txn_mon);
            if (txn_mon.is_sim_ctrl()) begin
                #1; // wait for mem_model non-blocking
                assert (sim_exit_valid == 1'b1 && sim_exit_code == 32'b0);
                test_done = 1'b1;
            end else begin
                spike2scb.get(txn_spike);
                diff = txn_mon.compare(txn_spike);
                if (diff != "") begin
                    $error("SCOREBOARD: mismatch at retirement %0d:\n%s", count, diff);
                    errors++;
                end
            end
            if (!test_done) count++;
        end

        if (errors == 0) $display("SCOREBOARD: PASS (%0d retirements checked)", count);
        else $display("SCOREBOARD: FAIL (%0d errors)", errors);
        $finish;
    end

endmodule
