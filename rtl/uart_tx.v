
// ============================================================
//  Module  : uart_tx
//  Project : UART Controller
//  Author  : [Your Name]
//
//  FSM States : IDLE → START → DATA → STOP → IDLE
//
//  Key fix: baud_gen is cleared when start is detected,
//  guaranteeing the first bit (start bit) is exactly
//  CPB cycles wide regardless of baud counter phase.
// ============================================================
module uart_tx #(
    parameter CLK_FREQ  = 50_000_000,
    parameter BAUD_RATE = 9_600
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       start,
    input  wire [7:0] data_in,
    output reg        tx,
    output reg        busy
);
 
    wire tick;
    reg  baud_clear;
 
    baud_gen #(.CLK_FREQ(CLK_FREQ),.BAUD_RATE(BAUD_RATE)) baud_inst (
        .clk  (clk),
        .rst_n(rst_n),
        .clear(baud_clear),
        .tick (tick)
    );
 
    localparam IDLE  = 2'b00;
    localparam START = 2'b01;
    localparam DATA  = 2'b10;
    localparam STOP  = 2'b11;
 
    reg [1:0] state;
    reg [7:0] shift_reg;
    reg [2:0] bit_index;
 
    always @(posedge clk) begin
        if (!rst_n) begin
            state      <= IDLE;
            tx         <= 1'b1;
            busy       <= 1'b0;
            baud_clear <= 1'b0;
            shift_reg  <= 8'b0;
            bit_index  <= 3'b0;
        end else begin
            baud_clear <= 1'b0; // default: don't clear
 
            case (state)
                IDLE: begin
                    tx   <= 1'b1;
                    busy <= 1'b0;
                    if (start) begin
                        shift_reg  <= data_in;
                        busy       <= 1'b1;
                        baud_clear <= 1'b1; // reset counter NOW
                        state      <= START;
                    end
                end
 
                START: begin
                    tx <= 1'b0;
                    if (tick) begin
                        bit_index <= 3'b0;
                        state     <= DATA;
                    end
                end
 
                DATA: begin
                    tx <= shift_reg[0];
                    if (tick) begin
                        shift_reg <= shift_reg >> 1;
                        if (bit_index == 3'd7)
                            state <= STOP;
                        else
                            bit_index <= bit_index + 1;
                    end
                end
 
                STOP: begin
                    tx <= 1'b1;
                    if (tick) begin
                        busy  <= 1'b0;
                        state <= IDLE;
                    end
                end
 
                default: state <= IDLE;
            endcase
        end
    end
endmodule