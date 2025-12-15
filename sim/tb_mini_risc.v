`timescale 1ns/1ps

module tb_mini_risc;

    reg clk = 0;
    reg rst_n = 0;

    // Parameters
    parameter DATA_W = 32;
    parameter ADDR_W = 12;

    wire [ADDR_W-1:0] dbg_pc_low;

    // Instantiate DUT (Device Under Test)
    mini_risc #(
        .DATA_W(DATA_W), 
        .ADDR_W(ADDR_W)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .dbg_pc_low(dbg_pc_low)
    );

    // 100 MHz clock generation
    always #5 clk = ~clk;

    // HALT Detection (Looks for 32'hFFFFFFFF)
    wire halt = (dut.instr == 32'hFFFFFFFF);

    integer k; // Loop variable

    initial begin
        // Output file setup
        $dumpfile("mini_risc.vcd");
        
        // 1. Dump standard signals (Level 0 = Recursive)
        $dumpvars(0, tb_mini_risc);

        // 2. FORCE DUMP of the Register Array
        // Simulators usually hide arrays to save space. We force it here.
        for (k = 0; k < 256; k = k + 1) begin
            $dumpvars(0, dut.regs[k]);
        end

        // Reset Sequence
        $display("Applying Reset...");
        rst_n = 0;
        #20;
        rst_n = 1;
        $display("Processor Running...");

        // Wait for HALT signal
        wait (halt === 1'b1);
        
        // Wait a few extra cycles for final writebacks to settle
        #100;

        $display("\n============================================");
        $display("                PROGRAM HALTED              ");
        $display("============================================\n");

        // Print first 16 registers to console for quick verification
        $display("----- Final Register State (First 16) -----");
        for (k = 0; k < 16; k = k + 1) begin
            $display("R%0d \t= %0d \t(Hex: 0x%h)", k, dut.regs[k], dut.regs[k]);
        end
        $display("... (Open GTKWave to view all 256 registers) ...");
        $display("-------------------------------------------\n");

        $finish;
    end

    // Timeout Protection
    // Set to 500,000 to accommodate long stress tests with slow multipliers
    initial begin
        #500000;
        $display("\n ERROR: Simulation timed out! Processor might be stuck.");
        $finish;
    end

endmodule