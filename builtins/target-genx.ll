;;  Copyright (c) 2019, Intel Corporation
;;  All rights reserved.
;;
;;  Redistribution and use in source and binary forms, with or without
;;  modification, are permitted provided that the following conditions are
;;  met:
;;
;;    * Redistributions of source code must retain the above copyright
;;      notice, this list of conditions and the following disclaimer.
;;
;;    * Redistributions in binary form must reproduce the above copyright
;;      notice, this list of conditions and the following disclaimer in the
;;      documentation and/or other materials provided with the distribution.
;;
;;    * Neither the name of Intel Corporation nor the names of its
;;      contributors may be used to endorse or promote products derived from
;;      this software without specific prior written permission.
;;
;;
;;   THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
;;   IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
;;   TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
;;   PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER
;;   OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
;;   EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
;;   PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
;;   PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
;;   LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
;;   NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
;;   SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

target datalayout = "e-p:32:32-i64:64-n8:16:32";

define(`WIDTH',`16')
define(`MASK',`i1')
define(`HAVE_GATHER',`1')
define(`HAVE_SCATTER',`1')
include(`util-genx.m4')

define(`CONCAT',`$1$2')
define(`GEN_TYPE',
`ifelse($1, `i1', `i1',
        $1, `i8', `i8',
        $1, `i16', `i16',
        $1, `i32', `i32',
        $1, `float', `f32',
        $1, `double', `f64',
        $1, `i64', `i64')')

define(`GEN_SUFFIX',`CONCAT(`v16', GEN_TYPE($1))')

define(`SIZEOF',
`ifelse($1, `i1', 1,
        $1, `i8', 1,
        $1, `i16', 2,
        $1, `i32', 4,
        $1, `float', 4,
        $1, `double', 8,
        $1, `i64', 8)')

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

stdlib_core()
packed_load_and_store()
scans()
ctlztz()
define_prefetches()
define_shuffles()
aossoa()
rdrand_decls()

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; rounding floats

declare float @llvm.genx.rndd.f32(float)
declare float @llvm.genx.rndu.f32(float)
declare <16 x float> @llvm.genx.rndu.GEN_SUFFIX(float)(<16 x float>)
declare <16 x float> @llvm.genx.rndd.GEN_SUFFIX(float)(<16 x float>)


define float @__floor_uniform_float(float) nounwind readonly alwaysinline {
    %res = call float @llvm.genx.rndd.f32(float %0)
    ret float %res
}

define float @__ceil_uniform_float(float) nounwind readonly alwaysinline {
    %res = call float @llvm.genx.rndu.f32(float %0)
    ret float %res
}

define float @__round_uniform_float(float) nounwind readonly alwaysinline {
  %float_to_int_bitcast.i.i.i.i = bitcast float %0 to i32
  %bitop.i.i = and i32 %float_to_int_bitcast.i.i.i.i, -2147483648
  %bitop.i = xor i32 %float_to_int_bitcast.i.i.i.i, %bitop.i.i
  %int_to_float_bitcast.i.i40.i = bitcast i32 %bitop.i to float
  %binop.i = fadd float %int_to_float_bitcast.i.i40.i, 8.388608e+06
  %binop21.i = fadd float %binop.i, -8.388608e+06
  %float_to_int_bitcast.i.i.i = bitcast float %binop21.i to i32
  %bitop31.i = xor i32 %float_to_int_bitcast.i.i.i, %bitop.i.i
  %int_to_float_bitcast.i.i.i = bitcast i32 %bitop31.i to float
  ret float %int_to_float_bitcast.i.i.i
}

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; rounding doubles

define double @__round_uniform_double(double) nounwind readonly alwaysinline {
  %float_to_int_bitcast.i.i.i.i = bitcast double %0 to i64
  %bitop.i.i = and i64 %float_to_int_bitcast.i.i.i.i, -9223372036854775808
  %bitop.i = xor i64 %float_to_int_bitcast.i.i.i.i, %bitop.i.i
  %int_to_float_bitcast.i.i40.i = bitcast i64 %bitop.i to double
  %binop.i = fadd double %int_to_float_bitcast.i.i40.i, 4.5036e+15
  %binop21.i = fadd double %binop.i, -4.5036e+15
  %float_to_int_bitcast.i.i.i = bitcast double %binop21.i to i64
  %bitop31.i = xor i64 %float_to_int_bitcast.i.i.i, %bitop.i.i
  %int_to_float_bitcast.i.i.i = bitcast i64 %bitop31.i to double
  ret double %int_to_float_bitcast.i.i.i
}

define double @__floor_uniform_double(double) nounwind readonly alwaysinline {
  %calltmp.i = tail call double @__round_uniform_double(double %0) nounwind
  %bincmp.i = fcmp ogt double %calltmp.i, %0
  %val_to_boolvec32.i = sext i1 %bincmp.i to i64
  %bitop.i = and i64 %val_to_boolvec32.i, -4616189618054758400
  %int_to_float_bitcast.i.i.i = bitcast i64 %bitop.i to double
  %binop.i = fadd double %calltmp.i, %int_to_float_bitcast.i.i.i
  ret double %binop.i
}

define double @__ceil_uniform_double(double) nounwind readonly alwaysinline {
  %calltmp.i = tail call double @__round_uniform_double(double %0) nounwind
  %bincmp.i = fcmp olt double %calltmp.i, %0
  %val_to_boolvec32.i = sext i1 %bincmp.i to i64
  %bitop.i = and i64 %val_to_boolvec32.i, 4607182418800017408
  %int_to_float_bitcast.i.i.i = bitcast i64 %bitop.i to double
  %binop.i = fadd double %calltmp.i, %int_to_float_bitcast.i.i.i
  ret double %binop.i
}


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; rcp

define float @__rcp_uniform_float(float) nounwind readonly alwaysinline {
  %mid_res = fdiv float 1., %0
  ;; do one N-R iteration to improve precision
  ;; return (2. - v * r) * r;
  %mult = fmul float %0, %mid_res
  %two_minus = fsub float 2., %mult
  %res = fmul float %mid_res, %two_minus
  ret float %res
}

define float @__rcp_fast_uniform_float(float) nounwind readonly alwaysinline {
  %res = fdiv float 1., %0
  ret float %res
}

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; rsqrt

declare float @llvm.genx.rsqrt.float.f32(float)
define float @__rsqrt_uniform_float(float %v) nounwind readonly alwaysinline {
  %r = call float @llvm.genx.rsqrt.float.f32(float %v)
  ;; Newton-Raphson iteration to improve precision
  ;;  return 0.5 * r * (3. - (v * r) * r);
  %mult = fmul float %v, %r
  %mult2 = fmul float %mult, %r
  %three_sub = fsub float 3., %mult2
  %mult3 = fmul float %r, %three_sub
  %res = fmul float 0.5, %mult3
  ret float %res
}

define float @__rsqrt_fast_uniform_float(float) nounwind readonly alwaysinline {
  %res = call float @llvm.genx.rsqrt.float.f32(float %0)
  ret float %res
}

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; sqrt

declare float @llvm.genx.sqrt.f32(float)
define float @__sqrt_uniform_float(float) nounwind readonly alwaysinline {
  %res = call float @llvm.genx.sqrt.f32(float %0)
  ret float %res
}

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; double precision sqrt

declare double @llvm.genx.ieee.sqrt.d64(double)
define double @__sqrt_uniform_double(double) nounwind alwaysinline {
  %res = call double @llvm.genx.ieee.sqrt.d64(double %0)
  ret double %res
}

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; fast math mode

;; In CPU fastmath set FTZ (flush-to-zero) and DAZ (denormals-are-zero)
;; GenX CM have per kernel setting of CM_DENORM_RTZ (Set all denorms to zero) - applied as attribute to kernel function; enabled by default
;; So in GenX fastmath enabled by default
define void @__fastmath() nounwind alwaysinline {
  ret void
}

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; min/max
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; double precision min/max

define double @__min_uniform_double(double, double) nounwind readnone alwaysinline {
  %pred = fcmp olt double %0, %1
  %res = select i1 %pred, double %0, double %1
  ret double %res
}

define double @__max_uniform_double(double, double) nounwind readnone alwaysinline {
  %pred = fcmp ogt double %0, %1
  %res = select i1 %pred, double %0, double %1
  ret double %res
}

define <16 x double> @__min_varying_double(<16 x double>, <16 x double>) nounwind readnone {
  %pred = fcmp olt <16 x double> %0, %1
  %res = select <16 x i1> %pred, <16 x double> %0, <16 x double> %1
  ret <16 x double> %res
}

define <16 x double> @__max_varying_double(<16 x double>, <16 x double>) nounwind readnone {
  %pred = fcmp ogt <16 x double> %0, %1
  %res = select <16 x i1> %pred, <16 x double> %0, <16 x double> %1
  ret <16 x double> %res
}

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Generates max/min builtins for unfiorm and varying
;; $1 LLVM IR type
;; $2 gen intrinsic min name
;; $3 gen intrinsic max name
;; $4 type-based builtin suffix
define(`genx_maxmin', `
declare $1 @llvm.genx.$2.GEN_TYPE($1).GEN_TYPE($1)($1, $1)
declare $1 @llvm.genx.$3.GEN_TYPE($1).GEN_TYPE($1)($1, $1)
declare <WIDTH x $1> @llvm.genx.$2.GEN_SUFFIX($1).GEN_SUFFIX($1)(<WIDTH x $1>, <WIDTH x $1>)
declare <WIDTH x $1> @llvm.genx.$3.GEN_SUFFIX($1).GEN_SUFFIX($1)(<WIDTH x $1>, <WIDTH x $1>)

define $1 @__max_uniform_$4($1, $1) nounwind readonly alwaysinline {
  %res = call $1 @llvm.genx.$3.GEN_TYPE($1).GEN_TYPE($1)($1 %0, $1 %1)
  ret $1 %res
}

define $1 @__min_uniform_$4($1, $1) nounwind readonly alwaysinline {
  %res = call $1 @llvm.genx.$2.GEN_TYPE($1).GEN_TYPE($1)($1 %0, $1 %1)
  ret $1 %res
}

define <WIDTH x $1> @__max_varying_$4(<WIDTH x $1>, <WIDTH x $1>) nounwind readonly alwaysinline {
  %res = call <WIDTH x $1> @llvm.genx.$3.GEN_SUFFIX($1).GEN_SUFFIX($1)(<WIDTH x $1> %0, <WIDTH x $1> %1)
  ret <WIDTH x $1> %res
}

define <WIDTH x $1> @__min_varying_$4(<WIDTH x $1>, <WIDTH x $1>) nounwind readonly alwaysinline {
  %res = call <WIDTH x $1> @llvm.genx.$2.GEN_SUFFIX($1).GEN_SUFFIX($1)(<WIDTH x $1> %0, <WIDTH x $1> %1)
  ret <WIDTH x $1> %res
}
')
genx_maxmin(float, fmin, fmax, float)
genx_maxmin(i32, smin, smax, int32)
genx_maxmin(i64, smin, smax, int64)
genx_maxmin(i32, umin, umax, uint32)
genx_maxmin(i64, umin, umax, uint64)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; horizontal ops / reductions

declare i32 @llvm.genx.cbit.i32 (i32)

define i32 @__popcnt_int32(i32) nounwind readonly alwaysinline {
  %c = call i32 @llvm.genx.cbit.i32 (i32 %0)
  ret i32 %c
}

define i64 @__popcnt_int64(i64) nounwind readonly alwaysinline {
  %lo = trunc i64 %0 to i32
  %hi.init = lshr i64 %0, 32
  %hi = trunc i64 %hi.init to i32
  %lo.cbit = call i32 @llvm.genx.cbit.i32 (i32 %lo)
  %hi.cbit = call i32 @llvm.genx.cbit.i32 (i32 %hi)
  %res.32 = add i32 %lo.cbit, %hi.cbit
  %res = zext i32 %res.32 to i64
  ret i64 %res
}

declare_nvptx()

declare i32 @llvm.genx.group.id.x()
declare i32 @llvm.genx.group.id.y()
declare i32 @llvm.genx.group.id.z()
declare <3 x i32> @llvm.genx.local.id.v3i32()
declare <3 x i32> @llvm.genx.group.count.v3i32()
declare <3 x i32> @llvm.genx.local.size.v3i32()

define i32 @__task_index()  nounwind readnone alwaysinline {
;; linear_group_id() * linear_local_size() + linear_local_id();
;; linear_group_id = group_count(0) * group_count(1) * group_id(2) +
;;                   group_count(0) * group_id(1) + group_id(0);
;; linear_local_size = local_size(0) * local_size(1) * local_size(2);
;; linear_local_id = local_size(0) * local_size(1) * local_id(2) +
;;                   local_size(0) * local_id(1) + local_id(0);
;; linear_group_id
  %gr_id_x = call i32 @llvm.genx.group.id.x()
  %gr_id_y = call i32 @llvm.genx.group.id.y()
  %gr_id_z = call i32 @llvm.genx.group.id.z()
  %gr_count = call <3 x i32> @llvm.genx.group.count.v3i32()
  %gr_count_x = extractelement <3 x i32> %gr_count, i32 0
  %gr_count_y = extractelement <3 x i32> %gr_count, i32 1
  %gr_count_z = extractelement <3 x i32> %gr_count, i32 2
  %gr_count_xy = mul i32 %gr_count_x, %gr_count_y
  %gr_count_xy_z = mul i32 %gr_count_xy, %gr_id_z
  %gr_count_x_y = mul i32 %gr_count_x, %gr_id_y
  %gr_id_temp = add i32 %gr_count_x_y, %gr_count_xy_z
  %gr_id = add i32 %gr_id_temp, %gr_id_x

;; linear_local_size
  %l_size = call <3 x i32> @llvm.genx.local.size.v3i32()
  %l_size_x = extractelement <3 x i32> %l_size, i32 0
  %l_size_y = extractelement <3 x i32> %l_size, i32 1
  %l_size_z = extractelement <3 x i32> %l_size, i32 2
  %l_size_xy = mul i32 %l_size_x, %l_size_y
  %l_size_xyz = mul i32 %l_size_xy, %l_size_z

;; linear_local_id
  %l_id = call <3 x i32> @llvm.genx.local.id.v3i32()
  %l_id_x = extractelement <3 x i32> %l_id, i32 0
  %l_id_y = extractelement <3 x i32> %l_id, i32 1
  %l_id_z = extractelement <3 x i32> %l_id, i32 2
  %l_is_z_size = mul i32 %l_size_xy, %l_id_z
  %l_is_y_size = mul i32 %l_size_x, %l_id_y
  %l_is_yz_size = add i32 %l_is_z_size, %l_is_y_size
  %l_local_id = add i32 %l_is_yz_size, %l_id_x

  %res_temp = mul i32 %gr_id, %l_size_xyz
  %res = add i32 %res_temp, %l_local_id
  ret i32 %res
}

define i32 @__task_count()  nounwind readnone alwaysinline {
;; linear_group_count * linear_local_size
;; linear_group_count = group_count(0) * group_count(1) * group_count(2);
;; linear_local_size = local_size(0) * local_size(1) * local_size(2);
;; linear_local_size
  %l_size = call <3 x i32> @llvm.genx.local.size.v3i32()
  %l_size_x = extractelement <3 x i32> %l_size, i32 0
  %l_size_y = extractelement <3 x i32> %l_size, i32 1
  %l_size_z = extractelement <3 x i32> %l_size, i32 2
  %l_size_xy = mul i32 %l_size_x, %l_size_y
  %l_size_xyz = mul i32 %l_size_xy, %l_size_z
;; linear_group_count
  %gr_count = call <3 x i32> @llvm.genx.group.count.v3i32()
  %gr_count_x = extractelement <3 x i32> %gr_count, i32 0
  %gr_count_y = extractelement <3 x i32> %gr_count, i32 1
  %gr_count_z = extractelement <3 x i32> %gr_count, i32 2
  %gr_count_xy = mul i32 %gr_count_x, %gr_count_y
  %gr_count_xyz = mul i32 %gr_count_xy, %gr_count_z
;; linear_group_count * linear_local_size
  %res = mul i32 %l_size_xyz, %gr_count_xyz
  ret i32 %res
}

define(`__genx_task_count', `
  %l_size = call <3 x i32> @llvm.genx.local.size.v3i32()
  %l_size_v = extractelement <3 x i32> %l_size, i32 $1
  %gr_count = call <3 x i32> @llvm.genx.group.count.v3i32()
  %gr_count_v = extractelement <3 x i32> %gr_count, i32 $1
  %res = mul i32 %l_size_v, %gr_count_v
  ret i32 %res
')

define i32 @__task_count0()  nounwind readnone alwaysinline {
   __genx_task_count(0)
}

define i32 @__task_count1()  nounwind readnone alwaysinline {
  __genx_task_count(1)
}

define i32 @__task_count2()  nounwind readnone alwaysinline {
  __genx_task_count(2)
}

define(`__genx_task_index', `
  %gr_id_v = call i32 @llvm.genx.group.id.$2()
  %l_id = call <3 x i32> @llvm.genx.local.id.v3i32()
  %l_id_v = extractelement <3 x i32> %l_id, i32 $1
  %l_size = call <3 x i32> @llvm.genx.local.size.v3i32()
  %l_size_v = extractelement <3 x i32> %l_size, i32 $1
  %res_tmp = mul i32 %gr_id_v, %l_size_v
  %res = add i32 %res_tmp, %l_id_v
  ret i32 %res
')

define i32 @__task_index0()  nounwind readnone alwaysinline {
   __genx_task_index(0, x)
}

define i32 @__task_index1()  nounwind readnone alwaysinline {
   __genx_task_index(1, y)
}

define i32 @__task_index2()  nounwind readnone alwaysinline {
   __genx_task_index(2, z)
}

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; half conversion routines

define float @__half_to_float_uniform(i16 %v) nounwind readnone {
  %hf = bitcast i16 %v to half
  %ft = fpext half %hf to float
  ret float %ft
}

define <WIDTH x float> @__half_to_float_varying(<WIDTH x i16> %v) nounwind readnone {
  %hf = bitcast <WIDTH x i16> %v to <WIDTH x half>
  %ft = fpext <WIDTH x half> %hf to <WIDTH x float>
  ret <WIDTH x float> %ft
}

define i16 @__float_to_half_uniform(float %v) nounwind readnone {
  %hf = fptrunc float %v to half
  %hf.bitcast = bitcast half %hf to i16
  ret i16 %hf.bitcast
}

define <WIDTH x i16> @__float_to_half_varying(<WIDTH x float> %v) nounwind readnone {
  %hf = fptrunc <WIDTH x float> %v to <WIDTH x half>
  %hf.bitcast = bitcast <WIDTH x half> %hf to <WIDTH x i16>
  ret <WIDTH x i16> %hf.bitcast
}

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; rcp

define <WIDTH x float> @__rcp_varying_float(<WIDTH x float>) nounwind readonly alwaysinline {
  %r = fdiv <WIDTH x float> const_vector(float, 1.), %0
  ;; do one N-R iteration to improve precision
  ;; return (2. - v * r) * r;
  %mult = fmul <WIDTH x float> %0, %r
  %two_minus = fsub <WIDTH x float> const_vector(float, 2.), %mult
  %res = fmul <WIDTH x float> %r, %two_minus
  ret <WIDTH x float> %res
}

define <WIDTH x float> @__rcp_fast_varying_float(<WIDTH x float>) nounwind readonly alwaysinline {
  %res = fdiv <WIDTH x float> const_vector(float, 1.), %0
  ret <WIDTH x float> %res
}

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; rsqrt

declare <16 x float> @llvm.genx.rsqrt.v16f32(<16 x float>)
define <WIDTH x float> @__rsqrt_varying_float(<WIDTH x float> %v) nounwind readonly alwaysinline {
  %r = call <16 x float> @llvm.genx.rsqrt.v16f32(<16 x float> %v)
  ;; Newton-Raphson iteration to improve precision
  ;;  return 0.5 * r * (3. - (v * r) * r);
  %mult = fmul <WIDTH x float> %v, %r
  %mult2 = fmul <WIDTH x float> %mult, %r
  %three_sub = fsub <WIDTH x float> const_vector(float, 3.), %mult2
  %mult3 = fmul <WIDTH x float> %r, %three_sub
  %res = fmul <WIDTH x float> const_vector(float, 0.5), %mult3
  ret <WIDTH x float> %res
}

define <WIDTH x float> @__rsqrt_fast_varying_float(<WIDTH x float>) nounwind readonly alwaysinline {
  %res = call <16 x float> @llvm.genx.rsqrt.v16f32(<16 x float> %0)
  ret <WIDTH x float> %res
}

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; sqrt

declare <16 x float> @llvm.genx.sqrt.v16f32(<16 x float>)
define <WIDTH x float> @__sqrt_varying_float(<WIDTH x float>) nounwind readonly alwaysinline {
  %res = call <16 x float> @llvm.genx.sqrt.v16f32(<WIDTH x float> %0)
  ret <WIDTH x float> %res
}

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; double precision sqrt

declare <16 x double> @llvm.genx.ieee.sqrt.v16d64(<16 x double>)
define <WIDTH x double> @__sqrt_varying_double(<WIDTH x double>) nounwind alwaysinline {
  %res = call <16 x double> @llvm.genx.ieee.sqrt.v16d64(<WIDTH x double> %0)
  ret <WIDTH x double> %res
}

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; rounding floats

define <16 x float> @__round_varying_float(<16 x float>) nounwind readonly alwaysinline {
  %float_to_int_bitcast.i.i.i.i = bitcast <16 x float> %0 to <16 x i32>
  ; create vector of literals
  %vec_lit.i = insertelement <1 x i32> undef, i32 -2147483648, i32 0
  %vec_lit = shufflevector <1 x i32> %vec_lit.i, <1 x i32> undef, <16 x i32> zeroinitializer
  %bitop.i.i = and <16 x i32> %float_to_int_bitcast.i.i.i.i, %vec_lit
  %bitop.i = xor <16 x i32> %float_to_int_bitcast.i.i.i.i, %bitop.i.i
  %int_to_float_bitcast.i.i40.i = bitcast <16 x i32> %bitop.i to <16 x float>
  ; create vector of float literals
  %vec_lit_pos.i = insertelement <1 x float> undef, float 8.388608e+06, i32 0
  %vec_lit_pos = shufflevector <1 x float> %vec_lit_pos.i, <1 x float> undef, <16 x i32> zeroinitializer
  ; create vector of float literals
  %vec_lit_neg.i = insertelement <1 x float> undef, float -8.388608e+06, i32 0
  %vec_lit_neg = shufflevector <1 x float> %vec_lit_neg.i, <1 x float> undef, <16 x i32> zeroinitializer
  %binop.i = fadd <16 x float> %int_to_float_bitcast.i.i40.i, %vec_lit_pos
  %binop21.i = fadd <16 x float> %binop.i, %vec_lit_neg
  %float_to_int_bitcast.i.i.i = bitcast <16 x float> %binop21.i to <16 x i32>
  %bitop31.i = xor <16 x i32> %float_to_int_bitcast.i.i.i, %bitop.i.i
  %int_to_float_bitcast.i.i.i = bitcast <16 x i32> %bitop31.i to <16 x float>
  ret <16 x float> %int_to_float_bitcast.i.i.i
}


define <16 x float> @__floor_varying_float(<16 x float>) nounwind readonly alwaysinline {
    %res = call <16 x float> @llvm.genx.rndd.GEN_SUFFIX(float)(<16 x float> %0)
    ret <16 x float> %res
}

define <16 x float> @__ceil_varying_float(<16 x float>) nounwind readonly alwaysinline  {
    %res = call <16 x float> @llvm.genx.rndu.GEN_SUFFIX(float)(<16 x float> %0)
    ret <16 x float> %res
}

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; rounding doubles

define <16 x double> @__round_varying_double(<16 x double>) nounwind readonly alwaysinline {
  %float_to_int_bitcast.i.i.i.i = bitcast <16 x double> %0 to <16 x i64>
  ; create vector of literals
  %vec_lit.i = insertelement <1 x i64> undef, i64 -9223372036854775808, i32 0
  %vec_lit = shufflevector <1 x i64> %vec_lit.i, <1 x i64> undef, <16 x i32> zeroinitializer
  %bitop.i.i = and <16 x i64> %float_to_int_bitcast.i.i.i.i, %vec_lit
  %bitop.i = xor <16 x i64> %float_to_int_bitcast.i.i.i.i, %bitop.i.i
  %int_to_float_bitcast.i.i40.i = bitcast <16 x i64> %bitop.i to <16 x double>
  ; create vector of float literals
  %vec_lit_pos.i = insertelement <1 x double> undef, double 4.5036e+15, i32 0
  %vec_lit_pos = shufflevector <1 x double> %vec_lit_pos.i, <1 x double> undef, <16 x i32> zeroinitializer
  ; create vector of float literals
  %vec_lit_neg.i = insertelement <1 x double> undef, double -4.5036e+15, i32 0
  %vec_lit_neg = shufflevector <1 x double> %vec_lit_neg.i, <1 x double> undef, <16 x i32> zeroinitializer
  %binop.i = fadd <16 x double> %int_to_float_bitcast.i.i40.i, %vec_lit_pos
  %binop21.i = fadd <16 x double> %binop.i, %vec_lit_neg
  %float_to_int_bitcast.i.i.i = bitcast <16 x double> %binop21.i to <16 x i64>
  %bitop31.i = xor <16 x i64> %float_to_int_bitcast.i.i.i, %bitop.i.i
  %int_to_float_bitcast.i.i.i = bitcast <16 x i64> %bitop31.i to <16 x double>
  ret <16 x double> %int_to_float_bitcast.i.i.i
}

define <16 x double> @__floor_varying_double(<16 x double>) nounwind readonly alwaysinline {
  %calltmp.i = tail call <16 x double> @__round_varying_double(<16 x double> %0) nounwind
  %bincmp.i = fcmp ogt <16 x double> %calltmp.i, %0
  %val_to_boolvec32.i = sext <16 x i1> %bincmp.i to <16 x i64>
  ; create vector of literals
  %vec_lit.i = insertelement <1 x i64> undef, i64 -4616189618054758400, i32 0
  %vec_lit = shufflevector <1 x i64> %vec_lit.i, <1 x i64> undef, <16 x i32> zeroinitializer
  %bitop.i = and <16 x i64> %val_to_boolvec32.i, %vec_lit
  %int_to_float_bitcast.i.i.i = bitcast <16 x i64> %bitop.i to <16 x double>
  %binop.i = fadd <16 x double> %calltmp.i, %int_to_float_bitcast.i.i.i
  ret <16 x double> %binop.i
}

define <16 x double> @__ceil_varying_double(<16 x double>) nounwind readonly alwaysinline {
  %calltmp.i = tail call <16 x double> @__round_varying_double(<16 x double> %0) nounwind
  %bincmp.i = fcmp olt <16 x double> %calltmp.i, %0
  %val_to_boolvec32.i = sext <16 x i1> %bincmp.i to <16 x i64>
  ; create vector of literals
  %vec_lit.i = insertelement <1 x i64> undef, i64 4607182418800017408, i32 0
  %vec_lit = shufflevector <1 x i64> %vec_lit.i, <1 x i64> undef, <16 x i32> zeroinitializer
  %bitop.i = and <16 x i64> %val_to_boolvec32.i, %vec_lit
  %int_to_float_bitcast.i.i.i = bitcast <16 x i64> %bitop.i to <16 x double>
  %binop.i = fadd <16 x double> %calltmp.i, %int_to_float_bitcast.i.i.i
  ret <16 x double> %binop.i
}

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; svml

include(`svml.m4')
svml_stubs(float,f,WIDTH)
svml_stubs(double,d,WIDTH)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; horizontal ops / reductions

declare i1 @llvm.genx.any.v16i1(<WIDTH x MASK>)
declare i1 @llvm.genx.all.v16i1(<WIDTH x MASK>)

define i64 @__movmsk(<WIDTH x MASK>) nounwind readnone alwaysinline {
  %v = bitcast <WIDTH x MASK> %0 to i16
  %zext = zext i16 %v to i64
  ret i64 %zext
}

define i1 @__any(<WIDTH x MASK>) nounwind readnone alwaysinline {
  %v = call i1 @llvm.genx.any.GEN_SUFFIX(i1)(<WIDTH x MASK> %0)
  ret i1 %v
}

define i1 @__all(<WIDTH x MASK>) nounwind readnone alwaysinline {
  %v = call i1 @llvm.genx.all.GEN_SUFFIX(i1)(<WIDTH x MASK> %0) nounwind readnone
  ret i1 %v
}

define i1 @__none(<WIDTH x MASK>) nounwind readnone alwaysinline {
  %v = call i1 @llvm.genx.any.GEN_SUFFIX(i1)(<WIDTH x MASK> %0) nounwind readnone
  %v_not = icmp eq i1 %v, 0
  ret i1 %v_not
}

define(`genx_add', `
define internal <WIDTH x $1> @__add_varying_$2(<WIDTH x $1>,
                                  <WIDTH x $1>) nounwind readnone alwaysinline {
  %r = add <WIDTH x $1> %0, %1
  ret <WIDTH x $1> %r
}

define internal $1 @__add_uniform_$2($1, $1) nounwind readnone alwaysinline {
  %r = add $1 %0, %1
  ret $1 %r
}
')

genx_add(i16, i16)
genx_add(i32, int32)
genx_add(i64, int64)

define(`genx_fadd', `
define internal <WIDTH x $1> @__fadd_varying_$1(<WIDTH x $1>,
                                  <WIDTH x $1>) nounwind readnone alwaysinline {
  %r = fadd <WIDTH x $1> %0, %1
  ret <WIDTH x $1> %r
}

define internal $1 @__fadd_uniform_$1($1, $1) nounwind readnone alwaysinline {
  %r = fadd $1 %0, %1
  ret $1 %r
}
')

genx_fadd(float)
genx_fadd(double)

define i16 @__reduce_add_int8(<WIDTH x i8>) nounwind readnone alwaysinline {
  %ext = zext <WIDTH x i8> %0 to <WIDTH x i16>
  reduce16(i16, @__add_varying_i16, @__add_uniform_i16, %ext)
}

define i32 @__reduce_add_int16(<WIDTH x i16>) nounwind readnone alwaysinline {
  %ext = zext <WIDTH x i16> %0 to <WIDTH x i32>
  reduce16(i32, @__add_varying_int32, @__add_uniform_int32, %ext)
}

define i64 @__reduce_add_int32(<WIDTH x i32>) nounwind readnone {
  %ext = zext <WIDTH x i32> %0 to <WIDTH x i64>
  reduce16(i64, @__add_varying_int64, @__add_uniform_int64, %ext)
}

define float @__reduce_add_float(<WIDTH x float>) nounwind readonly alwaysinline {
  reduce16(float, @__fadd_varying_float, @__fadd_uniform_float, %0)
}

define double @__reduce_add_double(<WIDTH x double>) nounwind readnone {
  reduce16(double, @__fadd_varying_double, @__fadd_uniform_double, %0)
}

define i64 @__reduce_add_int64(<WIDTH x i64>) nounwind readnone {
  reduce16(i64, @__add_varying_int64, @__add_uniform_int64, %0)
}

define i32 @__reduce_min_int32(<WIDTH x i32>) nounwind readnone {
  reduce16(i32, @__min_varying_int32, @__min_uniform_int32, %0)
}

define i32 @__reduce_max_int32(<WIDTH x i32>) nounwind readnone {
  reduce16(i32, @__max_varying_int32, @__max_uniform_int32, %0)
}

define i32 @__reduce_min_uint32(<WIDTH x i32>) nounwind readnone {
  reduce16(i32, @__min_varying_uint32, @__min_uniform_uint32, %0)
}

define i32 @__reduce_max_uint32(<WIDTH x i32>) nounwind readnone {
  reduce16(i32, @__max_varying_uint32, @__max_uniform_uint32, %0)
}

define float @__reduce_min_float(<WIDTH x float>) nounwind readnone {
  reduce16(float, @__min_varying_float, @__min_uniform_float, %0)
}

define float @__reduce_max_float(<WIDTH x float>) nounwind readnone {
  reduce16(float, @__max_varying_float, @__max_uniform_float, %0)
}

define double @__reduce_min_double(<WIDTH x double>) nounwind readnone {
  reduce16(double, @__min_varying_double, @__min_uniform_double, %0)
}

define double @__reduce_max_double(<WIDTH x double>) nounwind readnone {
  reduce16(double, @__max_varying_double, @__max_uniform_double, %0)
}

define i64 @__reduce_min_int64(<WIDTH x i64>) nounwind readnone {
  reduce16(i64, @__min_varying_int64, @__min_uniform_int64, %0)
}

define i64 @__reduce_max_int64(<WIDTH x i64>) nounwind readnone {
  reduce16(i64, @__max_varying_int64, @__max_uniform_int64, %0)
}

define i64 @__reduce_min_uint64(<WIDTH x i64>) nounwind readnone {
  reduce16(i64, @__min_varying_uint64, @__min_uniform_uint64, %0)
}

define i64 @__reduce_max_uint64(<WIDTH x i64>) nounwind readnone {
  reduce16(i64, @__max_varying_uint64, @__max_uniform_uint64, %0)
}

reduce_equal(WIDTH)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; masked store

define(`genx_masked_store_blend', `
declare void @llvm.genx.vstore.GEN_SUFFIX($1)(<WIDTH x $1>, <WIDTH x $1>*)
declare <WIDTH x $1> @llvm.genx.vload.GEN_SUFFIX($1)(<WIDTH x $1>*)

define void @__masked_store_blend_$1(<WIDTH x $1>* nocapture, <WIDTH x $1>,
                                      <WIDTH x MASK> %mask) nounwind
                                      alwaysinline {
  %old = load <WIDTH x $1>, <WIDTH x $1>* %0
  %blend = select <WIDTH x MASK> %mask, <16 x $1> %1, <16 x $1> %old
  store <WIDTH x $1> %blend, <WIDTH x $1>* %0
  ret void
}
')

genx_masked_store_blend(i8)
genx_masked_store_blend(i16)
genx_masked_store_blend(i32)
genx_masked_store_blend(float)
genx_masked_store_blend(double)
genx_masked_store_blend(i64)

define(`genx_masked_store', `
declare void @llvm.genx.svm.block.st.GEN_SUFFIX($1)(i64, <WIDTH x $1>)
define void @__masked_store_$1(<WIDTH x $1>* nocapture, <WIDTH x $1>, <WIDTH x MASK> %mask) nounwind alwaysinline {
  %ptr = bitcast <WIDTH x $1>* %0 to i8*
  %broadcast_init = insertelement <WIDTH x i32> undef, i32 SIZEOF($1), i32 0
  %shuffle = shufflevector <WIDTH x i32> %broadcast_init, <WIDTH x i32> undef, <WIDTH x i32> zeroinitializer
  %offsets = mul <WIDTH x i32> <i32 0, i32 1, i32 2, i32 3, i32 4, i32 5, i32 6, i32 7, i32 8, i32 9, i32 10, i32 11, i32 12, i32 13, i32 14, i32 15>, %shuffle
  call void @__scatter_base_offsets32_$1(i8* %ptr, i32 1, <WIDTH x i32> %offsets, <WIDTH x $1> %1, <WIDTH x MASK> %mask)
  ret void
}

define void @__masked_store_private_$1(<WIDTH x $1>* nocapture, <WIDTH x $1>, <WIDTH x MASK> %mask) nounwind alwaysinline {
  %ptr = bitcast <WIDTH x $1>* %0 to i8*
  %broadcast_init = insertelement <WIDTH x i32> undef, i32 SIZEOF($1), i32 0
  %shuffle = shufflevector <WIDTH x i32> %broadcast_init, <WIDTH x i32> undef, <WIDTH x i32> zeroinitializer
  %offsets = mul <WIDTH x i32> <i32 0, i32 1, i32 2, i32 3, i32 4, i32 5, i32 6, i32 7, i32 8, i32 9, i32 10, i32 11, i32 12, i32 13, i32 14, i32 15>, %shuffle
  call void @__scatter_base_offsets32_private_$1(i8* %ptr, i32 1, <WIDTH x i32> %offsets, <WIDTH x $1> %1, <WIDTH x MASK> %mask)
  ret void
}
')

genx_masked_store(i8)
genx_masked_store(i16)
genx_masked_store(i32)
genx_masked_store(float)
genx_masked_store(double)
genx_masked_store(i64)

define(`genx_masked_load', `
declare <WIDTH x $1> @llvm.genx.svm.block.ld.GEN_SUFFIX($1)(i64)
define <WIDTH x $1> @__masked_load_$1(i8 *, <WIDTH x MASK> %mask) nounwind alwaysinline {
  %broadcast_init = insertelement <WIDTH x i32> undef, i32 SIZEOF($1), i32 0
  %shuffle = shufflevector <WIDTH x i32> %broadcast_init, <WIDTH x i32> undef, <WIDTH x i32> zeroinitializer
  %offsets = mul <WIDTH x i32> <i32 0, i32 1, i32 2, i32 3, i32 4, i32 5, i32 6, i32 7, i32 8, i32 9, i32 10, i32 11, i32 12, i32 13, i32 14, i32 15>, %shuffle
  %res = call <WIDTH x $1> @__gather_base_offsets32_$1(i8 * %0, i32 1, <WIDTH x i32> %offsets, <WIDTH x MASK> %mask)
  ret <WIDTH x $1> %res
}

define <WIDTH x $1> @__masked_load_private_$1(i8 *, <WIDTH x MASK> %mask) nounwind alwaysinline {
  %ptr_bitcast = bitcast i8* %0 to <WIDTH x $1>*
  %res = load <WIDTH x $1>, <WIDTH x $1>* %ptr_bitcast
  %masked_res = select <WIDTH x MASK> %mask, <WIDTH x $1> %res, <WIDTH x $1> zeroinitializer
  ret <WIDTH x $1> %masked_res
}
')

genx_masked_load(i8)
genx_masked_load(i16)
genx_masked_load(i32)
genx_masked_load(float)
genx_masked_load(double)
genx_masked_load(i64)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; gather/scatter
;; TODO_GEN: add computation of the block size and the number of blocks for svm gather/scatter.
define(`genx_gather', `
declare <WIDTH x $1> @llvm.genx.svm.gather.GEN_SUFFIX($1).v16i1.v16i64(<WIDTH x MASK>, i32, <WIDTH x i64>, <WIDTH x $1>)
declare <WIDTH x $1> @llvm.genx.gather.private.GEN_SUFFIX($1).v16i1.pi8.v16i32(<WIDTH x MASK>, i8*, <WIDTH x i32>, <WIDTH x $1>)

define <WIDTH x $1>
@__gather_base_offsets32_$1(i8 * %ptr, i32 %offset_scale, <WIDTH x i32> %offsets, <WIDTH x MASK> %vecmask) nounwind readonly alwaysinline {
  %ptr_to_int = ptrtoint i8* %ptr to i32
  %base = insertelement <WIDTH x i32> undef, i32 %ptr_to_int, i32 0
  %shuffle = shufflevector <WIDTH x i32> %base, <WIDTH x i32> undef, <WIDTH x i32> zeroinitializer
  %new_offsets = add <WIDTH x i32> %offsets, %shuffle
  %res = call <WIDTH x $1> @__gather32_$1(<WIDTH x i32> %new_offsets, <WIDTH x MASK> %vecmask)
  ret <WIDTH x $1> %res
}

define <WIDTH x $1>
@__gather_base_offsets64_$1(i8 * %ptr, i32 %offset_scale, <WIDTH x i64> %offsets, <WIDTH x MASK> %vecmask) nounwind readonly alwaysinline {
  %ptr_to_int = ptrtoint i8* %ptr to i64
  %base = insertelement <WIDTH x i64> undef, i64 %ptr_to_int, i32 0
  %shuffle = shufflevector <WIDTH x i64> %base, <WIDTH x i64> undef, <WIDTH x i32> zeroinitializer
  %new_offsets = add <WIDTH x i64> %offsets, %shuffle
  %res = call <WIDTH x $1> @__gather64_$1(<WIDTH x i64> %new_offsets, <WIDTH x MASK> %vecmask)
  ret <WIDTH x $1> %res
}

define <WIDTH x $1>
@__gather_base_offsets32_private_$1(i8 * %ptr, i32 %offset_scale, <WIDTH x i32> %offsets, <WIDTH x MASK> %vecmask) nounwind readonly alwaysinline {
  %res = call <WIDTH x $1> @llvm.genx.gather.private.GEN_SUFFIX($1).v16i1.pi8.v16i32(<WIDTH x MASK> %vecmask, i8* %ptr, <WIDTH x i32> %offsets, <WIDTH x $1> undef)
  ret <WIDTH x $1> %res
}

define <WIDTH x $1>
@__gather_base_offsets64_private_$1(i8 * %ptr, i32 %offset_scale, <WIDTH x i64> %offsets, <WIDTH x MASK> %vecmask) nounwind readonly alwaysinline {
  %offsets32 = trunc <WIDTH x i64> %offsets to <WIDTH x i32>
  %res = call <WIDTH x $1> @llvm.genx.gather.private.GEN_SUFFIX($1).v16i1.pi8.v16i32(<WIDTH x MASK> %vecmask, i8* %ptr, <WIDTH x i32> %offsets32, <WIDTH x $1> undef)
  ret <WIDTH x $1> %res
}

define <WIDTH x $1>
@__gather32_$1(<WIDTH x i32> %offsets, <WIDTH x MASK> %vecmask) nounwind readonly alwaysinline {
  %offsets64 = zext <WIDTH x i32> %offsets to <WIDTH x i64>
  %res = call <WIDTH x $1> @llvm.genx.svm.gather.GEN_SUFFIX($1).v16i1.v16i64(<16 x MASK> %vecmask, i32 0, <WIDTH x i64> %offsets64, <WIDTH x $1> undef)
  ret <WIDTH x $1> %res
}

define <WIDTH x $1>
@__gather64_$1(<WIDTH x i64> %offsets, <WIDTH x MASK> %vecmask) nounwind readonly alwaysinline {
  %res = call <WIDTH x $1> @llvm.genx.svm.gather.GEN_SUFFIX($1).v16i1.v16i64(<WIDTH x MASK> %vecmask, i32 0, <WIDTH x i64> %offsets, <WIDTH x $1> undef)
  ret <WIDTH x $1> %res
}

define <WIDTH x $1>
@__gather32_private_$1(<WIDTH x i32> %offsets, <WIDTH x MASK> %vecmask) nounwind readonly alwaysinline {
  ;; CM cannot process zeroinitializer as a base so we need to generate here llvm gather
  %res = call <WIDTH x $1> @__gather_base_offsets32_private_$1(i8 * zeroinitializer, i32 0, <WIDTH x i32> %offsets, <WIDTH x MASK> %vecmask)
  ret <WIDTH x $1> %res
}

define <WIDTH x $1>
@__gather64_private_$1(<WIDTH x i64> %offsets, <WIDTH x MASK> %vecmask) nounwind readonly alwaysinline {
  ;; CM cannot process zeroinitializer as a base so we need to generate here llvm gather
  %res = call <WIDTH x $1> @__gather_base_offsets64_private_$1(i8 * zeroinitializer, i32 0, <WIDTH x i64> %offsets, <WIDTH x MASK> %vecmask)
  ret <WIDTH x $1> %res
}
')
genx_gather(i8)
genx_gather(i16)
genx_gather(i32)
genx_gather(float)
genx_gather(i64)
genx_gather(double)

define(`genx_scatter', `
declare void @llvm.genx.svm.scatter.v16i1.v16i64.GEN_SUFFIX($1)(<WIDTH x MASK>, i32, <WIDTH x i64>, <WIDTH x $1>)
declare void @llvm.genx.scatter.private.v16i1.pi8.v16i32.GEN_SUFFIX($1)(<WIDTH x MASK>, i8*, <WIDTH x i32>, <WIDTH x $1>)

define void
@__scatter_base_offsets32_$1(i8* %ptr, i32 %offset_scale, <WIDTH x i32> %offsets, <WIDTH x $1> %vals, <WIDTH x MASK> %vecmask) nounwind {
  %ptr_to_int = ptrtoint i8* %ptr to i32
  %base = insertelement <WIDTH x i32> undef, i32 %ptr_to_int, i32 0
  %shuffle = shufflevector <WIDTH x i32> %base, <WIDTH x i32> undef, <WIDTH x i32> zeroinitializer
  %new_offsets = add <WIDTH x i32> %offsets, %shuffle
  call void @__scatter32_$1(<WIDTH x i32> %new_offsets, <WIDTH x $1> %vals, <WIDTH x MASK> %vecmask)
  ret void
}

define void
@__scatter_base_offsets64_$1(i8* %ptr, i32 %offset_scale, <WIDTH x i64> %offsets, <WIDTH x $1> %vals, <WIDTH x MASK> %vecmask) nounwind {
  %ptr_to_int = ptrtoint i8* %ptr to i64
  %base = insertelement <WIDTH x i64> undef, i64 %ptr_to_int, i32 0
  %shuffle = shufflevector <WIDTH x i64> %base, <WIDTH x i64> undef, <WIDTH x i32> zeroinitializer
  %new_offsets = add <WIDTH x i64> %offsets, %shuffle
  call void @__scatter64_$1(<WIDTH x i64> %new_offsets, <WIDTH x $1> %vals, <WIDTH x MASK> %vecmask)
  ret void
}

define void
@__scatter_base_offsets32_private_$1(i8* %ptr, i32 %offset_scale, <WIDTH x i32> %offsets, <WIDTH x $1> %vals, <WIDTH x MASK> %vecmask) nounwind {
  call void @llvm.genx.scatter.private.v16i1.pi8.v16i32.GEN_SUFFIX($1)(<WIDTH x MASK> %vecmask, i8* %ptr, <WIDTH x i32> %offsets, <WIDTH x $1> %vals)
  ret void
}

define void
@__scatter_base_offsets64_private_$1(i8* %ptr, i32 %offset_scale, <WIDTH x i64> %offsets, <WIDTH x $1> %vals, <WIDTH x MASK> %vecmask) nounwind {
   %offsets32 = trunc <WIDTH x i64> %offsets to <WIDTH x i32>
   call void @llvm.genx.scatter.private.v16i1.pi8.v16i32.GEN_SUFFIX($1)(<WIDTH x MASK> %vecmask, i8* %ptr, <WIDTH x i32> %offsets32, <WIDTH x $1> %vals)
   ret void
}

define void
@__scatter32_$1(<WIDTH x i32> %ptrs, <WIDTH x $1> %values, <WIDTH x MASK> %vecmask) nounwind alwaysinline {
  %offsets64 = zext <WIDTH x i32> %ptrs to <WIDTH x i64>
  call void @llvm.genx.svm.scatter.v16i1.v16i64.GEN_SUFFIX($1)(<WIDTH x MASK> %vecmask, i32 0, <WIDTH x i64> %offsets64, <WIDTH x $1> %values)
  ret void
}

define void
@__scatter64_$1(<WIDTH x i64> %ptrs, <WIDTH x $1> %values, <WIDTH x MASK> %vecmask) nounwind alwaysinline {
  call void @llvm.genx.svm.scatter.v16i1.v16i64.GEN_SUFFIX($1)(<WIDTH x MASK> %vecmask, i32 0, <WIDTH x i64> %ptrs, <WIDTH x $1> %values)
  ret void
}

define void
@__scatter32_private_$1(<WIDTH x i32> %offsets, <WIDTH x $1> %values, <WIDTH x MASK> %vecmask) nounwind alwaysinline {
  ;; CM cannot process zeroinitializer as a base so we need to generate here llvm scatter
  call void @__scatter_base_offsets32_private_$1(i8* zeroinitializer, i32 1, <WIDTH x i32> %offsets, <WIDTH x $1> %values, <WIDTH x MASK> %vecmask)
  ret void
}

define void
@__scatter64_private_$1(<WIDTH x i64> %offsets, <WIDTH x $1> %values, <WIDTH x MASK> %vecmask) nounwind alwaysinline {
  ;; CM cannot process zeroinitializer as a base so we need to generate here llvm scatter
  call void @__scatter_base_offsets64_private_$1(i8* zeroinitializer, i32 1, <WIDTH x i64> %offsets, <WIDTH x $1> %values, <WIDTH x MASK> %vecmask)
  ret void
}
')

genx_scatter(i8)
genx_scatter(i16)
genx_scatter(i32)
genx_scatter(float)
genx_scatter(i64)
genx_scatter(double)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; int8/int16 builtins

define_avgs()

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; reciprocals in double precision, if supported

rsqrtd_decl()
rcpd_decl()

transcendetals_decl()
trigonometry_decl()
