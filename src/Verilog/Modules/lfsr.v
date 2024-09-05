module lfsr (
    input wire clk,
    input wire rst_n,
    input wire enable,
    output reg noise
);
    reg [15:0] lfsr_reg;
    wire feedback;

    assign feedback = lfsr_reg[15] ^ lfsr_reg[14] ^ lfsr_reg[13] ^ lfsr_reg[10];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            lfsr_reg <= 16'hFFFF;
            noise <= 0;
        end else if (enable) begin
            lfsr_reg <= {lfsr_reg[14:0], feedback};
            noise <= lfsr_reg[15];
        end
    end
endmodule