package pipeline_pkg;

  localparam  int                FRAME_WIDTH             = 512;
  localparam  int                FRAME_HIGHT             = 512;
  localparam  logic signed [4:0] MATRIX_COEF      [3][3] = '{'{-1, -1, -1}, '{-1, 8, -1},  '{-1, -1, -1}};

endpackage