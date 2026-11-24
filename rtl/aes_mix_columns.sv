`timescale 1ns / 1ps

module aes_mix_columns (
    input  logic [127:0] in_state,
    output logic [127:0] out_state
);
    function automatic logic [7:0] gf_mul2(input logic [7:0] x);
        gf_mul2 = x[7] ? ((x << 1) ^ 8'h1b) : (x << 1);
    endfunction

    function automatic logic [7:0] gf_mul3(input logic [7:0] x);
        gf_mul3 = gf_mul2(x) ^ x;
    endfunction

    always_comb begin
        logic [7:0] s0, s1, s2, s3;
        logic [7:0] m0, m1, m2, m3;

        for (int c = 0; c < 4; c++) begin
            s0 = in_state[127 - 8*(4*c + 0) -: 8];
            s1 = in_state[127 - 8*(4*c + 1) -: 8];
            s2 = in_state[127 - 8*(4*c + 2) -: 8];
            s3 = in_state[127 - 8*(4*c + 3) -: 8];

            m0 = gf_mul2(s0) ^ gf_mul3(s1) ^ s2           ^ s3;
            m1 = s0           ^ gf_mul2(s1) ^ gf_mul3(s2) ^ s3;
            m2 = s0           ^ s1           ^ gf_mul2(s2) ^ gf_mul3(s3);
            m3 = gf_mul3(s0) ^ s1           ^ s2           ^ gf_mul2(s3);

            out_state[127 - 8*(4*c + 0) -: 8] = m0;
            out_state[127 - 8*(4*c + 1) -: 8] = m1;
            out_state[127 - 8*(4*c + 2) -: 8] = m2;
            out_state[127 - 8*(4*c + 3) -: 8] = m3;
        end
    end
endmodule
