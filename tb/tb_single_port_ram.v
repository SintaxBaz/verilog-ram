`timescale 1ns / 1ps
//------------------------------------------------------------------------------
// Testbench : tb_single_port_ram
// Self-checking testbench for single_port_ram
//   - ref_mem is a reference model (the testbench's own copy of the memory)
//   - Every clock cycle, the expected dout is computed from the model
//     and compared with the DUT's dout automatically
//   - Inputs are driven on the NEGATIVE edge so they are stable at the
//     positive edge (avoids race conditions)
//------------------------------------------------------------------------------
module tb_single_port_ram;

    localparam DATA_WIDTH = 8;
    localparam ADDR_WIDTH = 4;
    localparam DEPTH      = 1 << ADDR_WIDTH;
    localparam N_RANDOM   = 1000;           // number of random operations

    // DUT signals
    reg                   clk  = 0;
    reg                   en   = 0;
    reg                   we   = 0;
    reg  [ADDR_WIDTH-1:0] addr = 0;
    reg  [DATA_WIDTH-1:0] din  = 0;
    wire [DATA_WIDTH-1:0] dout;

    // Reference model + scoreboard
    reg  [DATA_WIDTH-1:0] ref_mem [0:DEPTH-1];
    reg  [DATA_WIDTH-1:0] exp_dout;
    integer errors = 0;
    integer checks = 0;
    integer i;

    // Device Under Test
    single_port_ram #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) dut (
        .clk (clk),
        .en  (en),
        .we  (we),
        .addr(addr),
        .din (din),
        .dout(dout)
    );

    // 100 MHz clock (10 ns period)
    always #5 clk = ~clk;

    //--------------------------------------------------------------------------
    // do_op: perform ONE clock cycle of operation and check the result
    //--------------------------------------------------------------------------
    task do_op(input e, input w, input [ADDR_WIDTH-1:0] a, input [DATA_WIDTH-1:0] d);
        begin
            // 1. Drive inputs on the falling edge
            @(negedge clk);
            en = e; we = w; addr = a; din = d;

            // 2. Rising edge: RAM operates. Update the model the same way (read-first)
            @(posedge clk);
            if (e) begin
                exp_dout = ref_mem[a];      // read OLD value first
                if (w) ref_mem[a] = d;      // then write
            end                              // en = 0 -> exp_dout unchanged (hold)

            // 3. Small delay so the DUT output settles, then compare
            #1;
            checks = checks + 1;
            if (dout !== exp_dout) begin
                errors = errors + 1;
                $display("ERROR @%0t ns: en=%b we=%b addr=%0d din=%h | dout=%h expected=%h",
                         $time, e, w, a, d, dout, exp_dout);
            end
        end
    endtask

    //--------------------------------------------------------------------------
    // Test sequence
    //--------------------------------------------------------------------------
    initial begin
        $display("=== Single port RAM test started ===");

        // TEST 1: write every address
        $display("TEST 1: write all addresses");
        for (i = 0; i < DEPTH; i = i + 1)
            do_op(1, 1, i, i * 8'h11 + 8'h05);

        // TEST 2: read back every address
        $display("TEST 2: read back all addresses");
        for (i = 0; i < DEPTH; i = i + 1)
            do_op(1, 0, i, 8'h00);

        // TEST 3: read-first behaviour (dout must show OLD data during a write)
        $display("TEST 3: read-first check");
        do_op(1, 1, 3, 8'hAA);   // write AA to addr 3   (dout = old value)
        do_op(1, 1, 3, 8'h55);   // write 55 to addr 3   (dout must be AA)
        do_op(1, 0, 3, 8'h00);   // read addr 3          (dout must be 55)

        // TEST 4: en = 0 -> no write, dout must hold
        $display("TEST 4: enable low check");
        do_op(1, 0, 5, 8'h00);   // read addr 5 normally
        do_op(0, 1, 5, 8'hFF);   // en = 0: write must NOT happen, dout holds
        do_op(0, 0, 9, 8'h00);   // en = 0: dout still holds
        do_op(1, 0, 5, 8'h00);   // addr 5 must NOT be FF

        // TEST 5: corner addresses (first and last)
        $display("TEST 5: first and last address");
        do_op(1, 1, 0,         8'hC3);
        do_op(1, 1, DEPTH - 1, 8'h3C);
        do_op(1, 0, 0,         8'h00);
        do_op(1, 0, DEPTH - 1, 8'h00);

        // TEST 6: random operations (en is 1 about 7/8 of the time)
        $display("TEST 6: %0d random operations", N_RANDOM);
        for (i = 0; i < N_RANDOM; i = i + 1)
            do_op(({$random} % 8) != 0, $random, $random, $random);

        // Summary
        $display("============================================");
        $display(" Checks : %0d", checks);
        $display(" Errors : %0d", errors);
        if (errors == 0) $display(" RESULT : TEST PASSED");
        else             $display(" RESULT : TEST FAILED");
        $display("============================================");
        $finish;
    end

endmodule
