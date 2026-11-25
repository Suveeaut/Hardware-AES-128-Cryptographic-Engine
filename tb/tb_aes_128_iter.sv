`timescale 1ns / 1ps

module tb_aes_128_iter;
    logic         clk = 1'b0;
    logic         rst;
    logic         start;
    logic [127:0] plaintext;
    logic [127:0] cipher_key;
    logic [127:0] ciphertext;
    logic         busy;
    logic         done;

    always #5ns clk = ~clk; // 100 MHz

    aes_128_iter dut (
        .clk        (clk),
        .rst        (rst),
        .start      (start),
        .plaintext  (plaintext),
        .cipher_key (cipher_key),
        .ciphertext (ciphertext),
        .busy       (busy),
        .done       (done)
    );

    // NIST FIPS-197 Appendix A.1 test vector
    localparam logic [127:0] FIPS_KEY = 128'h2b7e1516_28aed2a6_abf71588_09cf4f3c;
    localparam logic [127:0] FIPS_PT  = 128'h3243f6a8_885a308d_313198a2_e0370734;
    localparam logic [127:0] FIPS_CT  = 128'h3925841d_02dc09fb_dc118597_196a0b32;

    int err_cnt = 0;

    task automatic run_vector(
        input logic [127:0] k_in,
        input logic [127:0] pt_in,
        input logic [127:0] exp_ct,
        input string        label
    );
        @(negedge clk);
        cipher_key = k_in;
        plaintext  = pt_in;
        start      = 1'b1;

        @(negedge clk);
        start      = 1'b0;

        wait (done === 1'b1);
        @(posedge clk);

        if (ciphertext === exp_ct) begin
            $display("[PASS] %s | CT = %032h", label, ciphertext);
        end else begin
            $error("[FAIL] %s | Expected = %032h, Got = %032h", label, exp_ct, ciphertext);
            err_cnt++;
        end

        repeat (2) @(posedge clk);
    endtask

    initial begin
        rst        = 1'b1;
        start      = 1'b0;
        plaintext  = 128'd0;
        cipher_key = 128'd0;

        repeat (3) @(posedge clk);
        rst = 1'b0;
        repeat (2) @(posedge clk);

        // Vector 1: Official NIST FIPS-197 Appendix A.1
        run_vector(FIPS_KEY, FIPS_PT, FIPS_CT, "NIST FIPS-197 App. A.1");

        // Vector 2: All-zero key & plaintext sanity check
        run_vector(
            128'h00000000_00000000_00000000_00000000,
            128'h00000000_00000000_00000000_00000000,
            128'h66e94bd4_ef8a2c3b_884cfa59_ca342b2e,
            "All-Zero Key/PT"
        );

        $display("=============================================");
        $display("AES-128 ITERATIVE TB SUMMARY : Errors = %0d", err_cnt);
        $display("=============================================");
        $finish;
    end
endmodule
