`timescale 1ns / 1ps
//------------------------------------------------------------------------------
// Module      : single_port_ram
// Description : Single port RAM
//               - Synchronous write
//               - Synchronous read, 1 clock cycle latency
//               - READ-FIRST: during a write, dout shows the OLD data
//                 stored at that address (new data is visible next read)
//               - en = 0 : RAM does nothing, dout holds its last value
//------------------------------------------------------------------------------
module single_port_ram #(
    parameter DATA_WIDTH = 8,               // bits per word
    parameter ADDR_WIDTH = 4                // depth = 2^ADDR_WIDTH words
)(
    input  wire                  clk,
    input  wire                  en,        // port enable
    input  wire                  we,        // write enable (1 = write)
    input  wire [ADDR_WIDTH-1:0] addr,
    input  wire [DATA_WIDTH-1:0] din,
    output reg  [DATA_WIDTH-1:0] dout
);

    localparam DEPTH = 1 << ADDR_WIDTH;

    // Memory array
    // Add (* ram_style = "block" *) on the next line to force block RAM (see README)
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    always @(posedge clk) begin
        if (en) begin
            if (we)
                mem[addr] <= din;
            dout <= mem[addr];   // non-blocking => reads value BEFORE this write
        end
    end

endmodule
