// ============================================================
//  Module  : baud_gen
//  Project : UART Controller
//  Author  : [Your Name]
//
//  Updated : Added clear input so TX/RX can reset the counter
//            when a new frame begins — ensures first bit is
//            always a full CPB cycles wide.
// ============================================================
module baud_gen #(
    parameter CLK_FREQ  = 50_000_000,
    parameter BAUD_RATE = 9_600
)(
    input  wire clk,
    input  wire rst_n,
    input  wire clear,  // synchronous clear — resets counter to 0
    output reg  tick
);
    localparam CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;
    localparam CTR_W = $clog2(CLKS_PER_BIT);
    reg [CTR_W-1:0] counter;

    always @(posedge clk) begin
        if (!rst_n || clear) begin
            counter <= 0;
            tick    <= 0;
        end else begin
            if (counter == CLKS_PER_BIT - 1) begin
                counter <= 0;
                tick    <= 1;
            end else begin
                counter <= counter + 1;
                tick    <= 0;
            end
        end
    end
endmodule