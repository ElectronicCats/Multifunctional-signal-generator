module sine_wave_generator (
    input wire clk,                  // Reloj de entrada
    input wire reset,                // Señal de reinicio
    input wire [2:0] freq_select,    // Selección de frecuencia (3 bits para 8 niveles)
    output reg [7:0] wave_out        // Salida de onda senoidal de 8 bits
);

    reg [7:0] counter;               // Contador para indexar la tabla
    reg [7:0] sine_table [0:255];    // Tabla de valores senoidales (256 valores de 8 bits)
    reg [7:0] clk_div;               // Contador de divisor de reloj
    reg [7:0] clk_div_threshold;     // Umbral para el divisor de reloj

    // Inicialización de la tabla de valores senoidales
    initial begin
        sine_table[0] = 8'd128;
sine_table[1] = 8'd131;
sine_table[2] = 8'd134;
sine_table[3] = 8'd137;
sine_table[4] = 8'd140;
sine_table[5] = 8'd143;
sine_table[6] = 8'd146;
sine_table[7] = 8'd149;
sine_table[8] = 8'd152;
sine_table[9] = 8'd155;
sine_table[10] = 8'd158;
sine_table[11] = 8'd161;
sine_table[12] = 8'd164;
sine_table[13] = 8'd167;
sine_table[14] = 8'd170;
sine_table[15] = 8'd173;
sine_table[16] = 8'd176;
sine_table[17] = 8'd179;
sine_table[18] = 8'd182;
sine_table[19] = 8'd185;
sine_table[20] = 8'd187;
sine_table[21] = 8'd190;
sine_table[22] = 8'd193;
sine_table[23] = 8'd195;
sine_table[24] = 8'd198;
sine_table[25] = 8'd201;
sine_table[26] = 8'd203;
sine_table[27] = 8'd206;
sine_table[28] = 8'd208;
sine_table[29] = 8'd210;
sine_table[30] = 8'd213;
sine_table[31] = 8'd215;
sine_table[32] = 8'd217;
sine_table[33] = 8'd219;
sine_table[34] = 8'd222;
sine_table[35] = 8'd224;
sine_table[36] = 8'd226;
sine_table[37] = 8'd228;
sine_table[38] = 8'd230;
sine_table[39] = 8'd231;
sine_table[40] = 8'd233;
sine_table[41] = 8'd235;
sine_table[42] = 8'd236;
sine_table[43] = 8'd238;
sine_table[44] = 8'd240;
sine_table[45] = 8'd241;
sine_table[46] = 8'd242;
sine_table[47] = 8'd244;
sine_table[48] = 8'd245;
sine_table[49] = 8'd246;
sine_table[50] = 8'd247;
sine_table[51] = 8'd248;
sine_table[52] = 8'd249;
sine_table[53] = 8'd250;
sine_table[54] = 8'd251;
sine_table[55] = 8'd251;
sine_table[56] = 8'd252;
sine_table[57] = 8'd253;
sine_table[58] = 8'd253;
sine_table[59] = 8'd254;
sine_table[60] = 8'd254;
sine_table[61] = 8'd254;
sine_table[62] = 8'd254;
sine_table[63] = 8'd254;
sine_table[64] = 8'd255;
sine_table[65] = 8'd254;
sine_table[66] = 8'd254;
sine_table[67] = 8'd254;
sine_table[68] = 8'd254;
sine_table[69] = 8'd254;
sine_table[70] = 8'd253;
sine_table[71] = 8'd253;
sine_table[72] = 8'd252;
sine_table[73] = 8'd251;
sine_table[74] = 8'd251;
sine_table[75] = 8'd250;
sine_table[76] = 8'd249;
sine_table[77] = 8'd248;
sine_table[78] = 8'd247;
sine_table[79] = 8'd246;
sine_table[80] = 8'd245;
sine_table[81] = 8'd244;
sine_table[82] = 8'd242;
sine_table[83] = 8'd241;
sine_table[84] = 8'd240;
sine_table[85] = 8'd238;
sine_table[86] = 8'd236;
sine_table[87] = 8'd235;
sine_table[88] = 8'd233;
sine_table[89] = 8'd231;
sine_table[90] = 8'd230;
sine_table[91] = 8'd228;
sine_table[92] = 8'd226;
sine_table[93] = 8'd224;
sine_table[94] = 8'd222;
sine_table[95] = 8'd219;
sine_table[96] = 8'd217;
sine_table[97] = 8'd215;
sine_table[98] = 8'd213;
sine_table[99] = 8'd210;
sine_table[100] = 8'd208;
sine_table[101] = 8'd206;
sine_table[102] = 8'd203;
sine_table[103] = 8'd201;
sine_table[104] = 8'd198;
sine_table[105] = 8'd195;
sine_table[106] = 8'd193;
sine_table[107] = 8'd190;
sine_table[108] = 8'd187;
sine_table[109] = 8'd185;
sine_table[110] = 8'd182;
sine_table[111] = 8'd179;
sine_table[112] = 8'd176;
sine_table[113] = 8'd173;
sine_table[114] = 8'd170;
sine_table[115] = 8'd167;
sine_table[116] = 8'd164;
sine_table[117] = 8'd161;
sine_table[118] = 8'd158;
sine_table[119] = 8'd155;
sine_table[120] = 8'd152;
sine_table[121] = 8'd149;
sine_table[122] = 8'd146;
sine_table[123] = 8'd143;
sine_table[124] = 8'd140;
sine_table[125] = 8'd137;
sine_table[126] = 8'd134;
sine_table[127] = 8'd131;
sine_table[128] = 8'd128;
sine_table[129] = 8'd124;
sine_table[130] = 8'd121;
sine_table[131] = 8'd118;
sine_table[132] = 8'd115;
sine_table[133] = 8'd112;
sine_table[134] = 8'd109;
sine_table[135] = 8'd106;
sine_table[136] = 8'd103;
sine_table[137] = 8'd100;
sine_table[138] = 8'd97;
sine_table[139] = 8'd94;
sine_table[140] = 8'd91;
sine_table[141] = 8'd88;
sine_table[142] = 8'd85;
sine_table[143] = 8'd82;
sine_table[144] = 8'd79;
sine_table[145] = 8'd76;
sine_table[146] = 8'd73;
sine_table[147] = 8'd70;
sine_table[148] = 8'd68;
sine_table[149] = 8'd65;
sine_table[150] = 8'd62;
sine_table[151] = 8'd60;
sine_table[152] = 8'd57;
sine_table[153] = 8'd54;
sine_table[154] = 8'd52;
sine_table[155] = 8'd49;
sine_table[156] = 8'd47;
sine_table[157] = 8'd45;
sine_table[158] = 8'd42;
sine_table[159] = 8'd40;
sine_table[160] = 8'd38;
sine_table[161] = 8'd36;
sine_table[162] = 8'd33;
sine_table[163] = 8'd31;
sine_table[164] = 8'd29;
sine_table[165] = 8'd27;
sine_table[166] = 8'd25;
sine_table[167] = 8'd24;
sine_table[168] = 8'd22;
sine_table[169] = 8'd20;
sine_table[170] = 8'd19;
sine_table[171] = 8'd17;
sine_table[172] = 8'd15;
sine_table[173] = 8'd14;
sine_table[174] = 8'd13;
sine_table[175] = 8'd11;
sine_table[176] = 8'd10;
sine_table[177] = 8'd9;
sine_table[178] = 8'd8;
sine_table[179] = 8'd7;
sine_table[180] = 8'd6;
sine_table[181] = 8'd5;
sine_table[182] = 8'd4;
sine_table[183] = 8'd4;
sine_table[184] = 8'd3;
sine_table[185] = 8'd2;
sine_table[186] = 8'd2;
sine_table[187] = 8'd1;
sine_table[188] = 8'd1;
sine_table[189] = 8'd1;
sine_table[190] = 8'd1;
sine_table[191] = 8'd1;
sine_table[192] = 8'd1;
sine_table[193] = 8'd1;
sine_table[194] = 8'd1;
sine_table[195] = 8'd1;
sine_table[196] = 8'd1;
sine_table[197] = 8'd1;
sine_table[198] = 8'd2;
sine_table[199] = 8'd2;
sine_table[200] = 8'd3;
sine_table[201] = 8'd4;
sine_table[202] = 8'd4;
sine_table[203] = 8'd5;
sine_table[204] = 8'd6;
sine_table[205] = 8'd7;
sine_table[206] = 8'd8;
sine_table[207] = 8'd9;
sine_table[208] = 8'd10;
sine_table[209] = 8'd11;
sine_table[210] = 8'd13;
sine_table[211] = 8'd14;
sine_table[212] = 8'd15;
sine_table[213] = 8'd17;
sine_table[214] = 8'd19;
sine_table[215] = 8'd20;
sine_table[216] = 8'd22;
sine_table[217] = 8'd24;
sine_table[218] = 8'd25;
sine_table[219] = 8'd27;
sine_table[220] = 8'd29;
sine_table[221] = 8'd31;
sine_table[222] = 8'd33;
sine_table[223] = 8'd36;
sine_table[224] = 8'd38;
sine_table[225] = 8'd40;
sine_table[226] = 8'd42;
sine_table[227] = 8'd45;
sine_table[228] = 8'd47;
sine_table[229] = 8'd49;
sine_table[230] = 8'd52;
sine_table[231] = 8'd54;
sine_table[232] = 8'd57;
sine_table[233] = 8'd60;
sine_table[234] = 8'd62;
sine_table[235] = 8'd65;
sine_table[236] = 8'd68;
sine_table[237] = 8'd70;
sine_table[238] = 8'd73;
sine_table[239] = 8'd76;
sine_table[240] = 8'd79;
sine_table[241] = 8'd82;
sine_table[242] = 8'd85;
sine_table[243] = 8'd88;
sine_table[244] = 8'd91;
sine_table[245] = 8'd94;
sine_table[246] = 8'd97;
sine_table[247] = 8'd100;
sine_table[248] = 8'd103;
sine_table[249] = 8'd106;
sine_table[250] = 8'd109;
sine_table[251] = 8'd112;
sine_table[252] = 8'd115;
sine_table[253] = 8'd118;
sine_table[254] = 8'd121;
sine_table[255] = 8'd124;
    end

    // Lógica del divisor de reloj y selección de frecuencia
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            counter <= 8'd0;
            clk_div <= 8'd0;
            wave_out <= 8'd0;
        end else begin
            case(freq_select)
                3'b000: clk_div_threshold <= 8'd128;   // Nivel de frecuencia 0
                3'b001: clk_div_threshold <= 8'd64;    // Nivel de frecuencia 1
                3'b010: clk_div_threshold <= 8'd32;    // Nivel de frecuencia 2
                3'b011: clk_div_threshold <= 8'd16;    // Nivel de frecuencia 3
                3'b100: clk_div_threshold <= 8'd8;     // Nivel de frecuencia 4
                3'b101: clk_div_threshold <= 8'd4;     // Nivel de frecuencia 5
                3'b110: clk_div_threshold <= 8'd2;     // Nivel de frecuencia 6
                3'b111: clk_div_threshold <= 8'd1;     // Nivel de frecuencia 7
                default: clk_div_threshold <= 8'd128;  // Valor por defecto
            endcase

            // Incremento del divisor de reloj
            if (clk_div >= clk_div_threshold) begin
                clk_div <= 8'd0;
                counter <= counter + 8'd1;
                wave_out <= sine_table[counter];  // Salida de la onda senoidal
            end else begin
                clk_div <= clk_div + 8'd1;
            end
        end
    end
endmodule