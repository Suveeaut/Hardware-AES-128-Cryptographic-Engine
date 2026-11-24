`timescale 1ns / 1ps

module tb_aes_128_pipe;
    logic         clk = 1'b0;
    logic         rst;
    logic         valid_in;
    logic [127:0] plaintext;
    logic [127:0] cipher_key;
    logic [127:0] ciphertext;
    logic         valid_out;

    always #5ns clk = ~clk; // 100 MHz

    aes_128_pipe dut (
        .clk        (clk),
        .rst        (rst),
        .valid_in   (valid_in),
        .plaintext  (plaintext),
        .cipher_key (cipher_key),
        .ciphertext (ciphertext),
        .valid_out  (valid_out)
    );

    localparam logic [127:0] FIPS_KEY = 128'h2b7e1516_28aed2a6_abf71588_09cf4f3c;
    localparam logic [127:0] FIPS_PT  = 128'h3243f6a8_885a308d_313198a2_e0370734;
    localparam logic [127:0] FIPS_CT  = 128'h3925841d_02dc09fb_dc118597_196a0b32;

    localparam logic [127:0] ZERO_KEY = 128'h00000000_00000000_00000000_00000000;
    localparam logic [127:0] ZERO_PT  = 128'h00000000_00000000_00000000_00000000;
    localparam logic [127:0] ZERO_CT  = 128'h66e94bd4_ef8a2c3b_884cfa59_ca342b2e;

    int err_cnt = 0;

    initial begin
        rst        = 1'b1;
        valid_in   = 1'b0;
        plaintext  = 128'd0;
        cipher_key = 128'd0;

        repeat (3) @(posedge clk);
        rst = 1'b0;
        @(posedge clk);

        // Send Block 1 (NIST FIPS-197) on cycle T0
        @(negedge clk);
        valid_in   = 1'b1;
        cipher_key = FIPS_KEY;
        plaintext  = FIPS_PT;

        // Immediately send Block 2 (All-Zero) on next cycle T1 (back-to-back pipeline test)
        @(negedge clk);
        valid_in   = 1'b1;
        cipher_key = ZERO_KEY;
        plaintext  = ZERO_PT;

        // Deassert valid_in on T2
        @(negedge clk);
        valid_in   = 1'b0;
        cipher_key = 128'd0;
        plaintext  = 128'd0;

        // Wait for Block 1 output
        wait (valid_out === 1'b1);
        @(posedge clk);
        if (ciphertext === FIPS_CT) begin
            $display("[PASS] Pipe Block 1 (FIPS-197) | CT = %032h", ciphertext);
        end else begin
            $error("[FAIL] Pipe Block 1 | Exp = %032h, Got = %032h", FIPS_CT, ciphertext);
            err_cnt++;
        end

        // Block 2 output arrives on the very next clock cycle
        @(posedge clk);
        if (valid_out === 1'b1 && ciphertext === ZERO_CT) begin
            $display("[PASS] Pipe Block 2 (Zero)     | CT = %032h", ciphertext);
        end else begin
            $error("[FAIL] Pipe Block 2 | valid_out=%b Exp = %032h, Got = %032h",
                   valid_out, ZERO_CT, ciphertext);
            err_cnt++;
        end

        repeat (5) @(posedge clk);
        $display("=============================================");
        $display("AES-128 PIPELINED TB SUMMARY : Errors = %0d", err_cnt);
        $display("=============================================");
        $finish;
    end
endmodule
