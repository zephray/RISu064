from risuconsts import *
# Struct: [direction, name, width]
# Direction is (loosely) defined as source -> sink
# If width is not given, it's treated as 1 bit scalar

# If signals
if_dec_t = [
    ["o", "pc", 64],
    ["o", "instr", 32],
    ["o", "bp"],
    ["o", "bp_track", 2],
    ["o", "bt", 64],
    ["o", "page_fault"]
]

## Decoded instruction
# Commomn signal sent to all FUs
dec_common_t = [
    ["o", "pc", 64],
    ["o", "op_type", 3],
    ["o", "operand1", 2],
    ["o", "operand2", 2],
    ["o", "imm", 64],
    ["o", "wb_en"],
    ["o", "rs1", 5],
    ["o", "rs2", 5],
    ["o", "rd", 5]
]

# Integer/ branch FU only signal
dec_int_t = [
    ["o", "op", 4],
    ["o", "option"],
    ["o", "truncate"],
    ["o", "br_type", 2],
    ["o", "br_neg"],
    ["o", "br_base_src"],
    ["o", "br_inj_pc"],
    ["o", "br_is_call"],
    ["o", "br_is_ret"],
    ["o", "bp"],
    ["o", "bp_track", 2],
    ["o", "bt", 64]
]

# Load store FU only signal
dec_ls_t = [
    ["o", "mem_sign"],
    ["o", "mem_width", 2]
]

# CSR handling FU only signal
dec_csr_t = [
    ["o", "csr_op", 2],
    ["o", "mret"],
    ["o", "intr"],
    ["o", "cause", 4]
]

# Multiplier/ divider FU only signal
dec_md_t = [
    ["o", "md_op", 3],
    ["o", "muldiv"]
]

# Issue logic only signal
dec_ix_t = [
    ["o", "legal"],
    ["o", "fencei"],
    ["o", "page_fault"]
]

dec_instr_t = dec_common_t + dec_int_t + dec_ls_t + dec_csr_t + dec_md_t + dec_ix_t

ix_ip_t = [
    ["o", "pc", 64],
    ["o", "dst", 5],
    ["o", "wb_en"],
    ["o", "op", 4],
    ["o", "option"],
    ["o", "truncate"],
    ["o", "br_type", 2],
    ["o", "br_neg"],
    ["o", "br_base", 64],
    ["o", "br_offset", 21],
    ["o", "br_is_call"],
    ["o", "br_is_ret"],
    ["o", "operand1", 64],
    ["o", "operand2", 64],
    ["o", "bp"],
    ["o", "bp_track", 2],
    ["o", "bt", 64],
    ["o", "speculate"]
]

rf_rd_t = [
    ["i", "rsrc", 5],
    ["o", "rdata", 64]
]

rf_wr_t = [
    ["i", "wen"],
    ["i", "wdst", 5],
    ["i", "wdata", 64]
]

wb_t = [
    ["o", "dst", 5],
    ["o", "result", 64],
    ["o", "wb_en"],
    ["o", "valid"]
]

ix_md_t = [
    ["o", "pc", 64],
    ["o", "dst", 5],
    ["o", "operand1", 64],
    ["o", "operand2", 64],
    ["o", "md_op", 3],
    ["o", "muldiv"],
    ["o", "speculate"]
]

ip_if_t = [
    ["o", "branch"],
    ["o", "branch_taken"],
    ["o", "branch_pc", 64],
    ["o", "branch_is_call"],
    ["o", "branch_is_ret"],
    ["o", "branch_track", 2],
    ["o", "pc_override"],
    ["o", "new_pc", 64]
]

ix_lsp_t = [
    ["o", "pc", 64],
    ["o", "dst", 5],
    ["o", "wb_en"],
    ["o", "base", 64],
    ["o", "offset", 12],
    ["o", "source", 64],
    ["o", "mem_sign"],
    ["o", "mem_width", 2],
    ["o", "speculate"]
]

ix_trap_t = [
    ["o", "pc", 64],
    ["o", "dst", 5],
    ["o", "csr_op", 2],
    ["o", "csr_id", 12],
    ["o", "csr_opr", 64],
    ["o", "mret"],
    ["o", "int"],
    ["o", "intexc"],
    ["o", "cause", 4],
]

romem_if_t = [
    ["o", "req_addr", 64],
    ["o", "req_valid"],
    ["i", "req_ready"],
    ["i", "resp_rdata", 64],
    ["i", "resp_valid"]
]

rwmem_if_t = [
    ["o", "req_addr", 64],
    ["o", "req_wdata", 64],
    ["o", "req_wmask", 8],
    ["o", "req_wen"],
    ["o", "req_valid"],
    ["i", "req_ready"],
    ["i", "resp_rdata", 64],
    ["i", "resp_valid"]
]

du_rob_t = [
    ["i", "rd", 5],
    ["i", "wb_en"],
    ["i", "oprn", 6],
    ["o", "tag", ROB_ABITS],
    ["i", "valid"]
]
