`timescale 1ns / 1ps

module aes_128_iter (
    input  logic         clk,
    input  logic         rst,
    input  logic         start,
    input  logic [127:0] plaintext,
    input  logic [127:0] cipher_key,
    output logic [127:0] ciphertext,
    output logic         busy,
    output logic         done
);
    typedef enum logic [1:0] {
        IDLE = 2'd0,
        RUN  = 2'd1,
        FINISH = 2'd2
    } state_t;

    state_t       fsm_state;
    logic [3:0]   round_cnt;   // 1 .. 10
    logic [127:0] state_reg;
    logic [127:0] key_reg;

    // Combinational round datapath
    logic [127:0] sub_out;
    logic [127:0] shift_out;
    logic [127:0] mix_out;
    logic [127:0] round_data_in;
    logic [127:0] next_key;

    aes_sbox_128 u_sub_bytes (
        .in_state  (state_reg),
        .out_state (sub_out)
    );

    aes_shift_rows u_shift_rows (
        .in_state  (sub_out),
        .out_state (shift_out)
    );

    aes_mix_columns u_mix_columns (
        .in_state  (shift_out),
        .out_state (mix_out)
    );

    aes_key_expand_step u_key_exp (
        .key_in    (key_reg),
        .round_idx (round_cnt),
        .key_out   (next_key)
    );

    // Round 1..9 uses MixColumns; Round 10 skips MixColumns per FIPS-197
    assign round_data_in = (round_cnt == 4'd10) ? shift_out : mix_out;

    assign busy = (fsm_state == RUN);

    always_ff @(posedge clk) begin
        if (rst) begin
            fsm_state  <= IDLE;
            round_cnt  <= 4'd0;
            state_reg  <= 128'd0;
            key_reg    <= 128'd0;
            ciphertext <= 128'd0;
            done       <= 1'b0;
        end else begin
            done <= 1'b0;

            case (fsm_state)
                IDLE: begin
                    if (start) begin
                        // Initial AddRoundKey (Round 0)
                        state_reg <= plaintext ^ cipher_key;
                        key_reg   <= cipher_key;
                        round_cnt <= 4'd1;
                        fsm_state <= RUN;
                    end
                end

                RUN: begin
                    if (round_cnt < 4'd10) begin
                        state_reg <= round_data_in ^ next_key;
                        key_reg   <= next_key;
                        round_cnt <= round_cnt + 4'd1;
                    end else begin
                        // Final round (round_cnt == 10)
                        ciphertext <= round_data_in ^ next_key;
                        key_reg    <= next_key;
                        round_cnt  <= 4'd0;
                        fsm_state  <= FINISH;
                        done       <= 1'b1;
                    end
                end

                FINISH: begin
                    fsm_state <= IDLE;
                end

                default: begin
                    fsm_state <= IDLE;
                end
            endcase
        end
    end

endmodule
