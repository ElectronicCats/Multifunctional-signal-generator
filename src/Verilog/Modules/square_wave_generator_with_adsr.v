/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`define default_netname none

module square_wave_generator_with_adsr (
    input wire clk,                  // Reloj del sistema (25 MHz)
    input wire reset,                // Señal de reinicio
    input wire [5:0] freq_select,    // Selección de frecuencia (6 bits para 64 niveles)
    input wire [7:0] attack_time,    // Tiempo de ataque (simulado por un valor digital)
    input wire [7:0] decay_time,     // Tiempo de decaimiento (simulado por un valor digital)
    input wire [7:0] sustain_level,  // Nivel de sostenimiento (simulado por un valor digital)
    input wire [7:0] release_time,   // Tiempo de liberación (simulado por un valor digital)
    input wire note_on,              // Señal de inicio de nota
    input wire note_off,             // Señal de fin de nota
    output reg [7:0] wave_out        // Salida de onda cuadrada de 8 bits
);

    reg [31:0] clk_div;              // Contador de divisor de reloj
    reg [31:0] clk_div_threshold;    // Umbral para el divisor de reloj
    reg wave_state;                  // Estado actual de la onda cuadrada

    // Variables para el ADSR
    reg [7:0] envelope_level;        // Nivel del sobre (ADS)
    reg [7:0] envelope_counter;      // Contador para la envolvente
    reg [3:0] state;                 // Estado del ADSR

    // Lógica para seleccionar el umbral del divisor de reloj según la frecuencia deseada
    always @(*) begin
        case (freq_select)
            // Octave 2
            6'b000000: clk_div_threshold = 32'd1915712;  // C2 (65.41 Hz)
            6'b000001: clk_div_threshold = 32'd1803586;  // C#2/Db2 (69.30 Hz)
            6'b000010: clk_div_threshold = 32'd1702624;  // D2 (73.42 Hz)
            6'b000011: clk_div_threshold = 32'd1607142;  // D#2/Eb2 (77.78 Hz)
            6'b000100: clk_div_threshold = 32'd1515152;  // E2 (82.41 Hz)
            6'b000101: clk_div_threshold = 32'd1431731;  // F2 (87.31 Hz)
            6'b000110: clk_div_threshold = 32'd1351351;  // F#2/Gb2 (92.50 Hz)
            6'b000111: clk_div_threshold = 32'd1275510;  // G2 (98.00 Hz)
            6'b001000: clk_div_threshold = 32'd1204819;  // G#2/Ab2 (103.83 Hz)
            6'b001001: clk_div_threshold = 32'd1136364;  // A2 (110.00 Hz)
            6'b001010: clk_div_threshold = 32'd1075268;  // A#2/Bb2 (116.54 Hz)
            6'b001011: clk_div_threshold = 32'd1017340;  // B2 (123.47 Hz)

            // Octave 3
            6'b001100: clk_div_threshold = 32'd95786;    // C3 (130.81 Hz)
            6'b001101: clk_div_threshold = 32'd90180;    // C#3/Db3 (138.59 Hz)
            6'b001110: clk_div_threshold = 32'd85131;    // D3 (146.83 Hz)
            6'b001111: clk_div_threshold = 32'd80357;    // D#3/Eb3 (155.56 Hz)
            6'b010000: clk_div_threshold = 32'd75758;    // E3 (164.81 Hz)
            6'b010001: clk_div_threshold = 32'd71586;    // F3 (174.61 Hz)
            6'b010010: clk_div_threshold = 32'd67567;    // F#3/Gb3 (185.00 Hz)
            6'b010011: clk_div_threshold = 32'd63775;    // G3 (196.00 Hz)
            6'b010100: clk_div_threshold = 32'd60241;    // G#3/Ab3 (207.65 Hz)
            6'b010101: clk_div_threshold = 32'd56818;    // A3 (220.00 Hz)
            6'b010110: clk_div_threshold = 32'd53763;    // A#3/Bb3 (233.08 Hz)
            6'b010111: clk_div_threshold = 32'd50867;    // B3 (246.94 Hz)

            // Octave 4
            6'b011000: clk_div_threshold = 32'd47878;    // C4 (261.63 Hz)
            6'b011001: clk_div_threshold = 32'd45090;    // C#4/Db4 (277.18 Hz)
            6'b011010: clk_div_threshold = 32'd42566;    // D4 (293.66 Hz)
            6'b011011: clk_div_threshold = 32'd40178;    // D#4/Eb4 (311.13 Hz)
            6'b011100: clk_div_threshold = 32'd37878;    // E4 (329.63 Hz)
            6'b011101: clk_div_threshold = 32'd35793;    // F4 (349.23 Hz)
            6'b011110: clk_div_threshold = 32'd33783;    // F#4/Gb4 (369.99 Hz)
            6'b011111: clk_div_threshold = 32'd31888;    // G4 (392.00 Hz)
            6'b100000: clk_div_threshold = 32'd30120;    // G#4/Ab4 (415.30 Hz)
            6'b100001: clk_div_threshold = 32'd28409;    // A4 (440.00 Hz)
            6'b100010: clk_div_threshold = 32'd26881;    // A#4/Bb4 (466.16 Hz)
            6'b100011: clk_div_threshold = 32'd25434;    // B4 (493.88 Hz)

            // Octave 5
            6'b100100: clk_div_threshold = 32'd23939;    // C5 (523.25 Hz)
            6'b100101: clk_div_threshold = 32'd22545;    // C#5/Db5 (554.37 Hz)
            6'b100110: clk_div_threshold = 32'd21283;    // D5 (587.33 Hz)
            6'b100111: clk_div_threshold = 32'd20089;    // D#5/Eb5 (622.25 Hz)
            6'b101000: clk_div_threshold = 32'd18938;    // E5 (659.25 Hz)
            6'b101001: clk_div_threshold = 32'd17896;    // F5 (698.46 Hz)
            6'b101010: clk_div_threshold = 32'd16891;    // F#5/Gb5 (739.99 Hz)
            6'b101011: clk_div_threshold = 32'd15944;    // G5 (783.99 Hz)
            6'b101100: clk_div_threshold = 32'd15060;    // G#5/Ab5 (830.61 Hz)
            6'b101101: clk_div_threshold = 32'd14204;    // A5 (880.00 Hz)
            6'b101110: clk_div_threshold = 32'd13441;    // A#5/Bb5 (932.33 Hz)
            6'b101111: clk_div_threshold = 32'd12717;    // B5 (987.77 Hz)

            default: clk_div_threshold = 32'd28409;      // Default to A4 (440 Hz)
        endcase
    end

    // Lógica de ADSR
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            envelope_level <= 8'd0;   // Reiniciar el nivel del sobre a 0
            envelope_counter <= 8'd0; // Reiniciar el contador del sobre a 0
            state <= 4'd0;            // Reiniciar el estado del ADSR
        end else begin
            case (state)
                4'd0: begin // Idle
                    if (note_on) state <= 4'd1; // Cambiar a ataque si se activa la nota
                end
                4'd1: begin // Attack
                    if (envelope_counter < attack_time) begin
                        envelope_counter <= envelope_counter + 1;
                        envelope_level <= envelope_counter * 8 / attack_time; // Aumento
                    end else begin
                        envelope_counter <= 8'd0;
                        state <= 4'd2; // Cambiar a decaimiento
                    end
                end
                4'd2: begin // Decay
                    if (envelope_counter < decay_time) begin
                        envelope_counter <= envelope_counter + 1;
                        envelope_level <= (sustain_level + (8'd255 - sustain_level) * (decay_time - envelope_counter) / decay_time); // Decaimiento
                    end else begin
                        envelope_counter <= 8'd0;
                        state <= 4'd3; // Cambiar a sostenimiento
                    end
                end
                4'd3: begin // Sustain
                    if (note_off) state <= 4'd4; // Cambiar a liberación si se desactiva la nota
                    // Mantener el nivel de sostenimiento
                end
                4'd4: begin // Release
                    if (envelope_counter < release_time) begin
                        envelope_counter <= envelope_counter + 1;
                        envelope_level <= sustain_level * (release_time - envelope_counter) / release_time; // Liberación
                    end else begin
                        envelope_counter <= 8'd0;
                        envelope_level <= 8'd0; // Fin de la nota
                        state <= 4'd0; // Volver al estado idle
                    end
                end
                default: state <= 4'd0; // Estado por defecto
            endcase
        end
    end

    // Lógica del generador de onda cuadrada
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            clk_div <= 32'd0;         // Reiniciar el divisor de reloj a 0
            wave_state <= 1'b0;       // Reiniciar el estado de la onda
            wave_out <= 8'd0;         // Reiniciar la salida de la onda
        end else begin
            if (clk_div >= clk_div_threshold) begin
                clk_div <= 32'd0;     // Reiniciar el divisor de reloj
                wave_state <= ~wave_state; // Cambiar el estado de la onda cuadrada
            end else begin
                clk_div <= clk_div + 1; // Incrementar el divisor de reloj
            end

            // Onda cuadrada modulada por el ADSR
            wave_out <= (wave_state) ? (envelope_level * 8'd255 / 8'd255) : 8'd0;
        end
    end

endmodule
