//! A minimal spike of R bindings to wxylib: two functions from wxy-domain
//! and one from wxy-warp. All pure Rust: no I/O, no C libraries, and CRS
//! work through rwarp's proj4rs backend.

use extendr_api::prelude::*;
use extendr_api::Result;
use wxy_domain::affine::Affine;
use wxy_domain::mapping::CellConvention;
use wxy_domain::normalise::{regular_axis, Tolerance};
use wxy_domain::positions::Positions;
use wxy_domain::{DataType, Dim, Domain, Frame, Mapping};
use wxy_source::{Chunk, ChunkGrid, ChunkKey, ChunkSource, Encoded, Values};
use wxy_warp::{GridSpec, ResampleAlg, WarpOptions};

/// An R matrix as a one-chunk source: values in C order (row 0 north).
struct Memory {
    grid: ChunkGrid,
    values: Vec<f64>,
}

#[async_trait::async_trait]
impl ChunkSource for Memory {
    fn grid(&self) -> &ChunkGrid {
        &self.grid
    }
    fn dtype(&self) -> DataType {
        DataType::F64
    }
    async fn fetch(&self, keys: &[ChunkKey]) -> wxy_source::Result<Vec<Encoded>> {
        Ok(keys
            .iter()
            .map(|k| Encoded {
                key: k.clone(),
                payload: Box::new(()),
            })
            .collect())
    }
    fn decode(&self, e: Encoded) -> wxy_source::Result<Chunk> {
        Ok(Chunk {
            window: self.grid.window(&e.key),
            key: e.key,
            stored: self.grid.shape.clone(),
            values: Values::F64(self.values.clone()),
        })
    }
}

fn err(e: impl std::fmt::Display) -> Error {
    Error::Other(e.to_string())
}

/// Errors go back to R as `list(error = message)` for the R wrapper to
/// raise, so a bad CRS string is a plain R error and not a Rust panic.
fn to_r<T: Into<Robj>>(r: Result<T>) -> Robj {
    match r {
        Ok(v) => v.into(),
        Err(Error::Other(m)) => list!(error = m).into(),
        Err(e) => list!(error = e.to_string()).into(),
    }
}

/// Geotransform `[x0, dx, rx, y0, ry, dy]` for an extent
/// `[xmin, xmax, ymin, ymax]` and dimension `[ncol, nrow]`, north up.
fn wxy_affine_inner(extent: &[f64], dim: &[f64]) -> Result<Vec<f64>> {
    if extent.len() != 4 || dim.len() != 2 {
        return Err(Error::Other(
            "extent must have 4 values and dim 2 values".into(),
        ));
    }
    if dim
        .iter()
        .any(|d| !d.is_finite() || *d < 1.0 || d.fract() != 0.0)
    {
        return Err(Error::Other(
            "dim must be two positive whole numbers".into(),
        ));
    }
    let dim = [dim[0] as usize, dim[1] as usize];
    let a = Affine::from_extent([extent[0], extent[1], extent[2], extent[3]], dim);
    Ok(a.0.to_vec())
}

#[extendr]
fn wxy_affine_impl(extent: &[f64], dim: &[f64]) -> Robj {
    to_r(wxy_affine_inner(extent, dim))
}

/// Test whether a coordinate vector is evenly spaced (the R2 -> R1 test of
/// the position ladder). `tolerance` is "float32", "float64", or a number
/// (an absolute distance in the coordinates' units).
fn wxy_regular_inner(x: &[f64], cell: &str, tolerance: Robj) -> Result<List> {
    let cell = match cell {
        "centre" | "center" => CellConvention::Centre,
        "edge" => CellConvention::Edge,
        other => return Err(Error::Other(format!("unknown cell convention '{other}'"))),
    };
    let tolerance = if let Some(s) = tolerance.as_str() {
        match s {
            "float32" => Tolerance::Float32,
            "float64" => Tolerance::Float64,
            other => return Err(Error::Other(format!("unknown tolerance '{other}'"))),
        }
    } else if let Some(t) = tolerance.as_real() {
        Tolerance::Absolute(t)
    } else {
        return Err(Error::Other(
            "tolerance must be \"float32\", \"float64\" or a number".into(),
        ));
    };
    let (found, report) = regular_axis(x, cell, tolerance);
    let (origin, step) = match found {
        Some(Positions::Regular1 { origin, step }) => (origin, step),
        _ => (f64::NAN, f64::NAN),
    };
    Ok(list!(
        regular = report.accepted,
        origin = origin,
        step = step,
        max_deviation = report.max_deviation,
        max_deviation_steps = report.max_deviation_steps,
        tolerance = report.tolerance,
        report = report.to_string()
    ))
}

