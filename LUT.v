module LUT #(
    parameter totalSize = 16,
    parameter width = 8, 
    parameter init_file = ""
)(
    address,
    result
);
    localparam address_width = $clog2(totalSize);

    input[address_width-1:0] address;
    output[width-1:0] result;

    reg[width-1:0] mem[0:totalSize-1];

    initial begin
        $readmemh(init_file, mem);
    end

    assign result = mem[address];
    
endmodule