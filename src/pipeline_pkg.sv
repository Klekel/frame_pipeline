package pipeline_pkg;

  localparam  int         FRAME_WIDTH             = 8;
  localparam  int         FRAME_HIGHT             = 8;
  localparam  logic [4:0] MATRIX_COEF      [3][3] = '{'{-1, -1, -1}, '{-1, 8, -1},  '{-1, -1, -1}};

endpackage