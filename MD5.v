`define CONST_INIT_FILE "./mem/constants.mem"

module MD5_accelerator #(
    parameter size = 32
) (
    input clk, reset, start,
    input[31:0] messageChunk,
    output[3:0] messageAddress,
    output reg mem_read,
    output[31:0] hashValue,
    output reg output_valid
);
    localparam[31:0] A_INIT = 32'h67452301;
    localparam[31:0] B_INIT = 32'hefcdab89;
    localparam[31:0] C_INIT = 32'h98badcfe;
    localparam[31:0] D_INIT = 32'h10325476;

    parameter[2:0] STATE_IDLE = 3'd0, STATE_INIT = 3'd1, STATE_MEM_READ = 3'd2, STATE_CALC = 3'd3, 
                   STATE_FINAL_SUM = 3'd4, STATE_OUTPUT_DATA = 3'd5;


    reg[31:0] A, B, C, D;
    reg[5:0] cnt_i;     // i iterator

    wire[31:0] F, S, shift_in, constantValue;
    wire[1:0] round;
    wire[3:0] j;
    wire[4:0] shift_amnt;
    
    wire cout;
    reg[2:0] ps, ns;
    reg load_en, reg_init, cnt_en, cnt_clr, cnt_init, final_sum;


    // constants LUT :
    reg[31:0] constants[0:63];
    initial begin
        $readmemh(`CONST_INIT_FILE, constants);
    end
    // end of constants LUT



    always @(*) begin
        ns = STATE_IDLE;

        case (ps)
            STATE_IDLE : ns = start ? STATE_INIT : STATE_IDLE;

            STATE_INIT : ns = start ? STATE_INIT : STATE_MEM_READ;

            STATE_MEM_READ : ns = STATE_CALC;

            STATE_CALC : ns = cout ? STATE_FINAL_SUM : STATE_MEM_READ;

            STATE_FINAL_SUM : ns = STATE_OUTPUT_DATA;

            STATE_OUTPUT_DATA : ns = cout ? STATE_IDLE : STATE_OUTPUT_DATA;

            default: ns = STATE_IDLE;

        endcase
        
    end

    always @(*) begin
        {load_en, reg_init, cnt_en, output_valid, final_sum, mem_read, cnt_clr, cnt_init} = 0;

        case (ps)
            STATE_IDLE: begin
                cnt_clr = 1'b1;
            end

            STATE_INIT : begin
                reg_init = 1'b1;
                mem_read = 1'b1;
            end

            STATE_MEM_READ : begin
                mem_read = 1'b1;
            end

            STATE_CALC : begin
                load_en = 1'b1;
                cnt_en = 1'b1;
            end

            STATE_FINAL_SUM : begin
                final_sum = 1'b1;
                cnt_clr = 1'b1;
                cnt_init = 1'b1;
            end

            STATE_OUTPUT_DATA : begin
                output_valid = 1'b1;
                cnt_en = 1'b1;
            end

        endcase
    end


    always @(posedge clk, posedge reset) begin
        if(reset) begin
            cnt_i = 0;
            // ps = STATE_IDLE;
            A = 0;
            B = 0;
            C = 0;
            D = 0;
        end

        else begin
            ps <= ns;

            if(load_en) begin
                A <= D;
                B <= B + S;
                C <= B;
                D <= C;
            end
            else if (reg_init) begin
                A <= A_INIT;
                B <= B_INIT;
                C <= C_INIT;
                D <= D_INIT;
            end
            else if (final_sum) begin
                A <= A + A_INIT;
                B <= B + B_INIT;
                C <= C + C_INIT;
                D <= D + D_INIT;
            end

            if(cnt_clr) begin
                cnt_i = cnt_init ? (6'd60) : 6'd0;
            end
            else if(cnt_en)
                cnt_i <= cnt_i + 1'b1;
        end
    end


    assign round = cnt_i >> 4;

    assign F = (round == 2'b00) ? (B & C) | ((~B) & D):
               (round == 2'b01) ? (D & B) | ((~D) & C):
               (round == 2'b10) ? B ^ C ^ D :
               (round == 2'b11) ? C ^ (B | (~D)) : 32'b0;
    
    assign shift_in = A + F + messageChunk + constantValue;

    assign shift_amnt = (round == 2'b00) ? 5'b00111 + (cnt_i[1:0] << 2) + (cnt_i[1:0]) :                      //7 + 5*Round
                        (round == 2'b01) ? ((cnt_i[1:0] == 2'b00) ? 5'b00101 : 
                                            (cnt_i[1:0] == 2'b01) ? 5'b01001 :
                                            (cnt_i[1:0] == 2'b10) ? 5'b01110 : 5'b10100):                     // 5 9 14 20
                                                                            
                        (round == 2'b10) ? ((cnt_i[1:0] == 2'b00) ? 5'b00100 : 
                                            (cnt_i[1:0] == 2'b01) ? 5'b01011 :
                                            (cnt_i[1:0] == 2'b10) ? 5'b10000 : 5'b10111) :                  // 4 + 7*Round
                                            
                        (round == 2'b11) ? ((cnt_i[1:0] == 2'b00) ? 5'b00110 : 
                                            (cnt_i[1:0] == 2'b01) ? 5'b01010 :
                                            (cnt_i[1:0] == 2'b10) ? 5'b01111 : 5'b10101) : 5'b0;                            // 6 + 4*Round


    assign S = (shift_in << shift_amnt) | (shift_in >> (size - shift_amnt));


    assign j = (round == 2'b00) ? cnt_i :
               (round == 2'b01) ? (cnt_i << 2) + cnt_i + 1'b1 :                 // 5*i + 1
               (round == 2'b10) ? (cnt_i << 1) + cnt_i + 3'b101 :               //3*i + 5
               (round == 2'b11) ? (cnt_i << 2) + (cnt_i << 1) + cnt_i : 4'b0;   //7*i
    
    assign messageAddress = j;

    assign constantValue = constants[cnt_i];

    assign hashValue =  (cnt_i[1:0] == 2'b00) ? {D[7:0], D[15:8], D[23:16], D[31:24]} :
                        (cnt_i[1:0] == 2'b01) ? {C[7:0], C[15:8], C[23:16], C[31:24]} :
                        (cnt_i[1:0] == 2'b10) ? {B[7:0], B[15:8], B[23:16], B[31:24]} :
                        {A[7:0], A[15:8], A[23:16], A[31:24]};
    


    assign cout = &{cnt_i};

endmodule