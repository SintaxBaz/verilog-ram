`timescale 1ns / 1ps
//------------------------------------------------------------------------------
// Testbench : tb_dual_port_ram
// Self-checking testbench for dual_port_ram (true dual port, read-first)
//   - ref_mem is the reference model of the shared memory
//   - Each cycle: BOTH ports read their OLD value from the model first,
//     then the writes are applied (read-first on both ports)
//   - Protocol checker: flags any cycle where both ports write the SAME
//     address (not allowed by the spec)
//   - Inputs are driven on the falling edge to avoid race conditions
//------------------------------------------------------------------------------
module tb_dual_port_ram;

    localparam DATA_WIDTH = 8;
    localparam ADDR_WIDTH = 4;
    localparam DEPTH      = 1 << ADDR_WIDTH;
    localparam N_RANDOM   = 2000;

    // DUT signals
    reg                   clk = 0;
    reg                   en_a = 0, we_a = 0, en_b = 0, we_b = 0;
    reg  [ADDR_WIDTH-1:0] addr_a = 0, addr_b = 0;
    reg  [DATA_WIDTH-1:0] din_a = 0,  din_b = 0;
    wire [DATA_WIDTH-1:0] dout_a, dout_b;

    // Reference model + scoreboard
    reg  [DATA_WIDTH-1:0] ref_mem [0:DEPTH-1];
    reg  [DATA_WIDTH-1:0] exp_a, exp_b;
    integer errors     = 0;
    integer checks     = 0;
    integer violations = 0;
    integer i;
    integer test_id = 0;    // shows which test is running (add it to the waveform)

    // Random stimulus variables
    reg                   r_en_a, r_we_a, r_en_b, r_we_b;
    reg  [ADDR_WIDTH-1:0] r_addr_a, r_addr_b;

    // Device Under Test
    dual_port_ram #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) dut (
        .clk   (clk),
        .en_a  (en_a), .we_a(we_a), .addr_a(addr_a), .din_a(din_a), .dout_a(dout_a),
        .en_b  (en_b), .we_b(we_b), .addr_b(addr_b), .din_b(din_b), .dout_b(dout_b)
    );

    // 100 MHz clock
    always #5 clk = ~clk;

    //--------------------------------------------------------------------------
    // Protocol checker: both ports writing the same address is NOT allowed
    //--------------------------------------------------------------------------
    always @(posedge clk) begin
        if (en_a && we_a && en_b && we_b && (addr_a == addr_b)) begin
            violations = violations + 1;
            $display("PROTOCOL VIOLATION @%0t ns: both ports write addr %0d", $time, addr_a);
        end
    end

    //--------------------------------------------------------------------------
    // do_op: one clock cycle on both ports, then check both outputs
    //--------------------------------------------------------------------------
    task do_op(
        input ea, input wa, input [ADDR_WIDTH-1:0] aa, input [DATA_WIDTH-1:0] da,
        input eb, input wb, input [ADDR_WIDTH-1:0] ab, input [DATA_WIDTH-1:0] db
    );
        begin
            // 1. Drive both ports on the falling edge
            @(negedge clk);
            en_a = ea; we_a = wa; addr_a = aa; din_a = da;
            en_b = eb; we_b = wb; addr_b = ab; din_b = db;

            // 2. Rising edge: update model. Reads FIRST (old data) ...
            @(posedge clk);
            if (ea) exp_a = ref_mem[aa];
            if (eb) exp_b = ref_mem[ab];
            // ... then writes
            if (ea && wa) ref_mem[aa] = da;
            if (eb && wb) ref_mem[ab] = db;

            // 3. Compare both ports
            #1;
            checks = checks + 2;
            if (dout_a !== exp_a) begin
                errors = errors + 1;
                $display("ERROR port A @%0t ns: en=%b we=%b addr=%0d | dout_a=%h expected=%h",
                         $time, ea, wa, aa, dout_a, exp_a);
            end
            if (dout_b !== exp_b) begin
                errors = errors + 1;
                $display("ERROR port B @%0t ns: en=%b we=%b addr=%0d | dout_b=%h expected=%h",
                         $time, eb, wb, ab, dout_b, exp_b);
            end
        end
    endtask

    //--------------------------------------------------------------------------
    // Test sequence
    //--------------------------------------------------------------------------
    initial begin
        $display("=== Dual port RAM test started ===");

        // TEST 1: port A writes everything, port B reads it back
        test_id = 1;
        $display("[%0d ns] TEST 1: write via A, read via B", $time);
        for (i = 0; i < DEPTH; i = i + 1)
            do_op(1, 1, i, i * 8'h11 + 8'h01,   0, 0, 0, 0);
        for (i = 0; i < DEPTH; i = i + 1)
            do_op(0, 0, 0, 0,                   1, 0, i, 0);

        // TEST 2: port B writes everything, port A reads it back
        test_id = 2;
        $display("[%0d ns] TEST 2: write via B, read via A", $time);
        for (i = 0; i < DEPTH; i = i + 1)
            do_op(0, 0, 0, 0,                   1, 1, i, 8'hF0 - i);
        for (i = 0; i < DEPTH; i = i + 1)
            do_op(1, 0, i, 0,                   0, 0, 0, 0);

        // TEST 3: A writes one address while B reads a DIFFERENT address
        test_id = 3;
        $display("[%0d ns] TEST 3: simultaneous write A / read B, different addresses", $time);
        for (i = 0; i < DEPTH; i = i + 1)
            do_op(1, 1, i, 8'h80 + i,           1, 0, (i + 8) % DEPTH, 0);

        // TEST 4: both ports write DIFFERENT addresses in the same cycle
        test_id = 4;
        $display("[%0d ns] TEST 4: simultaneous writes, different addresses", $time);
        do_op(1, 1, 2, 8'hA2,                   1, 1, 13, 8'hBD);
        do_op(1, 0, 13, 0,                      1, 0, 2, 0);   // cross read-back

        // TEST 5: collision - A writes, B reads SAME address -> B gets OLD data
        test_id = 5;
        $display("[%0d ns] TEST 5: collision A write / B read (B must see old data)", $time);
        do_op(1, 1, 6, 8'h11,                   0, 0, 0, 0);   // addr 6 = 11
        do_op(1, 1, 6, 8'h22,                   1, 0, 6, 0);   // B must read 11
        do_op(0, 0, 0, 0,                       1, 0, 6, 0);   // B now reads 22

        // TEST 6: collision - B writes, A reads SAME address -> A gets OLD data
        test_id = 6;
        $display("[%0d ns] TEST 6: collision B write / A read (A must see old data)", $time);
        do_op(1, 0, 9, 0,                       1, 1, 9, 8'h33);
        do_op(1, 0, 9, 0,                       1, 1, 9, 8'h44);   // A must read 33
        do_op(1, 0, 9, 0,                       0, 0, 0, 0);       // A now reads 44

        // TEST 7: both ports read the SAME address
        test_id = 7;
        $display("[%0d ns] TEST 7: both ports read same address", $time);
        do_op(1, 0, 6, 0,                       1, 0, 6, 0);

        // TEST 8: one port disabled - its output must hold, no write
        test_id = 8;
        $display("[%0d ns] TEST 8: enable low on one port", $time);
        do_op(0, 1, 1, 8'hEE,                   1, 0, 1, 0);   // A disabled: no write
        do_op(1, 0, 1, 0,                       0, 1, 1, 8'hDD); // B disabled: no write
        do_op(1, 0, 1, 0,                       1, 0, 1, 0);   // addr 1 unchanged

        // TEST 9: random traffic on both ports (illegal double-write avoided)
        test_id = 9;
        $display("[%0d ns] TEST 9: %0d random cycles on both ports", $time, N_RANDOM);
        for (i = 0; i < N_RANDOM; i = i + 1) begin
            r_en_a   = ({$random} % 8) != 0;
            r_we_a   = $random;
            r_addr_a = $random;
            r_en_b   = ({$random} % 8) != 0;
            r_we_b   = $random;
            r_addr_b = ({$random} % 4 == 0) ? r_addr_a : $random;  // force ~25% same-address cycles
            if (r_en_a && r_we_a && r_en_b && r_we_b && (r_addr_a == r_addr_b))
                r_we_b = 0;                                        // obey the spec
            do_op(r_en_a, r_we_a, r_addr_a, $random,
                  r_en_b, r_we_b, r_addr_b, $random);
        end

        // Summary
        $display("============================================");
        $display(" Checks     : %0d", checks);
        $display(" Errors     : %0d", errors);
        $display(" Violations : %0d", violations);
        if (errors == 0 && violations == 0) $display(" RESULT     : TEST PASSED");
        else                                $display(" RESULT     : TEST FAILED");
        $display("============================================");
        $finish;
    end

endmodule
