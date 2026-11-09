// ECE M216A Lab 1C - candidate 2: 64-bit parallel-prefix / carry-select adder
// Three comparable 64-bit tops: prefix_cselect_64_b4, _b8 and _b16.
// Synthesizable Verilog-2001, purely combinational; no latches or clocks.
// All implementations have identical external ports.

module prefix_cselect_core_64 #(
    parameter integer BLOCK_BITS = 4,
    parameter integer LEVELS = 4
) (
    input  wire [63:0] a,
    input  wire [63:0] b,
    input  wire        cin,
    output wire [63:0] sum,
    output wire        cout
);
    localparam integer NB = 64 / BLOCK_BITS;

    wire [NB-1:0] block_p, block_g;
    wire [NB-1:0] P [0:LEVELS];
    wire [NB-1:0] G [0:LEVELS];
    wire [NB:0]   block_c;

    assign P[0] = block_p;
    assign G[0] = block_g;
    assign block_c[0] = cin;
    assign cout = block_c[NB];

    genvar k, s, i;
    generate
        // For each block, calculate the two possible sums in parallel.
        for (k = 0; k < NB; k = k + 1) begin : BLOCK
            wire [BLOCK_BITS-1:0] ax, bx;
            wire [BLOCK_BITS:0]   tmp0;
            wire [BLOCK_BITS-1:0] sum1;

            assign ax = a[k*BLOCK_BITS +: BLOCK_BITS];
            assign bx = b[k*BLOCK_BITS +: BLOCK_BITS];

            // The carry-out from ax+bx with carry-in zero = block generate.
            assign tmp0 = {1'b0, ax} + {1'b0, bx};
            // When block carry-in is one, this is the alternate low sum.
            assign sum1 = tmp0[BLOCK_BITS-1:0] + 1'b1;

            // A block propagates incoming carry iff every bit propagates.
            assign block_p[k] = &(ax ^ bx);
            assign block_g[k] = tmp0[BLOCK_BITS];

            // Only a mux lies between the selected carry and block sum.
            assign sum[k*BLOCK_BITS +: BLOCK_BITS] =
                block_c[k] ? sum1 : tmp0[BLOCK_BITS-1:0];
        end

        // Parallel-prefix carries across the blocks.
        for (s = 0; s < LEVELS; s = s + 1) begin : PREFIX_STAGE
            for (i = 0; i < NB; i = i + 1) begin : PREFIX_NODE
                if (i >= (1 << s)) begin : COMBINE
                    assign G[s+1][i] = G[s][i]
                                      | (P[s][i] & G[s][i-(1 << s)]);
                    assign P[s+1][i] = P[s][i] & P[s][i-(1 << s)];
                end else begin : PASS
                    assign G[s+1][i] = G[s][i];
                    assign P[s+1][i] = P[s][i];
                end
            end
        end

        for (k = 0; k < NB; k = k + 1) begin : CARRY
            assign block_c[k+1] = G[LEVELS][k]
                                  | (P[LEVELS][k] & cin);
        end
    endgenerate
endmodule

// 16 groups x 4 bits; 4 prefix levels.
module prefix_cselect_64_b4 (
    input wire [63:0] a, b, input wire cin,
    output wire [63:0] sum, output wire cout
);
    prefix_cselect_core_64 #(.BLOCK_BITS(4), .LEVELS(4)) u_core
        (.a(a), .b(b), .cin(cin), .sum(sum), .cout(cout));
endmodule

// 8 groups x 8 bits; 3 prefix levels.
module prefix_cselect_64_b8 (
    input wire [63:0] a, b, input wire cin,
    output wire [63:0] sum, output wire cout
);
    prefix_cselect_core_64 #(.BLOCK_BITS(8), .LEVELS(3)) u_core
        (.a(a), .b(b), .cin(cin), .sum(sum), .cout(cout));
endmodule

// 4 groups x 16 bits; 2 prefix levels.
module prefix_cselect_64_b16 (
    input wire [63:0] a, b, input wire cin,
    output wire [63:0] sum, output wire cout
);
    prefix_cselect_core_64 #(.BLOCK_BITS(16), .LEVELS(2)) u_core
        (.a(a), .b(b), .cin(cin), .sum(sum), .cout(cout));
endmodule
