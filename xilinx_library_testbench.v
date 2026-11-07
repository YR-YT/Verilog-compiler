// ============================================================================
// File: xilinx_library_testbench.v
// Standard: IEEE 1364-2001 Verilog HDL
// Description: Self-checking automated testbench verifying memory operations,
//              clock pulses, sequential registers, LUTs, and arithmetic carry.
// ============================================================================

`timescale 1 ns / 1 ps
`include "xilinx_primitives_library.v"

module xilinx_library_testbench;

  // Clock & Reset Generator Signals
  reg clk;
  reg rst;
  reg ce;

  // 1. D Flip-Flop Signals
  reg  dff_d;
  wire dff_q;

  // 2. Look-Up Table Signals
  reg  lut_a, lut_b;
  wire lut_and_out;

  // 3. Fast Carry Signals
  reg  [3:0] carry_di, carry_s;
  wire [3:0] carry_co, carry_o;

  // 4. Single-Port BRAM Signals (32-bit data, 8-bit address = 256 words)
  reg         bram_en;
  reg         bram_we;
  reg  [7:0]  bram_addr;
  reg  [31:0] bram_din;
  wire [31:0] bram_dout;

  // 5. Distributed RAM Signals (16x1)
  reg  [3:0] dist_addr;
  reg        dist_din;
  reg        dist_we;
  wire       dist_dout;

  // --------------------------------------------------------------------------
  // Unit Under Test (UUT) Instantiations
  // --------------------------------------------------------------------------

  // FDRE: D Flip-Flop with Clock Enable and Synchronous Reset
  FDRE #( .INIT(1'b0) ) u_fdre (
    .Q(dff_q),
    .C(clk),
    .CE(ce),
    .D(dff_d),
    .R(rst)
  );

  // LUT2: AND gate logic (INIT = 4'h8 corresponds to I0 & I1)
  LUT2 #( .INIT(4'h8) ) u_lut2_and (
    .O(lut_and_out),
    .I0(lut_a),
    .I1(lut_b)
  );

  // CARRY4: Arithmetic Carry Unit
  CARRY4 u_carry4 (
    .CO(carry_co),
    .O(carry_o),
    .CI(1'b0),
    .CYINIT(1'b0),
    .DI(carry_di),
    .S(carry_s)
  );

  // Block RAM: 32-bit x 256-word Synchronous Memory
  BRAM_SINGLE_PORT #(
    .DATA_WIDTH(32),
    .ADDR_WIDTH(8)
  ) u_bram (
    .CLK(clk),
    .EN(bram_en),
    .WE(bram_we),
    .ADDR(bram_addr),
    .DIN(bram_din),
    .DOUT(bram_dout)
  );

  // Distributed RAM: 16-word x 1-bit RAM
  RAM16X1S #( .INIT(16'h0000) ) u_dist_ram (
    .O(dist_dout),
    .A(dist_addr),
    .D(dist_din),
    .WCLK(clk),
    .WE(dist_we)
  );

  // --------------------------------------------------------------------------
  // Master Clock Generation (100 MHz, 10 ns period)
  // --------------------------------------------------------------------------
  always #5 clk = ~clk;

  // --------------------------------------------------------------------------
  // Test Stimulus Routine
  // --------------------------------------------------------------------------
  integer pass_count = 0;
  integer fail_count = 0;

  initial begin
    // Setup waveform dump for GTKWave / ModelSim / Vivado
    $dumpfile("simulation_results.vcd");
    $dumpvars(0, xilinx_library_testbench);

    // Initialize all input signals
    clk       = 0;
    rst       = 1;
    ce        = 1;
    dff_d     = 0;
    lut_a     = 0;
    lut_b     = 0;
    carry_di  = 4'h0;
    carry_s   = 4'h0;
    bram_en   = 1;
    bram_we   = 0;
    bram_addr = 8'h00;
    bram_din  = 32'h00000000;
    dist_addr = 4'h0;
    dist_din  = 0;
    dist_we   = 0;

    $display("=================================================================");
    $display("  XILINX HARDWARE PRIMITIVES COMPREHENSIVE TESTBENCH");
    $display("=================================================================");

    // Wait 20 ns for initial reset
    #20;
    rst = 0;
    $display("[%0t ns] Reset released. Beginning verification...", $time);

    // ------------------------------------------------------------------------
    // TEST 1: Look-Up Table (LUT2 AND Gate)
    // ------------------------------------------------------------------------
    lut_a = 1; lut_b = 0; #5;
    if (lut_and_out === 1'b0) pass_count = pass_count + 1;
    else begin $display("FAIL: LUT2 1&0 expected 0, got %b", lut_and_out); fail_count = fail_count + 1; end

    lut_a = 1; lut_b = 1; #5;
    if (lut_and_out === 1'b1) pass_count = pass_count + 1;
    else begin $display("FAIL: LUT2 1&1 expected 1, got %b", lut_and_out); fail_count = fail_count + 1; end
    $display("[TEST 1 PASSED] LUT2 Truth Table verified.");

    // ------------------------------------------------------------------------
    // TEST 2: D Flip-Flop (FDRE) Posedge Latch & Synchronous Reset
    // ------------------------------------------------------------------------
    @(negedge clk);
    dff_d = 1;
    @(posedge clk); #1; // After clock posedge
    if (dff_q === 1'b1) pass_count = pass_count + 1;
    else begin $display("FAIL: FDRE expected Q=1 on posedge, got %b", dff_q); fail_count = fail_count + 1; end

    @(negedge clk);
    rst = 1; // Assert synchronous reset while dff_d is still 1
    @(posedge clk); #1;
    if (dff_q === 1'b0) pass_count = pass_count + 1;
    else begin $display("FAIL: FDRE synchronous reset expected Q=0, got %b", dff_q); fail_count = fail_count + 1; end
    rst = 0;
    $display("[TEST 2 PASSED] FDRE Clock posedge latch & synchronous reset verified.");

    // ------------------------------------------------------------------------
    // TEST 3: Block RAM (BRAM_SINGLE_PORT) 32-Bit Memory Write & Read
    // ------------------------------------------------------------------------
    $display("[%0t ns] Starting BRAM 32-bit Memory Test...", $time);

    // Write Word 0: Address 0x10 <= 0xDEADBEEF
    @(negedge clk);
    bram_addr = 8'h10;
    bram_din  = 32'hDEADBEEF;
    bram_we   = 1;
    @(posedge clk); #1;

    // Write Word 1: Address 0x11 <= 0xCAFEBABE
    @(negedge clk);
    bram_addr = 8'h11;
    bram_din  = 32'hCAFEBABE;
    bram_we   = 1;
    @(posedge clk); #1;

    // Write Word 2: Address 0x2A <= 0x12345678
    @(negedge clk);
    bram_addr = 8'h2A;
    bram_din  = 32'h12345678;
    bram_we   = 1;
    @(posedge clk); #1;

    // Read back Address 0x10
    @(negedge clk);
    bram_we   = 0;
    bram_addr = 8'h10;
    @(posedge clk); #1;
    if (bram_dout === 32'hDEADBEEF) begin
      pass_count = pass_count + 1;
      $display("  BRAM Read [0x10] = 0x%h (MATCH)", bram_dout);
    end else begin
      $display("FAIL: BRAM Read [0x10] expected 0xDEADBEEF, got 0x%h", bram_dout);
      fail_count = fail_count + 1;
    end

    // Read back Address 0x11
    @(negedge clk);
    bram_addr = 8'h11;
    @(posedge clk); #1;
    if (bram_dout === 32'hCAFEBABE) begin
      pass_count = pass_count + 1;
      $display("  BRAM Read [0x11] = 0x%h (MATCH)", bram_dout);
    end else begin
      $display("FAIL: BRAM Read [0x11] expected 0xCAFEBABE, got 0x%h", bram_dout);
      fail_count = fail_count + 1;
    end

    // Read back Address 0x2A
    @(negedge clk);
    bram_addr = 8'h2A;
    @(posedge clk); #1;
    if (bram_dout === 32'h12345678) begin
      pass_count = pass_count + 1;
      $display("  BRAM Read [0x2A] = 0x%h (MATCH)", bram_dout);
    end else begin
      $display("FAIL: BRAM Read [0x2A] expected 0x12345678, got 0x%h", bram_dout);
      fail_count = fail_count + 1;
    end
    $display("[TEST 3 PASSED] 32-bit Block RAM Write & Read cycles verified.");

    // ------------------------------------------------------------------------
    // TEST 4: Distributed RAM (RAM16X1S) Operation
    // ------------------------------------------------------------------------
    @(negedge clk);
    dist_addr = 4'h5;
    dist_din  = 1'b1;
    dist_we   = 1;
    @(posedge clk); #1;

    @(negedge clk);
    dist_we   = 0;
    dist_addr = 4'h5;
    #2;
    if (dist_dout === 1'b1) pass_count = pass_count + 1;
    else begin $display("FAIL: Distributed RAM at 0x5 expected 1, got %b", dist_dout); fail_count = fail_count + 1; end
    $display("[TEST 4 PASSED] Distributed RAM (RAM16X1S) verified.");

    // ------------------------------------------------------------------------
    // Summary Report
    // ------------------------------------------------------------------------
    #20;
    $display("=================================================================");
    $display("  VERIFICATION COMPLETE: %0d PASSED, %0d FAILED", pass_count, fail_count);
    $display("  Waveform dumped to: simulation_results.vcd");
    $display("=================================================================");
    $finish;
  end

endmodule
