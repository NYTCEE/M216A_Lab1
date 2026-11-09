// ECE M216A Lab 1C: 8-bit adder, second AI-assisted iteration.
// Pure Verilog-2001; no SystemVerilog features required.
// All three top modules implement {cout, sum} = a + b + cin.
// Synthesize one top module at a time using IDENTICAL Genus constraints.

// Candidate A: 2-bit group generate/propagate (four 2-bit groups).
// The second carry in each group is expanded, rather than rippled through
// two separate single-bit carry equations.
module lp8_ai2_pair_pg (
    input  wire [7:0] a,
    input  wire [7:0] b,
    input  wire       cin,
    output wire [7:0] sum,
    output wire       cout
);
    wire [7:0] p, g;
    wire [8:0] c;
    genvar j;

    assign p = a ^ b;
    assign g = a & b;
    assign c[0] = cin;

    generate
        for (j = 0; j < 4; j = j + 1) begin : PAIR
            assign c[2*j+1] = g[2*j] | (p[2*j] & c[2*j]);
            assign c[2*j+2] = g[2*j+1]
                              | (p[2*j+1] & g[2*j])
                              | (p[2*j+1] & p[2*j] & c[2*j]);
        end
    endgenerate

    assign sum  = p ^ c[7:0];
    assign cout = c[8];
endmodule


// Candidate B: two independent 4-bit carry-lookahead blocks.
// Bit-level P/G is shared by the local sum and block carry logic.
module lp8_ai2_block4_pg (
    input  wire [7:0] a,
    input  wire [7:0] b,
    input  wire       cin,
    output wire [7:0] sum,
    output wire       cout
);
    wire [7:0] p, g;
    wire [8:0] c;
    wire [1:0] block_p, block_g;
    genvar j;

    assign p = a ^ b;
    assign g = a & b;
    assign c[0] = cin;

    generate
        for (j = 0; j < 2; j = j + 1) begin : BLOCK4
            assign block_p[j] = p[4*j+3] & p[4*j+2]
                              & p[4*j+1] & p[4*j];
            assign block_g[j] = g[4*j+3]
                              | (p[4*j+3] & g[4*j+2])
                              | (p[4*j+3] & p[4*j+2] & g[4*j+1])
                              | (p[4*j+3] & p[4*j+2]
                                 & p[4*j+1] & g[4*j]);

            assign c[4*j+1] = g[4*j] | (p[4*j] & c[4*j]);
            assign c[4*j+2] = g[4*j+1]
                              | (p[4*j+1] & g[4*j])
                              | (p[4*j+1] & p[4*j] & c[4*j]);
            assign c[4*j+3] = g[4*j+2]
                              | (p[4*j+2] & g[4*j+1])
                              | (p[4*j+2] & p[4*j+1] & g[4*j])
                              | (p[4*j+2] & p[4*j+1]
                                 & p[4*j] & c[4*j]);
            assign c[4*j+4] = block_g[j] | (block_p[j] & c[4*j]);
        end
    endgenerate

    assign sum  = p ^ c[7:0];
    assign cout = c[8];
endmodule


// Candidate C: shared P/G with alternating inverted carry representation.
// This exposes complementary carry logic and may map into AOI/OAI cells.
// For even bit positions the stored carry is true; for odd positions it is
// inverted.  sum uses XOR or XNOR accordingly.
module lp8_ai2_altpol_pg (
    input  wire [7:0] a,
    input  wire [7:0] b,
    input  wire       cin,
    output wire [7:0] sum,
    output wire       cout
);
    wire [7:0] p, g;
    wire [8:0] cc;       // cc[even]: true carry; cc[odd]: inverted carry
    genvar j;

    assign p = a ^ b;
    assign g = a & b;
    assign cc[0] = cin;

    generate
        for (j = 0; j < 8; j = j + 1) begin : ALTERNATE
            if ((j % 2) == 0) begin : TRUE_TO_INVERTED
                assign cc[j+1] = ~(g[j] | (p[j] & cc[j]));
                assign sum[j]  = p[j] ^ cc[j];
            end else begin : INVERTED_TO_TRUE
                assign cc[j+1] = g[j] | (p[j] & ~cc[j]);
                assign sum[j]  = p[j] ~^ cc[j];
            end
        end
    endgenerate

    assign cout = cc[8];
endmodule
