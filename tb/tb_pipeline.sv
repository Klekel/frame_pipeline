module tb_pipeline ();
import pipeline_pkg::*;
logic       clk       = 0;
logic       rst_n     = 1;
logic       hs_i      = 0;
logic       vs_i      = 0;
logic [7:0] red       = 0;
logic [7:0] green     = 0;
logic [7:0] blue      = 0;
logic [19:0] threshold = 120;

logic hs_o;
logic vs_o;
logic y_o;
logic valid_o;

initial forever #10 clk = ~clk;

frame_pipeline_top
#(
  .FRAME_WIDTH ( FRAME_WIDTH ),
  .FRAME_HIGHT ( FRAME_HIGHT ),
  .MATRIX_COEF ( MATRIX_COEF )
) dut (
.clk_i       ( clk       ),
.rstn_i      ( rst_n     ),
.hs_i        ( hs_i      ),
.vs_i        ( vs_i      ),
.red_i       ( red       ),
.green_i     ( green     ),
.blue_i      ( blue      ),
.threshold_i ( threshold ),

.hs_o        ( hs_o      ),
.vs_o        ( vs_o      ),
.y_o         ( y_o       ),
.valid_o     ( valid_o   )
);

// ---------------------------------------------------------------
// Загрузка одного канала изображения из файла channel_*.txt
// Формат: числа 0..255 через пробел/перенос строки (N×N штук)
// ---------------------------------------------------------------
task automatic load_channel(input string fname, ref logic [7:0] img[FRAME_HIGHT][FRAME_WIDTH]);
    integer fd;
    integer val;
    int     y, x_idx;
    int     r;

    fd = $fopen(fname, "r");
    if (fd == 0) begin
        $display("ERROR: Cannot open %s", fname);
        $finish;
    end

    for (y = 0; y < FRAME_HIGHT; y++) begin
        for (x_idx = 0; x_idx < FRAME_WIDTH; x_idx++) begin
            r = $fscanf(fd, "%d", val);
            if (r != 1) begin
                $display("ERROR: %s: EOF/short read at row %0d col %0d", fname, y, x_idx);
                $fclose(fd);
                $finish;
            end
            if (val < 0 || val > 255) begin
                $display("ERROR: %s: value %0d out of range at row %0d col %0d",
                         fname, val, y, x_idx);
                $fclose(fd);
                $finish;
            end
            img[y][x_idx] = val[7:0];
        end
    end

    $fclose(fd);
    $display("Loaded %s (%0d x %0d)", fname, FRAME_WIDTH, FRAME_HIGHT);
endtask

    logic [7:0] img_r [0:FRAME_HIGHT-1][0:FRAME_WIDTH-1];
    logic [7:0] img_g [0:FRAME_HIGHT-1][0:FRAME_WIDTH-1];
    logic [7:0] img_b [0:FRAME_HIGHT-1][0:FRAME_WIDTH-1];

    logic       out_mask [0:FRAME_HIGHT-3][0:FRAME_WIDTH-3];

task automatic init_image_checker();

    int     fd;
    int     y, x_idx;

    // // 1) Заполняем массивы (ваш исходный код)
    // for (int y = 0; y < FRAME_HIGHT; y++)
    //     for (int x_idx = 0; x_idx < FRAME_WIDTH; x_idx++) begin
    //         if (((x_idx/8) + (y/8)) % 2 == 0) begin
    //             img_r[y][x_idx] = $urandom();
    //             img_g[y][x_idx] = $urandom();
    //             img_b[y][x_idx] = $urandom();
    //         end else begin
    //             img_r[y][x_idx] = $urandom();
    //             img_g[y][x_idx] = $urandom();
    //             img_b[y][x_idx] = $urandom();
    //         end
    //     end

    load_channel("C:/univer/RTL_prototype/lab2/etc/channel_R.txt", img_r);
    load_channel("C:/univer/RTL_prototype/lab2/etc/channel_G.txt", img_g);
    load_channel("C:/univer/RTL_prototype/lab2/etc/channel_B.txt", img_b);

    fd = $fopen("C:/univer/RTL_prototype/lab2/sim_output/r_input.txt", "w");
    if (fd == 0) begin
        $display("ERROR: Cannot open %s for writing", "C:/univer/RTL_prototype/lab2/sim_output/r_input.txt");
        $finish;
    end

    for (y = 0; y < FRAME_HIGHT; y++) begin
        for (x_idx = 0; x_idx < FRAME_WIDTH; x_idx++) begin
            $fwrite(fd, "%0d", img_r[y][x_idx]);
            // Пробел между числами, но не после последнего в строке
            if (x_idx != FRAME_WIDTH - 1)
                $fwrite(fd, " ");
        end
        $fwrite(fd, "\n");   // конец строки изображения
    end

    $fflush(fd);
    $fclose(fd);             // ОБЯЗАТЕЛЬНО: без этого XSIM может оставить файл пустым
endtask

    task automatic drive_frame();
        for (int y = 0; y < FRAME_HIGHT; y++) begin
            for (int x = 0; x < FRAME_WIDTH; x++) begin
                red   <= img_r[x][y];
                green <= img_g[x][y];
                blue  <= img_b[x][y];
                if (x == FRAME_WIDTH - 1) begin
                  hs_i <= 1'b1;
                  if (y == FRAME_HIGHT - 1)
                    vs_i <= 1'b1;
                end
                @(posedge clk);
                hs_i <= 1'b0;
                vs_i <= 1'b0;
            end
        end
        red <= 0; green <= 0; blue <= 0;
    endtask

int out_x = 0;
int out_y = 0;
int cnt_y = 0;

localparam int ROWS = FRAME_WIDTH-2; 
localparam int COLS = FRAME_HIGHT-2; 

integer fd;
integer frame_cnt = 0;
integer r, c;

initial begin
    fd = $fopen("C:/univer/RTL_prototype/lab2/sim_output/out_mask_dump.txt", "w");
    if (fd == 0) begin
        $display("Error: Could not open file.");
        $finish;
    end
end

always @(posedge clk) begin
    if (!rst_n) begin
        out_x <= 0; out_y <= 0;
    end else if (vs_o) begin
        out_mask[out_y][out_x] = y_o;

        for (r = 0; r < ROWS; r++) begin      
            for (c = 0; c < COLS; c++) begin  
                $fwrite(fd, "%0d", out_mask[c][r]); 
            end
            $fwrite(fd, "\n");
        end
        $fwrite(fd, "\n");
        $fflush(fd);        
        frame_cnt = frame_cnt + 1;

        out_y <= 0; out_x <= 0;
    end else if (hs_o) begin
        out_mask[out_y][out_x] <= y_o;
        out_x <= 0;
        out_y <= out_y + 1;
    end else if (valid_o) begin
        out_mask[out_y][out_x] <= y_o;
        out_x <= out_x + 1;
    end
end

    initial begin
        repeat (1) @(posedge clk);
        rst_n <= 0;
        repeat (5) @(posedge clk);
        rst_n <= 1;

        init_image_checker();

        drive_frame();
        wait(vs_o);
        repeat (6) @(posedge clk);

        $finish;
    end

   initial begin
       #(FRAME_WIDTH * FRAME_HIGHT * 20 * 4);
       $display("[TB] TIMEOUT");
       $finish;
   end

endmodule