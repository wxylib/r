// The Rust static library registers its routines through this symbol.
void R_init_wxy_extendr(void *dll);

void R_init_wxy(void *dll) {
    R_init_wxy_extendr(dll);
}