#[extendr]
fn wxy_regular_impl(x: &[f64], cell: &str, tolerance: Robj) -> Robj {
    to_r(wxy_regular_inner(x, cell, tolerance))
}

/// Warp `values` (C order, `nrow` x `ncol`, row 0 north) on `extent` in
/// `crs` to a grid of `dim` cells over `dst_extent` in `dst_crs`. Returns
/// the target values in C order; cells nothing maps to are NaN.
#[allow(clippy::too_many_arguments)]
fn wxy_warp_inner(
    values: Vec<f64>,
    ncol: f64,
    nrow: f64,
    extent: &[f64],
    crs: &str,
    dst_extent: &[f64],
    dst_dim: &[f64],
    dst_crs: &str,
    resample: &str,
) -> Result<Vec<f64>> {
    if extent.len() != 4 || dst_extent.len() != 4 || dst_dim.len() != 2 {
        return Err(err("extents need 4 values and dim 2 values"));
    }
    let (ncol, nrow) = (ncol as usize, nrow as usize);
    if values.len() != ncol * nrow {
        return Err(err("values do not match the matrix dimension"));
    }
    let resampling = match resample {
        "near" => ResampleAlg::NearestNeighbour,
        "bilinear" => ResampleAlg::Bilinear,
        "cubic" => ResampleAlg::Cubic,
        "lanczos" => ResampleAlg::Lanczos,
        other => return Err(err(format!("unknown resampling '{other}'"))),
    };
    let src_affine =
        Affine::from_extent([extent[0], extent[1], extent[2], extent[3]], [ncol, nrow]);
    let mut domain = Domain::new(vec![Dim::new("y", nrow as u64), Dim::new("x", ncol as u64)]);
    domain.add_mapping(Mapping::new(
        vec![0, 1],
        Positions::Affine(src_affine),
        Frame::crs(crs),
    ));
    let source = Memory {
        grid: ChunkGrid::new(
            vec![nrow as u64, ncol as u64],
            vec![nrow as u64, ncol as u64],
        ),
        values,
    };
    let dst = GridSpec::from_extent(
        dst_crs,
        [dst_extent[0], dst_extent[1], dst_extent[2], dst_extent[3]],
        [dst_dim[0] as usize, dst_dim[1] as usize],
    );
    let opts = WarpOptions {
        resampling,
        nodata: Some(f64::NAN),
        ..Default::default()
    };
    let out = futures::executor::block_on(wxy_warp::warp(&source, &domain, &dst, &opts, None))
        .map_err(err)?;
    match out.values {
        Values::F64(v) => Ok(v),
        _ => Err(err("unexpected output type")),
    }
}

#[extendr]
#[allow(clippy::too_many_arguments)]
fn wxy_warp_impl(
    values: Vec<f64>,
    ncol: f64,
    nrow: f64,
    extent: &[f64],
    crs: &str,
    dst_extent: &[f64],
    dst_dim: &[f64],
    dst_crs: &str,
    resample: &str,
) -> Robj {
    to_r(wxy_warp_inner(
        values, ncol, nrow, extent, crs, dst_extent, dst_dim, dst_crs, resample,
    ))
}

extendr_module! {
    mod wxy;
    fn wxy_affine_impl;
    fn wxy_regular_impl;
    fn wxy_warp_impl;
}
