// ECE M216A Lab 1C, AI Prompt #3: Critical-path-directed prefix experiment.
// Revisions relative to the previous 4-bit-block carry-select design:
// (1) Explicit 4-bit group generate/propagate instead of taking the carry
//     out of a behavioral 4-bit sum.
// (2) Selectable Sklansky or Kogge-Stone group prefix topology.
// (3) Optional conditional-increment sum in place of sum0/sum1 mux.
// Three top-level modules are provided at the bottom of this file.
// Verilog-2001, combinational and synthesizable.

module ai3_prefix_core_64 #(
    parameter integer USE_SKLANSKY = 1,
    parameter integer USE_COND_INCREMENT = 0
) (
    input  wire [63:0] a,
    input  wire [63:0] b,
    input  wire        cin,
    output wire [63:0] sum,
    output wire        cout
);
    localparam integer BLOCK_BITS = 4;
    localparam integer N_BLOCKS   = 16;
    localparam integer N_LEVELS   = 4;

    wire [N_BLOCKS-1:0] block_p;
    wire [N_BLOCKS-1:0] block_g;
    wire [N_BLOCKS-1:0] P [0:N_LEVELS];
    wire [N_BLOCKS-1:0] G [0:N_LEVELS];
    wire [N_BLOCKS:0] block_c;

    assign P[0] = block_p;
    assign G[0] = block_g;
    assign block_c[0] = cin;
    assign cout = block_c[N_BLOCKS];

    genvar k, s, i;
    generate
        // Form each 4-bit block's carry information directly from Boolean logic.
        for (k = 0; k < N_BLOCKS; k = k + 1) begin : BLK
            wire [3:0] ax, bx;
            wire [3:0] bp, bg;
            wire [4:0] tmp0;
            wire [3:0] sum0, sum1;

            assign ax = a[4*k +: 4];
            assign bx = b[4*k +: 4];
            assign bp = ax ^ bx;
            assign bg = ax & bx;

            assign block_p[k] = bp[3] & bp[2] & bp[1] & bp[0];
            assign block_g[k] = bg[3]
                  | (bp[3] & bg[2])
                  | (bp[3] & bp[2] & bg[1])
                  | (bp[3] & bp[2] & bp[1] & bg[0]);

            // Precompute the block sum before its incoming carry is known.
            assign tmp0 = {1'b0, ax} + {1'b0, bx};
            assign sum0 = tmp0[3:0];

            if (USE_COND_INCREMENT == 0) begin : SUM_MUX
                // Conventional carry-select sum: choose between sum0 and sum0+1.
                assign sum1 = sum0 + 4'b0001;
                assign sum[4*k +: 4] = block_c[k] ? sum1 : sum0;
            end else begin : SUM_CINC
                // Compute sum0+cin by conditionally toggling its trailing 1s.
                // Bit j flips only if cin=1 and every lower sum0 bit is 1.
                wire [3:0] inc_mask;
                assign inc_mask[0] = 1'b1;
                assign inc_mask[1] = sum0[0];
                assign inc_mask[2] = sum0[1] & sum0[0];
                assign inc_mask[3] = sum0[2] & sum0[1] & sum0[0];
                assign sum[4*k +: 4] = sum0 ^
                                         (inc_mask & {4{block_c[k]}});
            end
        end

        // Prefix calculation on 16 blocks, four levels.
        // Topology is selected at elaboration time, not at runtime.
        for (s = 0; s < N_LEVELS; s = s + 1) begin : LEVEL
            localparam integer DIST = (1 << s);
            localparam integer SPAN = (2 << s);

            for (i = 0; i < N_BLOCKS; i = i + 1) begin : NODE
                if (USE_SKLANSKY != 0) begin : SKLANSKY
                    // Upper half of each span takes the prefix of its lower half.
                    localparam integer PARTNER = (i / SPAN) * SPAN + DIST - 1;
                    if ((i % SPAN) >= DIST) begin : COMBINE
                        assign G[s+1][i] = G[s][i] |
                                (P[s][i] & G[s][PARTNER]);
                        assign P[s+1][i] = P[s][i] & P[s][PARTNER];
                    end else begin : PASS
                        assign G[s+1][i] = G[s][i];
                        assign P[s+1][i] = P[s][i];
                    end
                end else begin : KOGGE_STONE
                    // The original sliding-distance prefix topology.
                    if (i >= DIST) begin : COMBINE
                        assign G[s+1][i] = G[s][i] |
                                (P[s][i] & G[s][i-DIST]);
                        assign P[s+1][i] = P[s][i] & P[s][i-DIST];
                    end else begin : PASS
                        assign G[s+1][i] = G[s][i];
                        assign P[s+1][i] = P[s][i];
                    end
                end
            end
        end

        // Carry into each group is computed in parallel from its prefix pair.
        for (k = 0; k < N_BLOCKS; k = k + 1) begin : CARRY
            assign block_c[k+1] = G[N_LEVELS][k] |
                                  (P[N_LEVELS][k] & cin);
        end
    endgenerate
endmodule

// Variant A: changed prefix topology; standard carry-select output.
module ai3_sklansky_cselect_64 (
    input wire [63:0] a, b, input wire cin,
    output wire [63:0] sum, output wire cout
);
    ai3_prefix_core_64 #(.USE_SKLANSKY(1), .USE_COND_INCREMENT(0)) u_core
        (.a(a), .b(b), .cin(cin), .sum(sum), .cout(cout));
endmodule

// Variant B: same Boolean block logic, original Kogge-Stone topology.
// Use as a controlled comparison against Variant A.
module ai3_kogge_cselect_64 (
    input wire [63:0] a, b, input wire cin,
    output wire [63:0] sum, output wire cout
);
    ai3_prefix_core_64 #(.USE_SKLANSKY(0), .USE_COND_INCREMENT(0)) u_core
        (.a(a), .b(b), .cin(cin), .sum(sum), .cout(cout));
endmodule

// Variant C: Sklansky topology with a conditional-increment output.
module ai3_sklansky_cinc_64 (
    input wire [63:0] a, b, input wire cin,
    output wire [63:0] sum, output wire cout
);
    ai3_prefix_core_64 #(.USE_SKLANSKY(1), .USE_COND_INCREMENT(1)) u_core
        (.a(a), .b(b), .cin(cin), .sum(sum), .cout(cout));
endmodule
