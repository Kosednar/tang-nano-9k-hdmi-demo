// -----------------------------------------------------------------------------
// 720p60 internal-RAM text/tile framebuffer
//
// Fits in GW1N/GW1NR-9 internal BSRAM.
// Screen size: 80 columns x 45 rows
// Cell size:   16 x 16 pixels
// Glyphs:      8 x 8 font doubled horizontally and vertically
//
// screen_word format:
//   [15:12] foreground color index
//   [11:8]  background color index
//   [7:0]   ASCII character code
//
// This module includes a write port so it can later be driven by UART, SPI,
// a soft CPU, a state machine, or your AC phase-engine debug logic.
// -----------------------------------------------------------------------------

module text_framebuffer_720p (
    input  wire        pix_clk,
    input  wire        resetn,
    input  wire        video_active,
    input  wire [10:0] h_cnt,
    input  wire [9:0]  v_cnt,

    // Optional write port. Tie wr_en low if unused.
    input  wire        wr_en,
    input  wire [11:0] wr_addr,
    input  wire [15:0] wr_data,

    output reg  [7:0]  red,
    output reg  [7:0]  green,
    output reg  [7:0]  blue
);

    localparam [6:0] COLS = 7'd80;
    localparam [5:0] ROWS = 6'd45;
    localparam [11:0] CELLS = 12'd3600;

    // 3600 cells x 16 bits = 57,600 bits.
    reg [15:0] screen_ram [0:3599];

    // One 16-bit word per character cell: foreground color, background color,
    // and ASCII character. This keeps the text buffer small enough for BSRAM.

    // Power-up/demo initialization writer.
    reg        init_busy = 1'b1;
    reg [11:0] init_addr = 12'd0;

    // Convert current pixel position to text cell position.
    // 1280 / 16 = 80 columns, 720 / 16 = 45 rows.
    wire [6:0] text_col = h_cnt[10:4];
    wire [5:0] text_row = v_cnt[9:4];
    wire [3:0] cell_x   = h_cnt[3:0];
    wire [3:0] cell_y   = v_cnt[3:0];

    wire [12:0] read_addr_raw = (text_row * 13'd80) + text_col;

    // Convert the current pixel into an 80-column text address. The font is
    // 8x8 but doubled to 16x16 pixels per character cell.
    wire [11:0] read_addr = video_active ? read_addr_raw[11:0] : 12'd0;

    reg [15:0] screen_word = 16'h0000;
    reg [3:0]  cell_x_d = 4'd0;
    reg [3:0]  cell_y_d = 4'd0;
    reg        active_d = 1'b0;

    wire [7:0]  ascii = screen_word[7:0];
    wire [3:0]  fg    = screen_word[15:12];
    wire [3:0]  bg    = screen_word[11:8];
    wire [2:0]  font_x = cell_x_d[3:1];  // double width
    wire [2:0]  font_y = cell_y_d[3:1];  // double height
    wire        glyph_on = font_pixel(ascii, font_y, font_x);
    wire [23:0] fg_rgb = color_rgb(fg);
    wire [23:0] bg_rgb = color_rgb(bg);
    wire [23:0] rgb_next = (active_d && glyph_on) ? fg_rgb : (active_d ? bg_rgb : 24'h000000);

    always @(posedge pix_clk or negedge resetn) begin
        if (!resetn) begin
            init_busy   <= 1'b1;
            init_addr   <= 12'd0;
            screen_word <= 16'h0000;
            cell_x_d    <= 4'd0;
            cell_y_d    <= 4'd0;
            active_d    <= 1'b0;
            red         <= 8'h00;
            green       <= 8'h00;
            blue        <= 8'h00;
        end else begin
            // Fill the text buffer after reset. This takes only 3600 pixel clocks,
            // about 48.5 microseconds at 74.25 MHz.
            if (init_busy) begin
                screen_ram[init_addr] <= init_word(init_addr);
                if (init_addr == CELLS - 1'b1)
                    init_busy <= 1'b0;
                else
                    init_addr <= init_addr + 1'b1;
            end else if (wr_en && (wr_addr < CELLS)) begin
                screen_ram[wr_addr] <= wr_data;
            end

            screen_word <= screen_ram[read_addr];
            cell_x_d    <= cell_x;
            cell_y_d    <= cell_y;
            active_d    <= video_active;

            red   <= rgb_next[23:16];
            green <= rgb_next[15:8];
            blue  <= rgb_next[7:0];
        end
    end

    // -------------------------------------------------------------------------
    // Demo screen contents. The RAM still behaves like a real screen buffer;
    // this function only creates the initial power-up message.
    // -------------------------------------------------------------------------
    function [15:0] init_word;
        // Initial text shown on power-up. To change a label, edit only the
        // character entries for that row/column. The waveform overlay is separate.
        input [11:0] addr;
        begin
            // Default: dark blue background, bright white character space.
            init_word = {4'hF, 4'h1, 8'h20};
            case (addr)
                // Row 1, col 4 (raised top label)
                12'd84: init_word = {4'hE,4'h1,"T"};
                12'd85: init_word = {4'hE,4'h1,"O"};
                12'd86: init_word = {4'hE,4'h1,"P"};
                12'd87: init_word = {4'hE,4'h1,":"};
                12'd88: init_word = {4'hE,4'h1," "};
                12'd89: init_word = {4'hE,4'h1,"S"};
                12'd90: init_word = {4'hE,4'h1,"I"};
                12'd91: init_word = {4'hE,4'h1,"G"};
                12'd92: init_word = {4'hE,4'h1,"N"};
                12'd93: init_word = {4'hE,4'h1,"A"};
                12'd94: init_word = {4'hE,4'h1,"L"};
                12'd95: init_word = {4'hE,4'h1," "};
                12'd96: init_word = {4'hE,4'h1,"G"};
                12'd97: init_word = {4'hE,4'h1,"E"};
                12'd98: init_word = {4'hE,4'h1,"N"};
                12'd99: init_word = {4'hE,4'h1,"E"};
                12'd100: init_word = {4'hE,4'h1,"R"};
                12'd101: init_word = {4'hE,4'h1,"A"};
                12'd102: init_word = {4'hE,4'h1,"T"};
                12'd103: init_word = {4'hE,4'h1,"O"};
                12'd104: init_word = {4'hE,4'h1,"R"};
                // Row 17, col 4
                12'd1364: init_word = {4'hB,4'h1,"M"};
                12'd1365: init_word = {4'hB,4'h1,"I"};
                12'd1366: init_word = {4'hB,4'h1,"D"};
                12'd1367: init_word = {4'hB,4'h1,"D"};
                12'd1368: init_word = {4'hB,4'h1,"L"};
                12'd1369: init_word = {4'hB,4'h1,"E"};
                12'd1370: init_word = {4'hB,4'h1,":"};
                12'd1371: init_word = {4'hB,4'h1," "};
                12'd1372: init_word = {4'hB,4'h1,"S"};
                12'd1373: init_word = {4'hB,4'h1,"I"};
                12'd1374: init_word = {4'hB,4'h1,"M"};
                12'd1375: init_word = {4'hB,4'h1,"P"};
                12'd1376: init_word = {4'hB,4'h1,"L"};
                12'd1377: init_word = {4'hB,4'h1,"E"};
                12'd1378: init_word = {4'hB,4'h1," "};
                12'd1379: init_word = {4'hB,4'h1,"P"};
                12'd1380: init_word = {4'hB,4'h1,"L"};
                12'd1381: init_word = {4'hB,4'h1,"L"};
                // Row 32, col 4
                12'd2564: init_word = {4'hD,4'h1,"B"};
                12'd2565: init_word = {4'hD,4'h1,"O"};
                12'd2566: init_word = {4'hD,4'h1,"T"};
                12'd2567: init_word = {4'hD,4'h1,"T"};
                12'd2568: init_word = {4'hD,4'h1,"O"};
                12'd2569: init_word = {4'hD,4'h1,"M"};
                12'd2570: init_word = {4'hD,4'h1,":"};
                12'd2571: init_word = {4'hD,4'h1," "};
                12'd2572: init_word = {4'hD,4'h1,"P"};
                12'd2573: init_word = {4'hD,4'h1,"A"};
                12'd2574: init_word = {4'hD,4'h1,"T"};
                12'd2575: init_word = {4'hD,4'h1,"E"};
                12'd2576: init_word = {4'hD,4'h1,"N"};
                12'd2577: init_word = {4'hD,4'h1,"T"};
                12'd2578: init_word = {4'hD,4'h1," "};
                12'd2579: init_word = {4'hD,4'h1,"U"};
                12'd2580: init_word = {4'hD,4'h1,"S"};
                12'd2581: init_word = {4'hD,4'h1," "};
                12'd2582: init_word = {4'hD,4'h1,"1"};
                12'd2583: init_word = {4'hD,4'h1,"1"};
                12'd2584: init_word = {4'hD,4'h1,","};
                12'd2585: init_word = {4'hD,4'h1,"2"};
                12'd2586: init_word = {4'hD,4'h1,"9"};
                12'd2587: init_word = {4'hD,4'h1,"0"};
                12'd2588: init_word = {4'hD,4'h1,","};
                12'd2589: init_word = {4'hD,4'h1,"1"};
                12'd2590: init_word = {4'hD,4'h1,"1"};
                12'd2591: init_word = {4'hD,4'h1,"7"};
                12'd2592: init_word = {4'hD,4'h1," "};
                12'd2593: init_word = {4'hD,4'h1,"B"};
                12'd2594: init_word = {4'hD,4'h1,"1"};
                // Row 42, col 4
                12'd3364: init_word = {4'hE,4'h1,"J"};
                12'd3365: init_word = {4'hE,4'h1,"O"};
                12'd3366: init_word = {4'hE,4'h1,"E"};
                12'd3367: init_word = {4'hE,4'h1,"S"};
                12'd3368: init_word = {4'hE,4'h1," "};
                12'd3369: init_word = {4'hE,4'h1,"J"};
                12'd3370: init_word = {4'hE,4'h1,"E"};
                12'd3371: init_word = {4'hE,4'h1,"M"};
                12'd3372: init_word = {4'hE,4'h1,"S"};
                12'd3373: init_word = {4'hE,4'h1," "};
                12'd3374: init_word = {4'hE,4'h1,"C"};
                12'd3375: init_word = {4'hE,4'h1,"R"};
                12'd3376: init_word = {4'hE,4'h1,"E"};
                12'd3377: init_word = {4'hE,4'h1,"A"};
                12'd3378: init_word = {4'hE,4'h1,"T"};
                12'd3379: init_word = {4'hE,4'h1,"I"};
                12'd3380: init_word = {4'hE,4'h1,"O"};
                12'd3381: init_word = {4'hE,4'h1,"N"};
                12'd3382: init_word = {4'hE,4'h1,"S"};
                12'd3383: init_word = {4'hE,4'h1," "};
                12'd3384: init_word = {4'hE,4'h1,"L"};
                12'd3385: init_word = {4'hE,4'h1,"L"};
                12'd3386: init_word = {4'hE,4'h1,"C"};

                default: init_word = init_word;
            endcase
        end
    endfunction

    // -------------------------------------------------------------------------
    // 4-bit color palette, roughly CGA/VGA-like.
    // -------------------------------------------------------------------------
    function [23:0] color_rgb;
        input [3:0] idx;
        begin
            case (idx)
                4'h0: color_rgb = 24'h000000; // black
                4'h1: color_rgb = 24'h000050; // dark blue
                4'h2: color_rgb = 24'h005000; // dark green
                4'h3: color_rgb = 24'h005050; // dark cyan
                4'h4: color_rgb = 24'h500000; // dark red
                4'h5: color_rgb = 24'h500050; // dark magenta
                4'h6: color_rgb = 24'h505000; // brown/dark yellow
                4'h7: color_rgb = 24'hA0A0A0; // light gray
                4'h8: color_rgb = 24'h606060; // gray
                4'h9: color_rgb = 24'h0000FF; // blue
                4'hA: color_rgb = 24'h00FF00; // green
                4'hB: color_rgb = 24'h00FFFF; // cyan
                4'hC: color_rgb = 24'hFF0000; // red
                4'hD: color_rgb = 24'hFF00FF; // magenta
                4'hE: color_rgb = 24'hFFFF00; // yellow
                default: color_rgb = 24'hFFFFFF; // white
            endcase
        end
    endfunction

    function font_pixel;
        // Built-in 8x8 bitmap font. Each case entry is one ASCII character.
        input [7:0] ch;
        input [2:0] row;
        input [2:0] col;
        reg [7:0] bits;
        begin
            bits = font_row_bits(ch, row);
            case (col)
                3'd0: font_pixel = bits[7];
                3'd1: font_pixel = bits[6];
                3'd2: font_pixel = bits[5];
                3'd3: font_pixel = bits[4];
                3'd4: font_pixel = bits[3];
                3'd5: font_pixel = bits[2];
                3'd6: font_pixel = bits[1];
                default: font_pixel = bits[0];
            endcase
        end
    endfunction

    // 8x8 block font. Not pretty, but easy to synthesize and read.
    function [7:0] font_row_bits;
        input [7:0] ch;
        input [2:0] row;
        begin
            font_row_bits = 8'h00;
            case (ch)
                "A": case(row) 0:font_row_bits=8'b00111100;1:font_row_bits=8'b01100110;2:font_row_bits=8'b01100110;3:font_row_bits=8'b01111110;4:font_row_bits=8'b01100110;5:font_row_bits=8'b01100110;6:font_row_bits=8'b01100110;default:font_row_bits=8'b00000000; endcase
                "B": case(row) 0:font_row_bits=8'b01111100;1:font_row_bits=8'b01100110;2:font_row_bits=8'b01100110;3:font_row_bits=8'b01111100;4:font_row_bits=8'b01100110;5:font_row_bits=8'b01100110;6:font_row_bits=8'b01111100;default:font_row_bits=8'b00000000; endcase
                "C": case(row) 0:font_row_bits=8'b00111100;1:font_row_bits=8'b01100110;2:font_row_bits=8'b01100000;3:font_row_bits=8'b01100000;4:font_row_bits=8'b01100000;5:font_row_bits=8'b01100110;6:font_row_bits=8'b00111100;default:font_row_bits=8'b00000000; endcase
                "D": case(row) 0:font_row_bits=8'b01111000;1:font_row_bits=8'b01101100;2:font_row_bits=8'b01100110;3:font_row_bits=8'b01100110;4:font_row_bits=8'b01100110;5:font_row_bits=8'b01101100;6:font_row_bits=8'b01111000;default:font_row_bits=8'b00000000; endcase
                "E": case(row) 0:font_row_bits=8'b01111110;1:font_row_bits=8'b01100000;2:font_row_bits=8'b01100000;3:font_row_bits=8'b01111100;4:font_row_bits=8'b01100000;5:font_row_bits=8'b01100000;6:font_row_bits=8'b01111110;default:font_row_bits=8'b00000000; endcase
                "F": case(row) 0:font_row_bits=8'b01111110;1:font_row_bits=8'b01100000;2:font_row_bits=8'b01100000;3:font_row_bits=8'b01111100;4:font_row_bits=8'b01100000;5:font_row_bits=8'b01100000;6:font_row_bits=8'b01100000;default:font_row_bits=8'b00000000; endcase
                "G": case(row) 0:font_row_bits=8'b00111100;1:font_row_bits=8'b01100110;2:font_row_bits=8'b01100000;3:font_row_bits=8'b01101110;4:font_row_bits=8'b01100110;5:font_row_bits=8'b01100110;6:font_row_bits=8'b00111100;default:font_row_bits=8'b00000000; endcase
                "H": case(row) 0:font_row_bits=8'b01100110;1:font_row_bits=8'b01100110;2:font_row_bits=8'b01100110;3:font_row_bits=8'b01111110;4:font_row_bits=8'b01100110;5:font_row_bits=8'b01100110;6:font_row_bits=8'b01100110;default:font_row_bits=8'b00000000; endcase
                "I": case(row) 0:font_row_bits=8'b00111100;1:font_row_bits=8'b00011000;2:font_row_bits=8'b00011000;3:font_row_bits=8'b00011000;4:font_row_bits=8'b00011000;5:font_row_bits=8'b00011000;6:font_row_bits=8'b00111100;default:font_row_bits=8'b00000000; endcase
                "J": case(row) 0:font_row_bits=8'b00011110;1:font_row_bits=8'b00001100;2:font_row_bits=8'b00001100;3:font_row_bits=8'b00001100;4:font_row_bits=8'b01101100;5:font_row_bits=8'b01101100;6:font_row_bits=8'b00111000;default:font_row_bits=8'b00000000; endcase
                "K": case(row) 0:font_row_bits=8'b01100110;1:font_row_bits=8'b01101100;2:font_row_bits=8'b01111000;3:font_row_bits=8'b01110000;4:font_row_bits=8'b01111000;5:font_row_bits=8'b01101100;6:font_row_bits=8'b01100110;default:font_row_bits=8'b00000000; endcase
                "L": case(row) 0:font_row_bits=8'b01100000;1:font_row_bits=8'b01100000;2:font_row_bits=8'b01100000;3:font_row_bits=8'b01100000;4:font_row_bits=8'b01100000;5:font_row_bits=8'b01100000;6:font_row_bits=8'b01111110;default:font_row_bits=8'b00000000; endcase
                "M": case(row) 0:font_row_bits=8'b01100011;1:font_row_bits=8'b01110111;2:font_row_bits=8'b01111111;3:font_row_bits=8'b01101011;4:font_row_bits=8'b01100011;5:font_row_bits=8'b01100011;6:font_row_bits=8'b01100011;default:font_row_bits=8'b00000000; endcase
                "N": case(row) 0:font_row_bits=8'b01100110;1:font_row_bits=8'b01110110;2:font_row_bits=8'b01111110;3:font_row_bits=8'b01111110;4:font_row_bits=8'b01101110;5:font_row_bits=8'b01100110;6:font_row_bits=8'b01100110;default:font_row_bits=8'b00000000; endcase
                "O": case(row) 0:font_row_bits=8'b00111100;1:font_row_bits=8'b01100110;2:font_row_bits=8'b01100110;3:font_row_bits=8'b01100110;4:font_row_bits=8'b01100110;5:font_row_bits=8'b01100110;6:font_row_bits=8'b00111100;default:font_row_bits=8'b00000000; endcase
                "P": case(row) 0:font_row_bits=8'b01111100;1:font_row_bits=8'b01100110;2:font_row_bits=8'b01100110;3:font_row_bits=8'b01111100;4:font_row_bits=8'b01100000;5:font_row_bits=8'b01100000;6:font_row_bits=8'b01100000;default:font_row_bits=8'b00000000; endcase
                "Q": case(row) 0:font_row_bits=8'b00111100;1:font_row_bits=8'b01100110;2:font_row_bits=8'b01100110;3:font_row_bits=8'b01100110;4:font_row_bits=8'b01101110;5:font_row_bits=8'b00111100;6:font_row_bits=8'b00000110;default:font_row_bits=8'b00000000; endcase
                "R": case(row) 0:font_row_bits=8'b01111100;1:font_row_bits=8'b01100110;2:font_row_bits=8'b01100110;3:font_row_bits=8'b01111100;4:font_row_bits=8'b01111000;5:font_row_bits=8'b01101100;6:font_row_bits=8'b01100110;default:font_row_bits=8'b00000000; endcase
                "S": case(row) 0:font_row_bits=8'b00111100;1:font_row_bits=8'b01100110;2:font_row_bits=8'b01100000;3:font_row_bits=8'b00111100;4:font_row_bits=8'b00000110;5:font_row_bits=8'b01100110;6:font_row_bits=8'b00111100;default:font_row_bits=8'b00000000; endcase
                "T": case(row) 0:font_row_bits=8'b01111110;1:font_row_bits=8'b01011010;2:font_row_bits=8'b00011000;3:font_row_bits=8'b00011000;4:font_row_bits=8'b00011000;5:font_row_bits=8'b00011000;6:font_row_bits=8'b00111100;default:font_row_bits=8'b00000000; endcase
                "U": case(row) 0:font_row_bits=8'b01100110;1:font_row_bits=8'b01100110;2:font_row_bits=8'b01100110;3:font_row_bits=8'b01100110;4:font_row_bits=8'b01100110;5:font_row_bits=8'b01100110;6:font_row_bits=8'b00111100;default:font_row_bits=8'b00000000; endcase
                "V": case(row) 0:font_row_bits=8'b01100110;1:font_row_bits=8'b01100110;2:font_row_bits=8'b01100110;3:font_row_bits=8'b01100110;4:font_row_bits=8'b01100110;5:font_row_bits=8'b00111100;6:font_row_bits=8'b00011000;default:font_row_bits=8'b00000000; endcase
                "W": case(row) 0:font_row_bits=8'b01100011;1:font_row_bits=8'b01100011;2:font_row_bits=8'b01100011;3:font_row_bits=8'b01101011;4:font_row_bits=8'b01111111;5:font_row_bits=8'b01110111;6:font_row_bits=8'b01100011;default:font_row_bits=8'b00000000; endcase
                "X": case(row) 0:font_row_bits=8'b01100110;1:font_row_bits=8'b01100110;2:font_row_bits=8'b00111100;3:font_row_bits=8'b00011000;4:font_row_bits=8'b00111100;5:font_row_bits=8'b01100110;6:font_row_bits=8'b01100110;default:font_row_bits=8'b00000000; endcase
                "Y": case(row) 0:font_row_bits=8'b01100110;1:font_row_bits=8'b01100110;2:font_row_bits=8'b00111100;3:font_row_bits=8'b00011000;4:font_row_bits=8'b00011000;5:font_row_bits=8'b00011000;6:font_row_bits=8'b00111100;default:font_row_bits=8'b00000000; endcase
                "Z": case(row) 0:font_row_bits=8'b01111110;1:font_row_bits=8'b00000110;2:font_row_bits=8'b00001100;3:font_row_bits=8'b00011000;4:font_row_bits=8'b00110000;5:font_row_bits=8'b01100000;6:font_row_bits=8'b01111110;default:font_row_bits=8'b00000000; endcase
                "0": case(row) 0:font_row_bits=8'b00111100;1:font_row_bits=8'b01100110;2:font_row_bits=8'b01101110;3:font_row_bits=8'b01110110;4:font_row_bits=8'b01100110;5:font_row_bits=8'b01100110;6:font_row_bits=8'b00111100;default:font_row_bits=8'b00000000; endcase
                "1": case(row) 0:font_row_bits=8'b00011000;1:font_row_bits=8'b00111000;2:font_row_bits=8'b00011000;3:font_row_bits=8'b00011000;4:font_row_bits=8'b00011000;5:font_row_bits=8'b00011000;6:font_row_bits=8'b01111110;default:font_row_bits=8'b00000000; endcase
                "2": case(row) 0:font_row_bits=8'b00111100;1:font_row_bits=8'b01100110;2:font_row_bits=8'b00000110;3:font_row_bits=8'b00011100;4:font_row_bits=8'b00110000;5:font_row_bits=8'b01100000;6:font_row_bits=8'b01111110;default:font_row_bits=8'b00000000; endcase
                "3": case(row) 0:font_row_bits=8'b00111100;1:font_row_bits=8'b01100110;2:font_row_bits=8'b00000110;3:font_row_bits=8'b00011100;4:font_row_bits=8'b00000110;5:font_row_bits=8'b01100110;6:font_row_bits=8'b00111100;default:font_row_bits=8'b00000000; endcase
                "4": case(row) 0:font_row_bits=8'b00001100;1:font_row_bits=8'b00011100;2:font_row_bits=8'b00101100;3:font_row_bits=8'b01001100;4:font_row_bits=8'b01111110;5:font_row_bits=8'b00001100;6:font_row_bits=8'b00011110;default:font_row_bits=8'b00000000; endcase
                "5": case(row) 0:font_row_bits=8'b01111110;1:font_row_bits=8'b01100000;2:font_row_bits=8'b01111100;3:font_row_bits=8'b00000110;4:font_row_bits=8'b00000110;5:font_row_bits=8'b01100110;6:font_row_bits=8'b00111100;default:font_row_bits=8'b00000000; endcase
                "6": case(row) 0:font_row_bits=8'b00111100;1:font_row_bits=8'b01100110;2:font_row_bits=8'b01100000;3:font_row_bits=8'b01111100;4:font_row_bits=8'b01100110;5:font_row_bits=8'b01100110;6:font_row_bits=8'b00111100;default:font_row_bits=8'b00000000; endcase
                "7": case(row) 0:font_row_bits=8'b01111110;1:font_row_bits=8'b00000110;2:font_row_bits=8'b00001100;3:font_row_bits=8'b00011000;4:font_row_bits=8'b00110000;5:font_row_bits=8'b00110000;6:font_row_bits=8'b00110000;default:font_row_bits=8'b00000000; endcase
                "8": case(row) 0:font_row_bits=8'b00111100;1:font_row_bits=8'b01100110;2:font_row_bits=8'b01100110;3:font_row_bits=8'b00111100;4:font_row_bits=8'b01100110;5:font_row_bits=8'b01100110;6:font_row_bits=8'b00111100;default:font_row_bits=8'b00000000; endcase
                "9": case(row) 0:font_row_bits=8'b00111100;1:font_row_bits=8'b01100110;2:font_row_bits=8'b01100110;3:font_row_bits=8'b00111110;4:font_row_bits=8'b00000110;5:font_row_bits=8'b01100110;6:font_row_bits=8'b00111100;default:font_row_bits=8'b00000000; endcase
                " ": font_row_bits = 8'b00000000;
                "-": case(row) 3:font_row_bits=8'b01111110; default:font_row_bits=8'b00000000; endcase
                ":": case(row) 1:font_row_bits=8'b00011000;2:font_row_bits=8'b00011000;5:font_row_bits=8'b00011000;6:font_row_bits=8'b00011000;default:font_row_bits=8'b00000000; endcase
                ".": case(row) 5:font_row_bits=8'b00011000;6:font_row_bits=8'b00011000;default:font_row_bits=8'b00000000; endcase
                ",": case(row) 5:font_row_bits=8'b00011000;6:font_row_bits=8'b00011000;7:font_row_bits=8'b00110000;default:font_row_bits=8'b00000000; endcase
                "+": case(row) 1:font_row_bits=8'b00011000;2:font_row_bits=8'b00011000;3:font_row_bits=8'b01111110;4:font_row_bits=8'b00011000;5:font_row_bits=8'b00011000;default:font_row_bits=8'b00000000; endcase
                "/": case(row) 0:font_row_bits=8'b00000110;1:font_row_bits=8'b00001100;2:font_row_bits=8'b00011000;3:font_row_bits=8'b00110000;4:font_row_bits=8'b01100000;default:font_row_bits=8'b00000000; endcase
                "[": case(row) 0:font_row_bits=8'b00111100;1:font_row_bits=8'b00110000;2:font_row_bits=8'b00110000;3:font_row_bits=8'b00110000;4:font_row_bits=8'b00110000;5:font_row_bits=8'b00110000;6:font_row_bits=8'b00111100;default:font_row_bits=8'b00000000; endcase
                "]": case(row) 0:font_row_bits=8'b00111100;1:font_row_bits=8'b00001100;2:font_row_bits=8'b00001100;3:font_row_bits=8'b00001100;4:font_row_bits=8'b00001100;5:font_row_bits=8'b00001100;6:font_row_bits=8'b00111100;default:font_row_bits=8'b00000000; endcase
                default: font_row_bits = 8'b00000000;
            endcase
        end
    endfunction

endmodule
