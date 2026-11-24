`timescale 1ns / 1ps

module aes_shift_rows (
    input  logic [127:0] in_state,
    output logic [127:0] out_state
);
    logic [7:0] s_in  [0:3][0:3]; // [row][col]
    logic [7:0] s_out [0:3][0:3];

    always_comb begin
        // Byte 0 is at bits [127:120] (MSB), Byte 15 at [7:0] (LSB)
        // Column-major in FIPS-197: byte_idx = 4*c + r
        for (int c = 0; c < 4; c++) begin
            for (int r = 0; r < 4; r++) begin
                int b_idx = 4*c + r;
                s_in[r][c] = in_state[127 - 8*b_idx -: 8];
            end
        end

        for (int r = 0; r < 4; r++) begin
            for (int c = 0; c < 4; c++) begin
                s_out[r][c] = s_in[r][(c + r) % 4];
            end
        end

        for (int c = 0; c < 4; c++) begin
            for (int r = 0; r < 4; r++) begin
                int b_idx = 4*c + r;
                out_state[127 - 8*b_idx -: 8] = s_out[r][c];
            end
        end
    end
endmodule
