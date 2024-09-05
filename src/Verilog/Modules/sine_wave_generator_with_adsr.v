/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`define default_netname none

module sine_wave_generator_with_adsr (
    input wire clk,                  // Reloj del sistema
    input wire reset,                // Señal de reinicio
    input wire [5:0] freq_select,    // Selección de frecuencia (6 bits para 64 niveles)
    input wire [7:0] attack_time,    // Tiempo de ataque (simulado por un valor digital)
    input wire [7:0] decay_time,     // Tiempo de decaimiento (simulado por un valor digital)
    input wire [7:0] sustain_level,  // Nivel de sostenimiento (simulado por un valor digital)
    input wire [7:0] release_time,   // Tiempo de liberación (simulado por un valor digital)
    input wire note_on,              // Señal de inicio de nota
    input wire note_off,             // Señal de fin de nota
    output reg [7:0] wave_out        // Salida de onda senoidal de 8 bits
);

    reg [7:0] counter;               // Contador para indexar la tabla
    reg [7:0] sine_table [0:255];    // Tabla de valores senoidales (256 valores de 8 bits)
    reg [31:0] clk_div;              // Contador de divisor de reloj
    reg [31:0] clk_div_threshold;    // Umbral para el divisor de reloj

    // Variables para el ADSR
    reg [7:0] envelope_level;        // Nivel del sobre (ADS)
    reg [7:0] envelope_counter;      // Contador para la envolvente
    reg [3:0] state;                 // Estado del ADSR

    // Inicialización de la tabla de valores senoidales
    initial begin
        sine_table[0] = 8'd128;
        sine_table[1] = 8'd131;
        sine_table[2] = 8'd134;
        // (resto de la tabla sigue igual)
        sine_table[255] = 8'd124;
    end

    // Lógica para seleccionar el umbral del divisor de reloj según la frecuencia deseada
    always @(*) begin
        case (freq_select)
            6'b000000: clk_div_threshold = 32'd1915712;  // C2 (65.41 Hz)
            6'b000001: clk_div_threshold = 32'd1803586;  // C#2 (69.30 Hz)
            // (resto de las frecuencias sigue igual)
            6'b101111: clk_div_threshold = 32'd12717;    // B5 (987.77 Hz)
            default: clk_div_threshold = 32'd28409;      // A4 (440.00 Hz)
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
                        envelope_level <= (envelope_counter * 8'd255) / attack_time; // Aumento del ataque
                    end else begin
                        envelope_counter <= 8'd0;
                        state <= 4'd2; // Cambiar a decaimiento
                    end
                end
                4'd2: begin // Decay
                    if (envelope_counter < decay_time) begin
                        envelope_counter <= envelope_counter + 1;
                        envelope_level <= sustain_level + ((8'd255 - sustain_level) * (decay_time - envelope_counter)) / decay_time; // Decaimiento
                    end else begin
                        envelope_counter <= 8'd0;
                        state <= 4'd3; // Cambiar a sostenimiento
                    end
                end
                4'd3: begin // Sustain
                    if (note_off) state <= 4'd4; // Cambiar a liberación si se desactiva la nota
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
                default: state <= 4'd0;
            endcase
        end
    end

    // Generador de onda senoidal
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            counter <= 8'd0;
            clk_div <= 32'd0;
            wave_out <= 8'd0;
        end else begin
            // Incrementar el divisor de reloj y generar la onda
            if (clk_div >= clk_div_threshold) begin
                clk_div <= 32'd0;
                counter <= counter + 8'd1;
                wave_out <= (sine_table[counter] * envelope_level) / 8'd255; // Onda senoidal modulada por el ADSR
            end else begin
                clk_div <= clk_div + 1;
            end
        end
    end
endmodule
