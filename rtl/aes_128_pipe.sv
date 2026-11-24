`timescale 1ns / 1ps

module aes_128_pipe (
    input  logic         clk,
    input  logic         rst,
    input  logic         valid_in,
    input  logic [127:0] plaintext,
    input  logic [127:0] cipher_key,
    output logic [127:0] ciphertext,
    output logic         valid_out
);
    typedef logic [127:0] rk_bus_t [0:10];

    // Generate all 11 round keys for current input cipher_key
    rk_bus_t rk_cur;
    assign rk_cur[0] = cipher_key;

    genvar g;
    generate
        for (g = 1; g <= 10; g++) begin : gen_round_keys
            logic [3:0] r_idx;
            assign r_idx = g[3:0];
            aes_key_expand_step u_rk_step (
                .key_in    (rk_cur[g-1]),
                .round_idx (r_idx),
                .key_out   (rk_cur[g])
            );
        end
    endgenerate

    // Pipeline registers for state, round-key bus, and valid flags (stages 1..10)
    logic [127:0] state_pipe [1:10];
    rk_bus_t      rk_pipe    [1:10];
    logic         valid_pipe [1:10];

    // Stage 1 combinational path
    logic [127:0] s1_init, s1_sub, s1_shift, s1_mix, s1_next;
    assign s1_init = plaintext ^ rk_cur[0];

    aes_sbox_128 u_sbox_1 (
        .in_state  (s1_init),
        .out_state (s1_sub)
    );
    aes_shift_rows u_shift_1 (
        .in_state  (s1_sub),
        .out_state (s1_shift)
    );
    aes_mix_columns u_mix_1 (
        .in_state  (s1_shift),
        .out_state (s1_mix)
    );
    assign s1_next = s1_mix ^ rk_cur[1];

    // Stages 2..9 combinational datapaths (using each stage's pipelined key bus)
    logic [127:0] mid_sub   [2:9];
    logic [127:0] mid_shift [2:9];
    logic [127:0] mid_mix   [2:9];
    logic [127:0] mid_next  [2:9];

    generate
        for (g = 2; g <= 9; g++) begin : gen_mid_stages
            aes_sbox_128 u_sbox_m (
                .in_state  (state_pipe[g-1]),
                .out_state (mid_sub[g])
            );
            aes_shift_rows u_shift_m (
                .in_state  (mid_sub[g]),
                .out_state (mid_shift[g])
            );
            aes_mix_columns u_mix_m (
                .in_state  (mid_shift[g]),
                .out_state (mid_mix[g])
            );
            assign mid_next[g] = mid_mix[g] ^ rk_pipe[g-1][g];
        end
    endgenerate

    // Stage 10 combinational path (no MixColumns per FIPS-197)
    logic [127:0] s10_sub, s10_shift, s10_next;
    aes_sbox_128 u_sbox_10 (
        .in_state  (state_pipe[9]),
        .out_state (s10_sub)
    );
    aes_shift_rows u_shift_10 (
        .in_state  (s10_sub),
        .out_state (s10_shift)
    );
    assign s10_next = s10_shift ^ rk_pipe[9][10];

    always_ff @(posedge clk) begin
        if (rst) begin
            valid_out  <= 1'b0;
            ciphertext <= 128'd0;
            for (int i = 1; i <= 10; i++) begin
                state_pipe[i] <= 128'd0;
                valid_pipe[i] <= 1'b0;
                for (int k = 0; k <= 10; k++) begin
                    rk_pipe[i][k] <= 128'd0;
                end
            end
        end else begin
            // Stage 1
            valid_pipe[1] <= valid_in;
            if (valid_in) begin
                state_pipe[1] <= s1_next;
                rk_pipe[1]    <= rk_cur;
            end

            // Stages 2..9
            for (int i = 2; i <= 9; i++) begin
                valid_pipe[i] <= valid_pipe[i-1];
                if (valid_pipe[i-1]) begin
                    state_pipe[i] <= mid_next[i];
                    rk_pipe[i]    <= rk_pipe[i-1];
                end
            end

            // Stage 10 -> Output
            valid_out <= valid_pipe[9];
            if (valid_pipe[9]) begin
                ciphertext <= s10_next;
            end
        end
    end

endmodule