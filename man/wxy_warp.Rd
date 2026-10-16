\name{wxy_warp}
\alias{wxy_warp}
\title{Warp a matrix to another grid}
\usage{
wxy_warp(x, extent, crs, dst_extent, dst_dim, dst_crs,
         resample = c("near", "bilinear", "cubic", "lanczos"))
}
\arguments{
\item{x}{numeric matrix, row 1 at the north edge (as \code{raster::as.matrix}
gives it)}
\item{extent}{\code{c(xmin, xmax, ymin, ymax)} of \code{x}}
\item{crs}{CRS of \code{x}: an EPSG code such as \code{"EPSG:4326"} or a
PROJ string}
\item{dst_extent}{\code{c(xmin, xmax, ymin, ymax)} of the target grid}
\item{dst_dim}{\code{c(ncol, nrow)} of the target grid}
\item{dst_crs}{CRS of the target grid}
\item{resample}{resampling kernel}
}
\value{
A matrix of \code{dst_dim[2]} rows and \code{dst_dim[1]} columns, row 1 at
the north edge. Cells nothing maps to are \code{NaN}.
}
\description{
Warps values onto a target grid with the 'wxy-warp' Rust crate (which
uses 'rwarp'). CRS work is pure Rust ('proj4rs'): EPSG codes and PROJ
strings for the projections 'proj4rs' supports, no datum grids.
}
\examples{
z <- outer(seq(89.5, -89.5), seq(-179.5, 179.5), function(la, lo) la + lo / 10)
w <- wxy_warp(z, c(-180, 180, -90, 90), "EPSG:4326",
              c(-5e6, 5e6, -5e6, 5e6), c(100, 100),
              "+proj=stere +lat_0=-90 +lat_ts=-71 +datum=WGS84")
dim(w)
}
