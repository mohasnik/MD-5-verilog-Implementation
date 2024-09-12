module memory #(
    parameter totalSize = 16,
    parameter width = 8, 
    parameter init_file = ""
)(
    clk,
    read_en,
    address,
    result
);
    localparam address_width = $clog2(totalSize);

    input clk, read_en;
    input[address_width-1:0] address;
    output reg[width-1:0] result;

    reg[width-1:0] mem[0:totalSize-1];

    initial begin
        $readmemh(init_file, mem);
    end

    always @(posedge clk) begin
        if(read_en)
            result <= mem[address];
    end
    
endmodule