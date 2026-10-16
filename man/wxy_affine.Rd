\name{wxy_affine}
\alias{wxy_affine}
\title{Geotransform from an extent and dimension}
\usage{
wxy_affine(extent, dim)
}
\arguments{
\item{extent}{\code{c(xmin, xmax, ymin, ymax)}}
\item{dim}{\code{c(ncol, nrow)}}
}
\description{
Geotransform for a north-up grid, from the 'wxy-domain' Rust crate.
}
\value{
Six numbers \code{c(x0, dx, rx, y0, ry, dy)}, north up.
}
\examples{
wxy_affine(c(0, 10, 0, 5), c(10, 5))
}
