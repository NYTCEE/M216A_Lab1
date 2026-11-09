module hybrid_cla_prefix_64 (
    input  wire [63:0] a,
    input  wire [63:0] b,
    input  wire        cin,
    output wire [63:0] sum,
    output wire        cout
);

    // 1. Bit propagate and generate
    wire [63:0] p, g;
    assign p = a ^ b;
    assign g = a & b;

    // 2. Four-bit group propagate/generate
    wire [15:0] block_p, block_g;
    genvar k, stage, idx;

    generate
        for (k = 0; k < 16; k = k + 1) begin : GROUP_PG
            assign block_p[k] = &p[4*k+3 : 4*k];

            assign block_g[k] =
                  g[4*k+3]
                | (p[4*k+3] & g[4*k+2])
                | (p[4*k+3] & p[4*k+2] & g[4*k+1])
                | (p[4*k+3] & p[4*k+2] &
                   p[4*k+1] & g[4*k]);
        end
    endgenerate

    // 3. Four parallel-prefix stages
    wire [15:0] PP [0:4];
    wire [15:0] GG [0:4];

    assign PP[0] = block_p;
    assign GG[0] = block_g;

    generate
        for (stage = 0; stage < 4; stage = stage + 1)
        begin : PREFIX_STAGE
            for (idx = 0; idx < 16; idx = idx + 1)
            begin : PREFIX_NODE
                if (idx >= (1 << stage)) begin : COMBINE
                    assign GG[stage+1][idx] =
                        GG[stage][idx] |
                        (PP[stage][idx] &
                         GG[stage][idx-(1 << stage)]);

                    assign PP[stage+1][idx] =
                        PP[stage][idx] &
                        PP[stage][idx-(1 << stage)];
                end else begin : PASS
                    assign GG[stage+1][idx] = GG[stage][idx];
                    assign PP[stage+1][idx] = PP[stage][idx];
                end
            end
        end
    endgenerate

    // 4. Carry into each four-bit block
    wire [16:0] block_c;
    assign block_c[0] = cin;

    generate
        for (k = 0; k < 16; k = k + 1)
        begin : BLOCK_CARRY
            assign block_c[k+1] =
                GG[4][k] | (PP[4][k] & cin);
        end
    endgenerate

    // 5. Local carry-lookahead
    wire [63:0] bit_c;

    generate
        for (k = 0; k < 16; k = k + 1)
        begin : LOCAL_CARRY
            assign bit_c[4*k] = block_c[k];

            assign bit_c[4*k+1] =
                g[4*k] |
                (p[4*k] & block_c[k]);

            assign bit_c[4*k+2] =
                g[4*k+1] |
                (p[4*k+1] & g[4*k]) |
                (p[4*k+1] & p[4*k] & block_c[k]);

            assign bit_c[4*k+3] =
                g[4*k+2] |
                (p[4*k+2] & g[4*k+1]) |
                (p[4*k+2] & p[4*k+1] & g[4*k]) |
                (p[4*k+2] & p[4*k+1] &
                 p[4*k] & block_c[k]);
        end
    endgenerate

    // 6. Final sum and carry-out
    assign sum  = p ^ bit_c;
    assign cout = block_c[16];

endmodule
