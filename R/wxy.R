.wxy_call <- function(...) {
  r <- .Call(...)
  if (is.list(r) && identical(names(r), "error")) stop(r$error, call. = FALSE)
  r
}


wxy_affine <- function(extent, dim) {
  .wxy_call(wrap__wxy_affine_impl, as.double(extent), as.double(dim))
}

wxy_regular <- function(x, cell = c("centre", "edge"), tolerance = "float32") {
  cell <- match.arg(cell)
  if (is.numeric(tolerance)) tolerance <- as.double(tolerance)
  .wxy_call(wrap__wxy_regular_impl, as.double(x), cell, tolerance)
}

wxy_warp <- function(x, extent, crs, dst_extent, dst_dim, dst_crs,
                     resample = c("near", "bilinear", "cubic", "lanczos")) {
  resample <- match.arg(resample)
  x <- as.matrix(x)
  v <- .wxy_call(wrap__wxy_warp_impl, as.double(t(x)), as.double(ncol(x)),
             as.double(nrow(x)), as.double(extent), as.character(crs),
             as.double(dst_extent), as.double(dst_dim), as.character(dst_crs),
             resample)
  matrix(v, nrow = dst_dim[2], ncol = dst_dim[1], byrow = TRUE)
}
