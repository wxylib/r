## Make man/figures/warp.png for the README. Run from the package root
## with wxy installed: Rscript tools/readme-figure.R
library(wxy)

## A global lon/lat grid at 0.5 degrees: a checkerboard of 15-degree cells
## with a wave on top, so every curve in the warped panels is a graticule
## line.
lon <- seq(-179.75, 179.75, by = 0.5)
lat <- seq(89.75, -89.75, by = -0.5)
z <- outer(lat, lon, function(la, lo) {
  ((floor(la / 15) + floor(lo / 15)) %% 2) +
    0.35 * sin(lo * pi / 30) * cos(la * pi / 30)
})
ll <- c(-180, 180, -90, 90)

targets <- list(
  list(title = "Mollweide",
       crs = "+proj=moll +datum=WGS84",
       extent = c(-1.81e7, 1.81e7, -9.1e6, 9.1e6), dim = c(720, 360)),
  list(title = "North polar Lambert azimuthal",
       crs = "+proj=laea +lat_0=90 +lon_0=0 +datum=WGS84",
       extent = c(-9e6, 9e6, -9e6, 9e6), dim = c(480, 480)),
  list(title = "South polar stereographic (EPSG:3031 parameters)",
       crs = "+proj=stere +lat_0=-90 +lat_ts=-71 +lon_0=0 +datum=WGS84",
       extent = c(-6e6, 6e6, -6e6, 6e6), dim = c(480, 480))
)

## image() draws matrix rows along x, so flip a north-up matrix for it.
show <- function(m, title) {
  image(t(m[nrow(m):1, ]), col = hcl.colors(64, "Viridis"), asp = nrow(m) / ncol(m),
        axes = FALSE, useRaster = TRUE)
  title(title, cex.main = 1.1, font.main = 1)
}

png("man/figures/warp.png", width = 1600, height = 1000, res = 130)
op <- par(mfrow = c(2, 2), mar = c(0.5, 0.5, 2, 0.5), bg = "white")
show(z, "Source: longitude/latitude, 720 x 360")
for (tg in targets) {
  w <- wxy_warp(z, ll, "EPSG:4326", tg$extent, tg$dim, tg$crs, "bilinear")
  show(w, tg$title)
}
par(op)
dev.off()
