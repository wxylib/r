library(wxy)

## geotransform: 10 x 5 cells over 0..10, 0..5
gt <- wxy_affine(c(0, 10, 0, 5), c(10, 5))
stopifnot(identical(gt, c(0, 1, 0, 5, 0, -1)))
stopifnot(inherits(try(wxy_affine(1:3, c(1, 1)), silent = TRUE), "try-error"))

## cell centres of a 1-degree global grid, as a netCDF file might store them
lon <- seq(-179.5, 179.5, by = 1)
r <- wxy_regular(lon)
stopifnot(isTRUE(r$regular), r$origin == -180, r$step == 1)

## the same, rounded to float32 storage, is still regular at float32 tolerance
lon32 <- lon + c(0, 1e-6, rep(0, length(lon) - 2))
stopifnot(isTRUE(wxy_regular(lon32)$regular))
stopifnot(!isTRUE(wxy_regular(lon32, tolerance = "float64")$regular))

## a stretched axis is not
stopifnot(!isTRUE(wxy_regular(c(0, 1, 2, 4, 8))$regular))

## edges: n + 1 values
e <- wxy_regular(seq(0, 10, by = 2), cell = "edge")
stopifnot(isTRUE(e$regular), e$origin == 0, e$step == 2)

## warp: a 2 x 2 matrix onto itself is the identity (nearest)
m <- matrix(c(1, 2, 3, 4), 2, 2, byrow = TRUE)
w <- wxy_warp(m, c(0, 2, 0, 2), "EPSG:4326", c(0, 2, 0, 2), c(2, 2), "EPSG:4326")
stopifnot(identical(w, m))

## and a flip of the target extent's half picks out the right cells:
## the north-west cell of m is 1
w1 <- wxy_warp(m, c(0, 2, 0, 2), "EPSG:4326", c(0, 1, 1, 2), c(1, 1), "EPSG:4326")
stopifnot(w1[1, 1] == 1)

## lon/lat to south polar stereographic: the four cells around the pole
## take the southernmost row
z <- outer(seq(89.5, -89.5), seq(-179.5, 179.5), function(la, lo) la)
p <- wxy_warp(z, c(-180, 180, -90, 90), "EPSG:4326",
              c(-5e6, 5e6, -5e6, 5e6), c(100, 100),
              "+proj=stere +lat_0=-90 +lat_ts=-71 +datum=WGS84")
stopifnot(dim(p) == c(100, 100), all(p[50:51, 50:51] == -89.5), !anyNA(p))

## an odd size puts a column of cell centres on the antimeridian (lon 180,
## just past the source edge) and one cell exactly on the pole; a global
## source wraps in longitude and reads the edge row at the pole, so no cell
## is missing, with either kernel
for (k in c("near", "bilinear")) {
  p <- wxy_warp(z, c(-180, 180, -90, 90), "EPSG:4326",
                c(-5e6, 5e6, -5e6, 5e6), c(101, 101),
                "+proj=stere +lat_0=-90 +lat_ts=-71 +datum=WGS84", k)
  stopifnot(!anyNA(p), abs(p[51, 51] + 89.5) < 1e-9)
}

## a CRS proj4rs cannot parse is a plain R error
e <- try(wxy_warp(m, c(0, 2, 0, 2), "EPSG:4326", c(0, 2, 0, 2), c(2, 2),
                  "+proj=nonsense"), silent = TRUE)
stopifnot(inherits(e, "try-error"))
