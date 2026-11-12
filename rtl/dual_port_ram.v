`timescale 1ns / 1ps
//------------------------------------------------------------------------------
// Module      : dual_port_ram
// Description : True dual port RAM (single clock)
//               - Two independent ports, A and B, sharing ONE memory array
//               - Each port can read OR write every clock cycle
//               - Synchronous read, 1 clock cycle latency on both ports
//               - Both ports are READ-FIRST
//
// Collision rules (same address on both ports in the same cycle):
//   A reads,  B reads   -> both get the stored data          (safe)
//   A writes, B reads   -> B gets the OLD data (read-first)   (defined)
//   B writes, A reads   -> A gets the OLD data (read-first)   (defined)
//   A writes, B writes  -> stored value is UNDEFINED          (NOT ALLOWED)
//                          The user must never do this.
//------------------------------------------------------------------------------
module dual_port_ram #(
    parameter DATA_WIDTH = 8,               // bits per word
    parameter ADDR_WIDTH = 4                // depth = 2^ADDR_WIDTH words
)(
    input  wire                  clk,

    // Port A
    input  wire                  en_a,
    input  wire                  we_a,
    input  wire [ADDR_WIDTH-1:0] addr_a,
    input  wire [DATA_WIDTH-1:0] din_a,
    output reg  [DATA_WIDTH-1:0] dout_a,

    // Port B
    input  wire                  en_b,
    input  wire                  we_b,
    input  wire [ADDR_WIDTH-1:0] addr_b,
    input  wire [DATA_WIDTH-1:0] din_b,
    output reg  [DATA_WIDTH-1:0] dout_b
);

    localparam DEPTH = 1 << ADDR_WIDTH;

    // Shared memory array
    (* ram_style = "block" *)
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    // Port A
    always @(posedge clk) begin
        if (en_a) begin
            if (we_a)
                mem[addr_a] <= din_a;
            dout_a <= mem[addr_a];   // read-first
        end
    end

    // Port B
    always @(posedge clk) begin
        if (en_b) begin
            if (we_b)
                mem[addr_b] <= din_b;
            dout_b <= mem[addr_b];   // read-first
        end
    end

endmodule
