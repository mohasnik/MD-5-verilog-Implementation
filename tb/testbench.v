`define MSG_INIT_FILE "../mem/inputMessage.mem"

`timescale 1ns/1ns
module TB();

    reg clk = 0, reset, start;
    wire[31:0] message;
    wire[3:0] messageAddr;
    wire mem_read;
    wire output_valid;
    wire[31:0] hashValue;

    memory #(16, 32, `MSG_INIT_FILE) messageMem(.clk(clk), .read_en(mem_read), .address(messageAddr), .result(message));
    MD5_accelerator DUT(.clk(clk), .reset(reset), .start(start), .messageChunk(message), .messageAddress(messageAddr), .mem_read(mem_read), .hashValue(hashValue), .output_valid(output_valid));

    always #5 clk = ~clk;

    initial begin
        #17 reset = 1'b1;

        #19 reset = 1'b0;

        #13 start = 1'b1;

        #12 start = 1'b0;

        #2500 $stop;
    end

endmodule