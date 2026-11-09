// UCLA ECE M216A, Lab 1C: 8-bit AI-assisted adder, prompt 3.
// Pure synthesizable Verilog-2001. No clock, latch, or SystemVerilog features.
// All tops: a[7:0], b[7:0], cin -> sum[7:0], cout.
// IMPORTANT: RTL Boolean syntax does NOT force Genus to retain a NAND/AOI cell.
// Use identical original synthesis settings when comparing these RTL designs.

// Candidate A: shared XOR propagate, carry factored into NAND-like terms.
module lp8_ai3_nand_pg (
    input  wire [7:0] a,
    input  wire [7:0] b,
    input  wire       cin,
    output wire [7:0] sum,
    output wire       cout
);
    wire [7:0] p;
    wire [7:0] ng;
    wire [7:0] nt;
    wire [8:0] c;
    genvar i;

    assign p    = a ^ b;
    assign ng   = ~(a & b);  // inverse of generate (Gbar)
    assign c[0] = cin;
    assign sum  = p ^ c[7:0];
    assign cout = c[8];

    generate
        for (i = 0; i < 8; i = i + 1) begin : NAND_CARRY
            assign nt[i]  = ~(p[i] & c[i]);
            assign c[i+1] = ~(ng[i] & nt[i]);
        end
    endgenerate
endmodule

// Candidate B: alternate positive/negative carry polarity, expose AOI/OAI forms.
// Uses XOR for sum, OR-propagate for carry. At even i, cc[i] is TRUE carry;
// at odd i, cc[i] is INVERTED carry. No two copies of a carry chain.
module lp8_ai3_aoi_oai (
    input  wire [7:0] a,
    input  wire [7:0] b,
    input  wire       cin,
    output wire [7:0] sum,
    output wire       cout
);
    wire [7:0] px, po, g, ng, npo;
    wire [8:0] cc;
    genvar i;

    assign px = a ^ b;
    assign po = a | b;
    assign g = a & b;
    assign ng = ~g;
    assign npo = ~po;
    assign cc[0] = cin;

    generate
        for (i = 0; i < 8; i = i + 1) begin : AOI_OAI_CARRY
            if ((i % 2) == 0) begin : AOI_PHASE
                // Negative carry from true carry, AOI-like form.
                assign cc[i+1] = ~(g[i] | (po[i] & cc[i]));
                assign sum[i] = px[i] ^ cc[i];
            end else begin : OAI_PHASE
                // True carry from negative carry, OAI-like form.
                assign cc[i+1] = ~(ng[i] & (npo[i] | cc[i]));
                assign sum[i] = px[i] ~^ cc[i];
            end
        end
    endgenerate

    assign cout = cc[8];
endmodule

// Candidate C: two-bit group carry, complement-factored group propagation.
// Adjacent local sums share bit-level P/G.  Group carry uses a complemented
// formulation to explore an OAI-like technology mapping at group boundaries.
module lp8_ai3_pair_nor (
    input  wire [7:0] a,
    input  wire [7:0] b,
    input  wire       cin,
    output wire [7:0] sum,
    output wire       cout
);
    wire [7:0] p, g;
    wire [8:0] c;
    wire [3:0] npair_g, npair_p;
    genvar j;

    assign p = a ^ b;
    assign g = a & b;
    assign c[0] = cin;

    generate
        for (j = 0; j < 4; j = j + 1) begin : PAIR
            assign npair_g[j] = ~(g[2*j+1] | (p[2*j+1] & g[2*j]));
            assign npair_p[j] = ~(p[2*j+1] & p[2*j]);
            assign c[2*j+1] = g[2*j] | (p[2*j] & c[2*j]);
            assign c[2*j+2] = ~(npair_g[j] & (npair_p[j] | ~c[2*j]));
        end
    endgenerate

    assign sum = p ^ c[7:0];
    assign cout = c[8];
endmodule
