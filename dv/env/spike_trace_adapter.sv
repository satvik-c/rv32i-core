module spike_trace_adapter
    import rvfi_pkg::*;
(
    input mailbox #(rvfi_txn) spike2scb
);

    task automatic push (ref rvfi_txn pending, input rvfi_txn next, input mailbox #(rvfi_txn) spike2scb);
        if (pending != null && spike2scb != null) begin
            if (next != null) pending.rvfi_pc_wdata = next.rvfi_pc_rdata;
            else pending.rvfi_pc_wdata = pending.rvfi_pc_rdata + 32'd4;
            spike2scb.put(pending);
        end
    endtask

    initial begin
        string log_path, line;
        int fd;

        int hart, priv, rd_idx;
        logic [31:0] pc, insn, rd_val, mem_addr, mem_data;
        rvfi_txn txn, pending;
        logic done;
        
        if (!$value$plusargs("SPIKE_LOG=%s", log_path)) begin
            $error("SPIKE_LOG path not provided");
            $finish;
        end

        fd = $fopen(log_path, "r");
        if (fd == 0) begin
            $error("Could not open file %s", log_path);
            $finish;
        end

        pending = null;
        done = 1'b0;

        while (!done && $fgets(line, fd)) begin
            txn = null;

            if ($sscanf(line, "core %d: %d 0x%h (0x%h) x%d 0x%h mem 0x%h",
                        hart, priv, pc, insn, rd_idx, rd_val, mem_addr) == 7 && pc >= RESET_VECTOR) begin
                txn = new();
                txn.rvfi_pc_rdata  = pc;
                txn.rvfi_insn      = insn;
                txn.rvfi_rd_addr   = rd_idx;
                txn.rvfi_rd_wdata  = rd_val;
                txn.rvfi_mem_addr  = {mem_addr[31:2], 2'b00};
                txn.rvfi_mem_rmask = decode_mask(insn, mem_addr);
                if (txn.rvfi_mem_rmask == 4'b1111) txn.rvfi_mem_rdata = rd_val;
            end
            else if ($sscanf(line, "core %d: %d 0x%h (0x%h) mem 0x%h 0x%h",
                             hart, priv, pc, insn, mem_addr, mem_data) == 6 && pc >= RESET_VECTOR) begin
                if (mem_addr inside {SIM_EXIT, SIM_EXIT_HI}) begin
                    done = 1'b1;
                end else begin
                    txn = new();
                    txn.rvfi_pc_rdata  = pc;
                    txn.rvfi_insn      = insn;
                    txn.rvfi_mem_addr  = {mem_addr[31:2], 2'b00};
                    txn.rvfi_mem_wmask = decode_mask(insn, mem_addr);
                    txn.rvfi_mem_wdata = mem_data << (8 * mem_addr[1:0]);
                end
            end
            else if ($sscanf(line, "core %d: %d 0x%h (0x%h) x%d 0x%h",
                             hart, priv, pc, insn, rd_idx, rd_val) == 6 && pc >= RESET_VECTOR) begin
                txn = new();
                txn.rvfi_pc_rdata = pc;
                txn.rvfi_insn     = insn;
                txn.rvfi_rd_addr  = rd_idx;
                txn.rvfi_rd_wdata = rd_val;
            end
            else if ($sscanf(line, "core %d: %d 0x%h (0x%h)",
                             hart, priv, pc, insn) == 4 && pc >= RESET_VECTOR) begin
                txn = new();
                txn.rvfi_pc_rdata = pc;
                txn.rvfi_insn     = insn;
            end

            if (txn != null) begin
                push(pending, txn, spike2scb);
                pending = txn;
            end
        end

        push(pending, null, spike2scb);
        $fclose(fd);
    end

endmodule
