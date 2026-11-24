`timescale 1ns / 1ps

module aes_key_expand_step (
    input  logic [127:0] key_in,
    input  logic [3:0]   round_idx, // 1 .. 10
    output logic [127:0] key_out
);
    logic [31:0] w0, w1, w2, w3;
    logic [31:0] rot_w;
    logic [31:0] sub_w;
    logic [7:0]  rcon_byte;
    logic [31:0] rcon_word;
    logic [31:0] temp;
    logic [31:0] nw0, nw1, nw2, nw3;

    always_comb begin
        case (round_idx)
            4'd1:    rcon_byte = 8'h01;
            4'd2:    rcon_byte = 8'h02;
            4'd3:    rcon_byte = 8'h04;
            4'd4:    rcon_byte = 8'h08;
            4'd5:    rcon_byte = 8'h10;
            4'd6:    rcon_byte = 8'h20;
            4'd7:    rcon_byte = 8'h40;
            4'd8:    rcon_byte = 8'h80;
            4'd9:    rcon_byte = 8'h1b;
            4'd10:   rcon_byte = 8'h36;
            default: rcon_byte = 8'h00;
        endcase
    end

    // FIPS-197 word order: w0 is MSB [127:96], w3 is LSB [31:0]
    assign {w0, w1, w2, w3} = key_in;

    // RotWord on w3 (last word of previous round key)
    assign rot_w = {w3[23:0], w3[31:24]};

    // SubWord using 4 byte S-Boxes
    genvar i;
    generate
        for (i = 0; i < 4; i++) begin : gen_key_sbox
            aes_sbox_byte u_ksbox (
                .in_b  (rot_w[8*i +: 8]),
                .out_b (sub_w[8*i +: 8])
            );
        end
    endgenerate

    assign rcon_word = {rcon_byte, 24'h000000};
    assign temp      = sub_w ^ rcon_word;

    assign nw0 = w0 ^ temp;
    assign nw1 = w1 ^ nw0;
    assign nw2 = w2 ^ nw1;
    assign nw3 = w3 ^ nw2;

    assign key_out = {nw0, nw1, nw2, nw3};
endmodule
