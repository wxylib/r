\name{wxy_regular}
\alias{wxy_regular}
\title{Is a coordinate vector regular?}
\usage{
wxy_regular(x, cell = c("centre", "edge"), tolerance = "float32")
}
\arguments{
\item{x}{numeric coordinate vector}
\item{cell}{\code{"centre"} if \code{x} holds cell centres (n values),
\code{"edge"} if it holds cell edges (n + 1 values)}
\item{tolerance}{\code{"float32"}, \code{"float64"}, or an absolute distance}
}
\value{
A list: \code{regular}, \code{origin} (position at index 0, the outer edge
of the first cell), \code{step}, the largest deviation from the fitted line
(in units and in steps), the tolerance applied, and a one-line \code{report}.
}
\description{
Tests whether stored coordinates are evenly spaced within a tolerance,
using the normalise step of the 'wxy-domain' Rust crate.
}
\examples{
wxy_regular(seq(-179.5, 179.5, by = 1))
wxy_regular(c(0, 1, 2, 4, 8))
}
