module tb_pipeline ();
import pipeline_pkg::*;
logic       clk       = 0;
logic       rst_n     = 1;
logic       hs_i      = 0;
logic       vs_i      = 0;
logic [7:0] red       = 0;
logic [7:0] green     = 0;
logic [7:0] blue      = 0;
logic [7:0] threshold = 12;

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
    // Буферы изображения (память кадра)
    // ---------------------------------------------------------------
    logic [7:0] img_r [0:FRAME_HIGHT-1][0:FRAME_WIDTH-1];
    logic [7:0] img_g [0:FRAME_HIGHT-1][0:FRAME_WIDTH-1];
    logic [7:0] img_b [0:FRAME_HIGHT-1][0:FRAME_WIDTH-1];

    logic       out_mask [0:FRAME_HIGHT-3][0:FRAME_WIDTH-3];

    // Заполнение «шахматкой» — удобно для проверки границ
    task automatic init_image_checker();
        for (int y = 0; y < FRAME_HIGHT; y++)
            for (int x = 0; x < FRAME_WIDTH; x++) begin
                if (((x/4) + (y/4)) % 2 == 0) begin
                    img_r[y][x] = 8'h0f;
                    img_g[y][x] = 8'h0f;
                    img_b[y][x] = 8'h0f;
                end else begin
                    img_r[y][x] = 8'h00;
                    img_g[y][x] = 8'h00;
                    img_b[y][x] = 8'h00;
                end
            end
    endtask

    // ---------------------------------------------------------------
    // Драйвер пикселей: подаёт изображение построчно
    //   hs_i — импульс 1 такт в конце каждой строки
    //   vs_i — импульс 1 такт в конце кадра
    // ---------------------------------------------------------------
    task automatic drive_frame();
        for (int y = 0; y < FRAME_HIGHT; y++) begin
            for (int x = 0; x < FRAME_WIDTH; x++) begin
                red   <= img_r[y][x];
                green <= img_g[y][x];
                blue  <= img_b[y][x];
                if (x == FRAME_WIDTH - 1) begin // --- конец строки: hs_i ---
                  hs_i <= 1'b1;
                  if (y == FRAME_HIGHT - 1) // --- конец кадра: vs_i ---
                    vs_i <= 1'b1;
                end
                @(posedge clk);
                hs_i <= 1'b0;
                vs_i <= 1'b0;
            end
        end

        // сброс входов в ноль
        red <= 0; green <= 0; blue <= 0;
    endtask

    // ---------------------------------------------------------------
    // Приёмник выходной маски: ловит y_o когда valid_o=1,
    // восстанавливает координаты по счётчикам hs_o/vs_o.
    //   hs_o — 1 такт в конце каждой выходной строки
    //   vs_o — 1 такт в конце выходного кадра
    // ---------------------------------------------------------------
    int out_x = 0;
    int out_y = 0;
    int cnt_y = 0;

    always @(posedge clk) begin
        if (!rst_n) begin
            out_x <= 0; out_y <= 0;
        end else if (vs_o) begin
            // конец кадра — сброс координат
            out_y <= 0; out_x <= 0;
        end else if (hs_o) begin
            // конец строки — переход к следующей строке
            out_x <= 0;
            out_y <= out_y + 1;
        end else if (valid_o) begin
            out_mask[out_y][out_x] <= y_o;
            out_x <= out_x + 1;
        end
    end

    // ---------------------------------------------------------------
    // Сравнение выходной маски с эталоном (программная свёртка)
    // ---------------------------------------------------------------
    task automatic check_output();
        int errors = 0;
        int reference;
        int gray;
        for (int y = 0; y < FRAME_HIGHT-2; y++) begin
            for (int x = 0; x < FRAME_WIDTH-2; x++) begin
                // Эталонная свёртка с матрицей MATRIX_COEF по градациям серого
                reference = 0;
                for (int ky = -1; ky <= 1; ky++)
                    for (int kx = -1; kx <= 1; kx++) begin
                        int yy = y + ky;
                        int xx = x + kx;
                        if (yy < 0 || yy >= FRAME_HIGHT-2 || xx < 0 || xx >= FRAME_WIDTH-2) continue;
                        gray = (img_r[yy][xx] * 77 + img_g[yy][xx] * 150 + img_b[yy][xx] * 29) >> 8;
                        reference += gray * $signed(MATRIX_COEF[ky+1][kx+1]);
                    end
                if ((reference > threshold) !== out_mask[y][x]) begin
                    if (errors < 100)
                        $display("[TB] MISMATCH (%0d,%0d): reference=%0d out=%b",
                                 y, x, reference, out_mask[y][x]);
                    errors++;
                end
            end
        end
        if (errors == 0)
            $display("[TB] PASS — все %0d пикселей совпали", FRAME_WIDTH*FRAME_HIGHT);
        else
            $display("[TB] FAIL — %0d/%0d несовпадений", errors, FRAME_WIDTH*FRAME_HIGHT);
    endtask

    // ---------------------------------------------------------------
    // Основной сценарий
    // ---------------------------------------------------------------
    initial begin
        repeat (1) @(posedge clk);
        rst_n <= 0;
        repeat (5) @(posedge clk);
        rst_n <= 1;

        // 2. Изображение: либо из файла, либо шахматка
        // load_image("img64.mem");     // раскомментируйте, если файл есть
        init_image_checker();

        // 3. Подать кадр
          drive_frame();
        fork
          drive_frame();
        join_none

        // 4. Подождать, пока пайплайн опустошится
        //    (3 строки по FRAME_WIDTH тактов + запас)
        repeat (FRAME_WIDTH * 10 + 20) @(posedge clk);

        // 5. Проверка
        check_output();

        $finish;
    end

    // Таймаут
    initial begin
        #(FRAME_WIDTH * FRAME_HIGHT * 20 * 4);
        $display("[TB] TIMEOUT");
        $finish;
    end

endmodule