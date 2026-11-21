package pipeline_pkg;

  localparam  int         FRAME_WIDTH             = 16;
  localparam  int         FRAME_HIGHT             = 16;
  localparam  logic [3:0] MATRIX_COEF      [3][3] = '{'{-1, -1, -1}, '{-1, 8, -1},  '{-1, -1, -1}};

endpackage